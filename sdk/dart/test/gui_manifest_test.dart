import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gui_manifest/gui_manifest.dart';
import 'package:nanomarkup/nanomarkup.dart';
import 'package:test/test.dart';

import '../example/example_cli.dart' as example;

const _fixtures = '../../conformance/fixtures';

const _cli = GuiCliInfo(
  name: 'example',
  version: '0.1.0',
  displayName: 'Example CLI',
);

void main() {
  group('negotiation', () {
    test('not a request', () {
      expect(GuiManifestRequest.parse(['status']), isNull);
      expect(GuiManifestRequest.parse(['--gui-manifest=1', 'x']), isNull);
    });
    test('bare flag means version 1', () {
      expect(
        GuiManifestRequest.parse(['--gui-manifest']),
        isA<GuiManifestAccepted>().having((r) => r.version, 'version', 1),
      );
    });
    test('newer request falls back to highest supported', () {
      expect(
        GuiManifestRequest.parse(['--gui-manifest=7']),
        isA<GuiManifestAccepted>().having((r) => r.version, 'version', 1),
      );
    });
    test('rejects 0 and garbage', () {
      expect(
        GuiManifestRequest.parse(['--gui-manifest=0']),
        isA<GuiManifestRejected>(),
      );
      expect(
        GuiManifestRequest.parse(['--gui-manifest=01']),
        isA<GuiManifestRejected>(),
      );
      expect(
        GuiManifestRequest.parse(['--gui-manifest=x']),
        isA<GuiManifestRejected>(),
      );
    });
  });

  test('the example spec reproduces the conformance fixture', () {
    final source = encodeManifest(manifestFromSpec(example.createSpec()));
    final fixture = File('$_fixtures/minimal.nano').readAsStringSync();
    expect(decode(source), decode(fixture));
    expect(source, fixture);
  });

  test('generated manifest is valid', () {
    final source = encodeManifest(manifestFromSpec(example.createSpec()));
    expect(validateManifestSource(source), isEmpty);
  });

  group('manifest from a spec', () {
    final manifest = manifestFromSpec(example.createSpec());

    test('lists commands in declaration order with paths as ids', () {
      expect(manifest.commands.map((c) => c.id), [
        'status',
        'workers.list',
        'workers.remove',
      ]);
    });

    test('appends the json args only to json commands', () {
      final argv = {for (final c in manifest.commands) c.id: c.argv};
      expect(argv['status'], ['status', '--json']);
      expect(argv['workers.list'], ['workers', 'list', '--json']);
      expect(argv['workers.remove'], ['workers', 'remove']);
    });

    test('records groups and membership', () {
      expect(manifest.groups.map((g) => g.id), ['workers']);
      final group = {for (final c in manifest.commands) c.id: c.group};
      expect(group, {
        'status': null,
        'workers.list': 'workers',
        'workers.remove': 'workers',
      });
    });

    test('commands carry an icon and a kind (action by default)', () {
      final byId = {for (final c in manifest.commands) c.id: c};
      expect(byId['status']!.kind, GuiCommandKind.info);
      expect(byId['status']!.icon, GuiIcons.pulse);
      expect(byId['workers.list']!.kind, GuiCommandKind.info);
      expect(byId['workers.remove']!.kind, GuiCommandKind.action);
      expect(byId['workers.remove']!.icon, GuiIcons.trash);
    });

    test('a group sidebar entry opens its default command', () {
      final nav = manifest.navigation.map((n) => (n.id, n.command)).toList();
      expect(nav, [('status', 'status'), ('workers', 'workers.list')]);
    });
  });

  test('fixture is valid', () {
    expect(
      validateManifestSource(
        File('$_fixtures/minimal.nano').readAsStringSync(),
      ),
      isEmpty,
    );
  });

  group('validator reports', () {
    List<String> issues(String source) =>
        validateManifestSource(source).map((i) => i.toString()).toList();

    test('missing top-level fields', () {
      expect(issues('..\n    manifestVersion 1'), [
        r'$.cli: is required',
        r'$.commands: is required',
        r'$.navigation: is required',
      ]);
    });

    test('bad booleans, ids and references', () {
      const source = '''..
    manifestVersion 1
    cli..
        name x
        version 1
    navigation:
        ..
            id Bad
            label B
            command nope
    commands:
        ..
            id a
            argv:
                a
            title A
            destructive yes
        ..
            id a
            argv:
                a
            title A''';
      expect(issues(source), [
        r'$.commands[1].id: duplicate id "a"',
        r'$.commands[0].destructive: "yes" is not one of true, false',
        r'$.navigation[0].id: "Bad" is not a valid id',
        r'$.navigation[0].command: unknown command "nope"',
      ]);
    });
  });

  group('groups', () {
    const base = '''..
    manifestVersion 1
    cli..
        name x
        version 1
    navigation:
    commands:
        ..
            id a
            argv:
                a
            title A
            group ''';

    List<String> issues(String source) =>
        validateManifestSource(source).map((i) => i.toString()).toList();

    test('commands must reference declared groups', () {
      expect(issues('${base}nope'), [
        r'$.commands[0].group: unknown group "nope"',
      ]);
    });

    test('groups need ids and labels and valid parents', () {
      const source = '''..
    manifestVersion 1
    cli..
        name x
        version 1
    navigation:
    groups:
        ..
            id g
            parent missing
        ..
            id g
            label G
    commands:''';
      expect(issues(source), [
        r'$.groups[1].id: duplicate id "g"',
        r'$.groups[0].label: is required',
        r'$.groups[0].parent: unknown group "missing"',
      ]);
    });
  });

  group('command kind and icon', () {
    const base = '''..
    manifestVersion 1
    cli..
        name x
        version 1
    navigation:
    commands:
        ..
            id a
            argv:
                a
            title A
''';

    /// The command with one more field line.
    List<String> issues(String field) => validateManifestSource(
          '$base            $field',
        ).map((i) => i.toString()).toList();

    test('accept info and action', () {
      expect(issues('kind info'), isEmpty);
      expect(issues('kind action'), isEmpty);
      expect(issues('icon rocket'), isEmpty);
    });

    test('reject other kinds', () {
      expect(issues('kind read'), [
        r'$.commands[0].kind: "read" is not one of info, action',
      ]);
    });
  });

  test('icon names are unique and include the default', () {
    expect(GuiIcons.all.toSet().length, GuiIcons.all.length);
    expect(GuiIcons.all, contains(GuiIcons.command));
    for (final name in GuiIcons.all) {
      expect(name, matches(RegExp(r'^[a-z][a-zA-Z0-9]*$')), reason: name);
    }
  });

  test('options map to parameters', () {
    final runner = CommandRunner<void>('t', 't')..addCommand(_Login());
    final params = buildManifest(runner, cli: _cli).commands.single.parameters;
    expect(params.map((p) => (p.name, p.type, p.kind)), [
      ('token', GuiParamType.secret, GuiParamKind.option),
      ('region', GuiParamType.enumeration, GuiParamKind.option),
      ('verbose', GuiParamType.boolean, GuiParamKind.flag),
    ]);
    expect(params[0].defaultValue, isNull);
    expect(params[1].defaultValue, 'eu');
  });
}

class _Login extends Command<void> with GuiDescribed<void> {
  _Login() {
    argParser
      ..addOption('token', mandatory: true, defaultsTo: null)
      ..addOption('region', allowed: ['eu', 'us'], defaultsTo: 'eu')
      ..addFlag('verbose');
  }

  @override
  final name = 'login';
  @override
  final description = 'Sign in.';
  @override
  final gui = const GuiMeta(secretOptions: {'token'});
}

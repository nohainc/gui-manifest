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

  test('builder reproduces the conformance fixture', () {
    final source = encodeManifest(
      example.createManifest(example.createRunner()),
    );
    final fixture = File('$_fixtures/minimal.nano').readAsStringSync();
    expect(decode(source), decode(fixture));
  });

  test('generated manifest is valid', () {
    final source = encodeManifest(
      example.createManifest(example.createRunner()),
    );
    expect(validateManifestSource(source), isEmpty);
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

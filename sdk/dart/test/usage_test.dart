import 'package:gui_manifest/gui_manifest.dart';
import 'package:test/test.dart';

CliCommand _cmd(
  String name,
  String description, {
  List<GuiParameter> parameters = const [],
  bool Function()? visible,
}) => CliCommand(
  name: name,
  title: name,
  description: description,
  parameters: parameters,
  visible: visible,
  handler: (_) => 0,
);

GuiParameter _p(
  String name,
  GuiParamKind kind, {
  bool required = false,
  bool multiple = false,
  GuiParamType type = GuiParamType.string,
}) => GuiParameter(
  name: name,
  kind: kind,
  type: type,
  required: required,
  multiple: multiple,
);

CliSpec _spec({bool showMore = true, String Function(CliSpec)? usageBuilder}) =>
    CliSpec(
      name: 'mycli',
      description: 'My CLI',
      version: '1',
      usageBuilder: usageBuilder,
      globals: [
        _p('data-dir', GuiParamKind.option, type: GuiParamType.path),
        _p('json', GuiParamKind.flag, type: GuiParamType.boolean),
      ],
      nodes: [
        _cmd('status', 'Service summary'),
        CliGroup(
          name: 'folders',
          title: 'Folders',
          description: 'Folders',
          defaultCommand: 'list',
          visible: () => showMore,
          children: [
            _cmd('list', 'List allowed folders'),
            _cmd(
              'add',
              'Add an allowed folder',
              parameters: [
                _p('path', GuiParamKind.positional, required: true),
                _p('name', GuiParamKind.option),
                _p('force', GuiParamKind.flag, type: GuiParamType.boolean),
              ],
            ),
          ],
        ),
        CliGroup(
          name: 'service',
          title: 'Service',
          description: 'Service',
          navigation: true,
          navigationCommand: 'status',
          children: [_cmd('start', 'Start it'), _cmd('status', 'Show it')],
        ),
        _cmd(
          'work-dir',
          'View or set the Work Root',
          parameters: [_p('path', GuiParamKind.positional)],
        ),
        _cmd(
          'run',
          'Run files',
          parameters: [
            _p('token', GuiParamKind.option, required: true),
            _p('files', GuiParamKind.positional, multiple: true),
          ],
        ),
      ],
    );

void main() {
  group('flatUsage', () {
    test('lists every command on one line, sorted by top-level name', () {
      expect(flatUsage(_spec()), '''
Usage: mycli [--data-dir DATA_DIR] [--json] <command>

  folders                       List allowed folders
  folders add PATH [--name NAME]
                                Add an allowed folder
  run --token TOKEN [FILES...]  Run files
  service start                 Start it
  service status                Show it
  status                        Service summary
  work-dir [PATH]               View or set the Work Root
''');
    });

    test('leaves out invisible nodes and their children', () {
      final text = flatUsage(_spec(showMore: false));
      expect(text, isNot(contains('folders')));
      expect(text, contains('status'));
    });

    test('the header can be replaced', () {
      expect(
        flatUsage(_spec(), header: 'Usage: custom'),
        startsWith('Usage: custom\n\n'),
      );
    });
  });

  group('usageBuilder', () {
    Future<(int, String, String)> run(List<String> args) async {
      final out = StringBuffer(), err = StringBuffer();
      final code = await runCli(
        _spec(usageBuilder: (spec) => '${flatUsage(spec)}-- footer --\n'),
        args,
        out: out,
        err: err,
      );
      return (code, '$out', '$err');
    }

    test('is printed by --help', () async {
      final (code, out, _) = await run(['--help']);
      expect(code, 0);
      expect(out, contains('  status                        Service summary'));
      expect(out, contains('-- footer --'));
    });

    test('is printed with top-level usage errors', () async {
      final (code, out, err) = await run(['bogus']);
      expect(code, 64);
      expect(out, isEmpty);
      expect(err, contains('Could not find a command named "bogus"'));
      expect(err, contains('-- footer --'));
    });

    test('does not replace the usage of a command', () async {
      final (_, out, _) = await run(['folders', 'add', '--help']);
      expect(out, contains('mycli folders add'));
      expect(out, isNot(contains('-- footer --')));
    });
  });

  group('no command', () {
    Future<(int, String, String)> run(List<String> args) async {
      final out = StringBuffer(), err = StringBuffer();
      final code = await runCli(_spec(), args, out: out, err: err);
      return (code, '$out', '$err');
    }

    test('is a usage error, not a successful help screen', () async {
      final (code, out, err) = await run([]);
      expect(code, 64);
      expect(out, isEmpty);
      expect(err, contains('Missing command.'));
    });

    test('--help still prints help and succeeds', () async {
      expect((await run(['--help'])).$1, 0);
    });
  });

  group('navigationCommand', () {
    test(
      'opens that child without changing what the group runs alone',
      () async {
        final manifest = manifestFromSpec(_spec());
        expect(manifest.navigation.map((n) => (n.id, n.command)), [
          ('service', 'service.status'),
        ]);
        final err = StringBuffer();
        final code = await runCli(
          _spec(),
          ['service'],
          out: StringBuffer(),
          err: err,
        );
        expect(code, 64);
        expect('$err', contains('Missing subcommand'));
      },
    );

    test('must name a command child', () {
      expect(
        () => CliSpec(
          name: 'x',
          description: 'x',
          version: '1',
          nodes: [
            CliGroup(
              name: 'g',
              title: 'G',
              description: 'G',
              navigation: true,
              navigationCommand: 'nope',
              children: [_cmd('a', 'a')],
            ),
          ],
        ),
        throwsA(isA<CliSpecError>()),
      );
    });
  });
}

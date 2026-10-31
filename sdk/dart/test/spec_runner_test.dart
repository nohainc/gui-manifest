import 'package:gui_manifest/gui_manifest.dart';
import 'package:test/test.dart';

class _Run {
  _Run(this.code, this.out, this.err);
  final int code;
  final String out;
  final String err;
}

GuiParameter _positional(
  String name, {
  bool required = false,
  bool multiple = false,
}) => GuiParameter(
  name: name,
  kind: GuiParamKind.positional,
  type: GuiParamType.string,
  required: required,
  multiple: multiple,
);

/// Records what handlers received.
CliSpec _spec(
  List<String> log, {
  bool Function()? secretVisible,
  int usageExit = 64,
}) {
  String globals(CliInvocation r) =>
      'json=${r.globalFlag('json')} dir=${r.globalOption('data-dir')}';
  return CliSpec(
    name: 't',
    description: 'Test CLI',
    version: '1.0.0',
    usageExitCode: usageExit,
    globals: const [
      GuiParameter(
        name: 'json',
        kind: GuiParamKind.flag,
        type: GuiParamType.boolean,
      ),
      GuiParameter(
        name: 'data-dir',
        kind: GuiParamKind.option,
        type: GuiParamType.path,
      ),
    ],
    nodes: [
      CliCommand(
        name: 'status',
        title: 'Status',
        description: 'Show status.',
        handler: (r) {
          log.add('status ${globals(r)}');
          return 0;
        },
      ),
      CliGroup(
        name: 'workers',
        title: 'Workers',
        description: 'Manage workers.',
        defaultCommand: 'list',
        children: [
          CliCommand(
            name: 'list',
            title: 'List',
            description: 'List workers.',
            aliases: ['ls'],
            handler: (r) {
              log.add('workers list ${globals(r)}');
              return 0;
            },
          ),
          CliCommand(
            name: 'add',
            title: 'Add',
            description: 'Add a worker.',
            parameters: [
              _positional('type', required: true),
              const GuiParameter(
                name: 'name',
                kind: GuiParamKind.option,
                type: GuiParamType.string,
              ),
              const GuiParameter(
                name: 'region',
                kind: GuiParamKind.option,
                type: GuiParamType.enumeration,
                values: ['eu', 'us'],
                defaultValue: 'eu',
              ),
              const GuiParameter(
                name: 'force',
                kind: GuiParamKind.flag,
                type: GuiParamType.boolean,
              ),
            ],
            handler: (r) {
              log.add(
                'add ${r.positional('type')} name=${r.option('name')} '
                'region=${r.option('region')} force=${r.flag('force')} '
                '${globals(r)} path=${r.path.join('/')}',
              );
              return 0;
            },
          ),
        ],
      ),
      CliGroup(
        name: 'service',
        title: 'Service',
        description: 'Manage the service.',
        children: [
          CliCommand(
            name: 'start',
            title: 'Start',
            description: 'Start it.',
            handler: (r) => 7,
          ),
        ],
      ),
      CliCommand(
        name: 'work-dir',
        title: 'Work Root',
        description: 'View or set the Work Root.',
        parameters: [_positional('path')],
        handler: (r) {
          log.add('work-dir ${r.positional('path')}');
          return 0;
        },
      ),
      CliCommand(
        name: 'run-all',
        title: 'Run all',
        description: 'Run files.',
        parameters: [_positional('files', multiple: true)],
        handler: (r) {
          log.add('run-all ${r.positionalList('files').join(',')}');
          return 0;
        },
      ),
      CliCommand(
        name: 'login',
        title: 'Login',
        description: 'Sign in.',
        parameters: const [
          GuiParameter(
            name: 'token',
            kind: GuiParamKind.option,
            type: GuiParamType.secret,
            required: true,
          ),
        ],
        handler: (r) {
          log.add('login ${r.option('token')}');
          return 0;
        },
      ),
      CliCommand(
        name: 'maintenance',
        title: 'Maintenance',
        description: 'Only after setup.',
        visible: secretVisible,
        handler: (r) {
          log.add('maintenance');
          return 0;
        },
      ),
    ],
  );
}

Future<_Run> _run(CliSpec spec, List<String> args) async {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = await runCli(spec, args, out: out, err: err);
  return _Run(code, '$out', '$err');
}

void main() {
  late List<String> log;
  setUp(() => log = []);

  group('commands', () {
    test('runs a command and returns its exit code', () async {
      final result = await _run(_spec(log), ['service', 'start']);
      expect(result.code, 7);
    });

    test('a group alone runs its default command', () async {
      expect((await _run(_spec(log), ['workers'])).code, 0);
      expect(log, ['workers list json=false dir=null']);
    });

    test('aliases select the command', () async {
      await _run(_spec(log), ['workers', 'ls']);
      expect(log, ['workers list json=false dir=null']);
    });

    test('a group without a default command is a usage error', () async {
      final result = await _run(_spec(log), ['service']);
      expect(result.code, 64);
      expect(result.err, contains('Missing subcommand'));
    });

    test('unknown commands are usage errors with usage text', () async {
      final result = await _run(_spec(log), ['nope']);
      expect(result.code, 64);
      expect(result.err, contains('Could not find a command named "nope"'));
      expect(result.err, contains('Available commands'));
      expect(log, isEmpty);
    });

    test('usage errors use the configured exit code', () async {
      expect((await _run(_spec(log, usageExit: 2), ['nope'])).code, 2);
    });
  });

  group('global options', () {
    test('are accepted before, between and after the command words', () async {
      final spec = _spec(log);
      await _run(spec, ['--json', 'workers', 'list']);
      await _run(spec, ['workers', '--json', 'list']);
      await _run(spec, ['workers', 'list', '--json']);
      await _run(spec, ['workers', '--json']); // default command
      expect(log, everyElement('workers list json=true dir=null'));
      expect(log, hasLength(4));
    });

    test('options take values and the last one given wins', () async {
      await _run(_spec(log), [
        '--data-dir',
        '/a',
        'status',
        '--data-dir',
        '/b',
      ]);
      expect(log, ['status json=false dir=/b']);
      log.clear();
      await _run(_spec(log), ['--data-dir=/a', 'status']);
      expect(log, ['status json=false dir=/a']);
    });
  });

  group('parameters', () {
    test(
      'positionals, options, defaults and flags reach the handler',
      () async {
        await _run(_spec(log), [
          'workers',
          'add',
          'gemini',
          '--name',
          'g1',
          '--force',
          '--json',
        ]);
        expect(log, [
          'add gemini name=g1 region=eu force=true json=true dir=null '
              'path=workers/add',
        ]);
      },
    );

    test('options may come before the positional', () async {
      await _run(_spec(log), ['workers', 'add', '--region', 'us', 'codex']);
      expect(log.single, contains('add codex'));
      expect(log.single, contains('region=us'));
    });

    test('a missing required positional is a usage error', () async {
      final result = await _run(_spec(log), ['workers', 'add']);
      expect(result.code, 64);
      expect(result.err, contains('Missing required argument "type"'));
      expect(result.err, contains('workers add [options] <type>'));
      expect(log, isEmpty);
    });

    test('too many positionals is a usage error', () async {
      final result = await _run(_spec(log), ['workers', 'add', 'a', 'b']);
      expect(result.code, 64);
      expect(result.err, contains('Unexpected argument "b"'));
    });

    test('optional and repeated positionals', () async {
      final spec = _spec(log);
      await _run(spec, ['work-dir']);
      await _run(spec, ['work-dir', '/x']);
      await _run(spec, ['run-all']);
      await _run(spec, ['run-all', 'a', 'b', 'c']);
      expect(log, [
        'work-dir null',
        'work-dir /x',
        'run-all ',
        'run-all a,b,c',
      ]);
    });

    test('values outside an enum are usage errors', () async {
      final result = await _run(_spec(log), [
        'workers',
        'add',
        'x',
        '--region',
        'mars',
      ]);
      expect(result.code, 64);
      expect(result.err, contains('mars'));
    });

    test('mandatory options are enforced', () async {
      final result = await _run(_spec(log), ['login']);
      expect(result.code, 64);
      expect(result.err, contains('token'));
      expect((await _run(_spec(log), ['login', '--token', 's3'])).code, 0);
      expect(log, ['login s3']);
    });
  });

  group('help', () {
    test('lists visible commands and global options', () async {
      final result = await _run(_spec(log, secretVisible: () => false), [
        '--help',
      ]);
      expect(result.code, 0);
      expect(result.out, contains('Test CLI'));
      expect(result.out, contains('--json'));
      expect(result.out, contains('workers'));
      expect(result.out, isNot(contains('maintenance')));
    });

    test('a command hidden from help can still run', () async {
      final spec = _spec(log, secretVisible: () => false);
      expect((await _run(spec, ['maintenance'])).code, 0);
      expect(log, ['maintenance']);
    });

    test('visibility is decided when help is printed', () async {
      var visible = false;
      final spec = _spec(log, secretVisible: () => visible);
      expect(
        (await _run(spec, ['--help'])).out,
        isNot(contains('maintenance')),
      );
      visible = true;
      expect((await _run(spec, ['--help'])).out, contains('maintenance'));
    });

    test('group and command help print to out', () async {
      final group = await _run(_spec(log), ['workers', '--help']);
      expect(group.code, 0);
      expect(group.out, contains('Available subcommands'));
      expect(group.out, contains('Add a worker.'));
      expect(log, isEmpty, reason: 'help must not run the default command');
      final command = await _run(_spec(log), ['workers', 'add', '--help']);
      expect(command.out, contains('--region'));
    });
  });

  group('--gui-manifest', () {
    test('prints the manifest without running anything', () async {
      final result = await _run(_spec(log), ['--gui-manifest=1']);
      expect(result.code, 0);
      expect(result.out, startsWith('..\n    manifestVersion 1'));
      expect(log, isEmpty);
    });

    test('unsupported versions exit 2', () async {
      final result = await _run(_spec(log), ['--gui-manifest=0']);
      expect(result.code, 2);
      expect(result.err, startsWith('t: '));
    });
  });
}

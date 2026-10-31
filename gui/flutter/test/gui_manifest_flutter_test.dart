import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gui_manifest_flutter/gui_manifest_flutter.dart';
import 'package:nanomarkup/nanomarkup.dart';

final _fixture = decode(
  File('../../conformance/fixtures/minimal.nano').readAsStringSync(),
);

class _FakeRunner implements CliRunner {
  _FakeRunner({this.manifest, this.outputs = const {}});

  final Object? manifest;
  final Map<String, String> outputs;
  final calls = <List<String>>[];

  @override
  String get executable => 'example';

  @override
  Future<GuiManifestModel> loadManifest() async =>
      GuiManifestModel.fromTree(manifest ?? _fixture);

  @override
  CliRun start(List<String> args) {
    calls.add(args);
    return CliRun(
      Future.value(
        CliResult(
          args: args,
          exitCode: 0,
          stdout: outputs[args.join(' ')] ?? '',
          stderr: '',
          duration: const Duration(milliseconds: 5),
        ),
      ),
      () {},
    );
  }
}

Future<void> _pump(WidgetTester tester, CliRunner runner) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(GuiManifestApp(runner: runner, title: 'Example'));
  await tester.pumpAndSettle();
}

/// A manifest with a group that has no main action, a subgroup, ungrouped
/// commands and a hidden one.
final Map<String, Object> _richManifest = {
  'manifestVersion': '1',
  'cli': {'name': 'x', 'version': '1', 'displayName': 'X'},
  'navigation': [
    {'id': 'status', 'label': 'Status', 'command': 'status'},
  ],
  'groups': [
    {'id': 'config', 'label': 'Config'},
    {'id': 'tools', 'label': 'Tools', 'parent': 'config'},
  ],
  'commands': [
    {
      'id': 'status',
      'argv': ['status'],
      'title': 'Status',
      'output': {'format': 'text', 'view': 'raw'},
    },
    {
      'id': 'config.show',
      'argv': ['config', 'show'],
      'title': 'Show config',
      'group': 'config',
    },
    {
      'id': 'config.tools.run',
      'argv': ['config', 'tools', 'run'],
      'title': 'Run tool',
      'group': 'tools',
    },
    {
      'id': 'version',
      'argv': ['version'],
      'title': 'Version',
    },
    {
      'id': 'secret',
      'argv': ['secret'],
      'title': 'Secret',
      'hidden': 'true',
    },
  ],
};

void main() {
  group('CommandSpec.buildArgs', () {
    final spec = GuiManifestModel.fromTree(_fixture).command('workers.remove')!;

    test('appends positionals', () {
      expect(spec.buildArgs({'id': 'w1'}), ['workers', 'remove', 'w1']);
    });

    test('requires required parameters', () {
      expect(() => spec.buildArgs({}), throwsArgumentError);
    });

    test('options and flags', () {
      const s = CommandSpec(
        id: 'x',
        argv: ['x'],
        title: 'X',
        parameters: [
          CommandParameter(name: 'name', kind: 'option', type: 'string'),
          CommandParameter(name: 'force', kind: 'flag', type: 'boolean'),
          CommandParameter(name: 'path', kind: 'positional', type: 'path'),
        ],
      );
      expect(s.buildArgs({'name': 'a b', 'force': 'true', 'path': '/p'}), [
        'x',
        '--name',
        'a b',
        '--force',
        '/p',
      ]);
      expect(s.buildArgs({'force': ''}), ['x']);
    });
  });

  test('invalid manifests are rejected with issue paths', () {
    expect(
      () => GuiManifestModel.fromTree({'manifestVersion': '1'}),
      throwsA(
        isA<ManifestException>().having(
          (e) => e.message,
          'message',
          contains(r'$.cli'),
        ),
      ),
    );
  });

  testWidgets('builds the sidebar and auto-runs the first entry', (
    tester,
  ) async {
    final runner = _FakeRunner(
      outputs: {
        'status --json': '{"state": "running", "slots": 2}',
        'workers list --json': '[{"id": "w1", "type": "gemini"}]',
      },
    );
    await _pump(tester, runner);

    expect(find.text('Example CLI'), findsOneWidget);
    expect(find.text('Workers'), findsOneWidget);
    // Every command is reachable from a main action, so there is no extra
    // "Commands" section.
    expect(find.text('Commands'), findsNothing);
    expect(find.text('Remove worker'), findsNothing, reason: 'group collapsed');
    expect(runner.calls, [
      ['status', '--json'],
    ]);
    expect(find.text('state'), findsOneWidget);
    expect(find.text('running'), findsOneWidget);

    await tester.tap(find.text('Workers'));
    await tester.pumpAndSettle();
    expect(runner.calls.last, ['workers', 'list', '--json']);
    expect(find.text('gemini'), findsOneWidget);
  });

  testWidgets('destructive command asks before running', (tester) async {
    final runner = _FakeRunner();
    await _pump(tester, runner);
    await tester.tap(find.byTooltip('Show Workers commands'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove worker').first);
    await tester.pumpAndSettle();

    final run = find.widgetWithText(FilledButton, 'Run');
    expect(
      tester.widget<FilledButton>(run).onPressed,
      isNull,
      reason: 'required id is empty',
    );

    await tester.enterText(find.byType(TextField), 'w1');
    await tester.pump();
    expect(find.textContaining('example workers remove w1'), findsOneWidget);

    await tester.tap(run);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(runner.calls.where((c) => c.contains('remove')), isEmpty);

    await tester.tap(run);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove worker'));
    await tester.pumpAndSettle();
    expect(runner.calls.last, ['workers', 'remove', 'w1']);
  });

  testWidgets('a group row opens its main page and shows its commands', (
    tester,
  ) async {
    final runner = _FakeRunner(
      outputs: {'workers list --json': '[{"id": "w1", "type": "gemini"}]'},
    );
    await _pump(tester, runner);
    await tester.tap(find.text('Workers'));
    await tester.pumpAndSettle();

    expect(runner.calls.last, ['workers', 'list', '--json']);
    expect(find.text('gemini'), findsOneWidget);
    expect(find.text('Remove worker'), findsOneWidget, reason: 'expanded');

    await tester.tap(find.byTooltip('Hide Workers commands'));
    await tester.pumpAndSettle();
    expect(find.text('Remove worker'), findsNothing);
    expect(find.text('gemini'), findsOneWidget, reason: 'page stays open');
  });

  testWidgets('groups without a main action get a section under Commands', (
    tester,
  ) async {
    final runner = _FakeRunner(manifest: _richManifest);
    await _pump(tester, runner);

    expect(find.text('Commands'), findsOneWidget);
    expect(find.text('Config'), findsOneWidget);
    expect(find.text('Version'), findsOneWidget);
    expect(find.text('Show config'), findsNothing, reason: 'collapsed');

    await tester.tap(find.text('Config'));
    await tester.pumpAndSettle();
    expect(find.text('Show config'), findsOneWidget);
    expect(find.text('Run tool'), findsNothing, reason: 'subgroup collapsed');
    expect(runner.calls.map((c) => c.first), [
      'status',
    ], reason: 'only the first main action ran; a section header runs nothing');

    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run tool'));
    await tester.pumpAndSettle();
    expect(find.text('Run tool').evaluate().length, greaterThan(1));
  });

  testWidgets('commandPages replace generated pages', (tester) async {
    final runner = _FakeRunner();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GuiManifestApp(
        runner: runner,
        title: 'Example',
        commandPages: {
          'status': (context, command, runner) => Text('custom ${command.id}'),
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('custom status'), findsOneWidget);
    expect(runner.calls, isEmpty, reason: 'custom page decides what to run');
  });

  testWidgets('shows an error screen when the manifest fails', (tester) async {
    await _pump(tester, _FakeRunner(manifest: 'not a manifest'));
    expect(find.textContaining('Invalid GUI manifest'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

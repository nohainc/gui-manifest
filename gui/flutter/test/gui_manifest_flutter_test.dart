import 'dart:async';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gui_manifest/gui_manifest.dart' show GuiIcons;
import 'package:gui_manifest_flutter/gui_manifest_flutter.dart';
import 'package:gui_manifest_flutter/src/result_card.dart';
import 'package:nanomarkup/nanomarkup.dart';

final _fixture = decode(
  File('../../conformance/fixtures/minimal.nano').readAsStringSync(),
);

class _FakeRunner implements CliRunner {
  _FakeRunner({
    this.manifest,
    this.outputs = const {},
    this.executable = 'example',
    this.hold = false,
  });

  final Object? manifest;
  final Map<String, String> outputs;
  final calls = <List<String>>[];

  /// Leaves every run unfinished until [finish] is called.
  final bool hold;
  final pending = <(List<String>, Completer<CliResult>)>[];
  final cancelled = <List<String>>[];

  CliResult _result(List<String> args) => CliResult(
    args: args,
    exitCode: 0,
    stdout: outputs[args.join(' ')] ?? '',
    stderr: '',
    duration: const Duration(milliseconds: 5),
  );

  /// Completes the oldest unfinished run.
  void finish() {
    final (args, completer) = pending.removeAt(0);
    completer.complete(_result(args));
  }

  @override
  final String executable;

  @override
  Future<GuiManifestModel> loadManifest() async =>
      GuiManifestModel.fromTree(manifest ?? _fixture);

  @override
  CliRun start(List<String> args) {
    calls.add(args);
    if (hold) {
      final completer = Completer<CliResult>();
      pending.add((args, completer));
      return CliRun(completer.future, () => cancelled.add(args));
    }
    return CliRun(Future.value(_result(args)), () {});
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

/// [_richManifest] with commands classified as reading (`info`) or doing
/// something, and one icon that this GUI does not know.
final Map<String, Object> _kindManifest = () {
  final copy = Map<String, Object>.from(_richManifest);
  final commands = [
    for (final c
        in (_richManifest['commands'] as List).cast<Map<String, Object>>())
      Map<String, Object>.from(c),
  ];
  Map<String, Object> byId(String id) =>
      commands.firstWhere((c) => c['id'] == id);
  byId('config.show')['kind'] = 'info';
  byId('version')['kind'] = 'info';
  byId('version')['icon'] = 'tag';
  byId('config.tools.run')['icon'] = 'no-such-icon';
  commands.add({
    'id': 'login',
    'argv': ['login'],
    'title': 'Sign in',
    'kind': 'action',
    'icon': 'login',
  });
  copy['commands'] = commands;
  return copy;
}();

void main() {
  group('CommandSpec.preview', () {
    const spec = CommandSpec(
      id: 'x',
      argv: ['x', '--json'],
      title: 'X',
      parameters: [
        CommandParameter(
          name: 'id',
          kind: 'positional',
          type: 'string',
          required: true,
        ),
        CommandParameter(name: 'name', kind: 'option', type: 'string'),
        CommandParameter(
          name: 'token',
          kind: 'option',
          type: 'secret',
          required: true,
        ),
        CommandParameter(name: 'force', kind: 'flag', type: 'boolean'),
      ],
    );

    test('uses the program name and shows placeholders for missing values', () {
      expect(
        spec.preview({}, program: 'mycli'),
        'mycli x --json --token <token> <id>',
      );
    });

    test('masks secrets, quotes values with spaces, adds flags', () {
      expect(
        spec.preview({
          'id': 'w 1',
          'name': "it's",
          'token': 's3cret',
          'force': 'true',
        }, program: 'mycli'),
        r"mycli x --json --name 'it'\''s' --token •••• --force 'w 1'",
      );
    });

    test('is the same line buildArgs executes when everything is given', () {
      final values = {'id': 'w1', 'token': 't', 'name': 'n'};
      expect(
        spec
            .preview(values, program: 'mycli')
            .replaceFirst('--token ••••', '--token t'),
        'mycli ${spec.buildArgs(values).join(' ')}',
      );
    });
  });

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
    // "COMMANDS" section.
    expect(find.text('COMMANDS'), findsNothing);
    expect(find.text('Remove worker'), findsNothing, reason: 'group collapsed');
    expect(runner.calls, [
      ['status', '--json'],
    ]);
    // Results are written as Nano Markup by default.
    expect(find.textContaining('state running'), findsOneWidget);
    expect(find.textContaining('slots 2'), findsOneWidget);

    await tester.tap(find.text('Workers'));
    await tester.pumpAndSettle();
    expect(runner.calls.last, ['workers', 'list', '--json']);
    expect(find.textContaining('type gemini'), findsOneWidget);
  });

  testWidgets('destructive command asks before running', (tester) async {
    final runner = _FakeRunner();
    await _pump(tester, runner);
    await tester.tap(find.text('Workers'));
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
    expect(find.textContaining('type gemini'), findsOneWidget);
    expect(find.text('Remove worker'), findsOneWidget, reason: 'expanded');

    // Tapping the open group again hides its commands, like a Space.
    await tester.tap(find.text('Workers'));
    await tester.pumpAndSettle();
    expect(find.text('Remove worker'), findsNothing);
    expect(
      find.textContaining('type gemini'),
      findsOneWidget,
      reason: 'page stays open',
    );

    await tester.tap(find.text('Workers'));
    await tester.pumpAndSettle();
    expect(find.text('Remove worker'), findsOneWidget, reason: 'shown again');
  });

  testWidgets('groups without a main action get a section under Commands', (
    tester,
  ) async {
    final runner = _FakeRunner(manifest: _richManifest);
    await _pump(tester, runner);

    expect(find.text('COMMANDS'), findsOneWidget);
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

  group('Syntila sidebar style', () {
    const selected = Color(0xffd3d5d7);
    const muted = Color(0xff434547);

    ThemeData theme() => ThemeData(
      extensions: const [
        GuiSidebarTheme(
          backgroundColor: Color(0xffe7e8ea),
          selectedColor: selected,
          textColor: muted,
          labelColor: Color(0xff535557),
          borderColor: Color(0xffd3d5d7),
        ),
      ],
    );

    Future<void> pumpThemed(WidgetTester tester, CliRunner runner) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        GuiManifestApp(runner: runner, title: 'Example', theme: theme()),
      );
      await tester.pumpAndSettle();
    }

    Color? rowColor(WidgetTester tester, String id) {
      final box = tester.widget<Container>(
        find.byKey(ValueKey('sidebar-row-$id')),
      );
      return (box.decoration as BoxDecoration).color;
    }

    TextStyle? style(WidgetTester tester, String label) =>
        tester.widget<Text>(find.text(label)).style;

    testWidgets('groups are Spaces and their commands are Threads', (
      tester,
    ) async {
      await pumpThemed(tester, _FakeRunner());
      await tester.tap(find.text('Workers'));
      await tester.pumpAndSettle();

      final space = tester.getSize(
        find.byKey(const ValueKey('sidebar-row-nav:workers')),
      );
      final thread = tester.getSize(
        find.byKey(const ValueKey('sidebar-row-cmd:workers.remove')),
      );
      expect(space.height, GuiSidebarMetrics.rowHeight);
      expect(thread.height, GuiSidebarMetrics.rowHeight);
      expect(style(tester, 'Workers')?.fontSize, 12.5);
      expect(style(tester, 'Remove worker')?.fontSize, 11.5);
      expect(style(tester, 'Workers')?.color, muted);
      // The Thread name starts a little right of the Space name.
      expect(
        tester.getTopLeft(find.text('Remove worker')).dx,
        greaterThan(tester.getTopLeft(find.text('Workers')).dx),
      );
      // Both show their manifest icon (never a folder): a Space at 16px, a
      // Thread a little smaller.
      Icon iconIn(String rowId, IconData icon) => tester.widget<Icon>(
        find.descendant(
          of: find.byKey(ValueKey('sidebar-row-$rowId')),
          matching: find.byIcon(icon),
        ),
      );
      expect(
        iconIn('nav:workers', iconFor('cpu')).size,
        GuiSidebarMetrics.iconSize,
      );
      expect(
        iconIn('cmd:workers.remove', iconFor('trash')).size,
        GuiSidebarMetrics.threadIconSize,
      );
      // An expandable row shows whether it is open.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('sidebar-row-nav:workers')),
          matching: find.byIcon(Icons.expand_less),
        ),
        findsOneWidget,
      );
    });

    testWidgets('selected and hovered rows use the host sidebar color', (
      tester,
    ) async {
      await pumpThemed(tester, _FakeRunner());
      expect(rowColor(tester, 'nav:status'), selected, reason: 'selected');
      expect(rowColor(tester, 'nav:workers'), Colors.transparent);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Workers')));
      await tester.pump();
      expect(rowColor(tester, 'nav:workers'), selected, reason: 'hovered');
      await mouse.moveTo(const Offset(900, 600));
      await tester.pump();
      expect(rowColor(tester, 'nav:workers'), Colors.transparent);
    });

    testWidgets('falls back to the color scheme without a host theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        GuiManifestApp(runner: _FakeRunner(), title: 'X'),
      );
      await tester.pumpAndSettle();
      final scheme = Theme.of(
        tester.element(find.text('Status').first),
      ).colorScheme;
      expect(rowColor(tester, 'nav:status'), scheme.secondaryContainer);
    });

    testWidgets('commands without a group are Spaces without Threads', (
      tester,
    ) async {
      await pumpThemed(tester, _FakeRunner(manifest: _richManifest));
      final version = find.byKey(const ValueKey('sidebar-row-cmd:version'));
      // No icon in the manifest: the default command icon, not a folder.
      expect(
        find.descendant(of: version, matching: find.byIcon(defaultCommandIcon)),
        findsOneWidget,
      );
      expect(defaultCommandIcon, Icons.terminal);
      expect(style(tester, 'Version')?.fontSize, 12.5);
      expect(tester.getSize(version).height, GuiSidebarMetrics.rowHeight);
    });
  });

  group('Settings', () {
    Future<void> pumpWith(
      WidgetTester tester,
      CliRunner runner, {
      ViewPreferencesStore? store,
    }) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        GuiManifestApp(
          runner: runner,
          title: 'Example',
          preferencesStore: store,
        ),
      );
      await tester.pumpAndSettle();
    }

    double scaleOf(WidgetTester tester) => MediaQuery.of(
      tester.element(find.text('Status').first),
    ).textScaler.scale(1);

    testWidgets('the settings icon follows the reload icon', (tester) async {
      await pumpWith(tester, _FakeRunner());
      final reload = tester.getCenter(find.byTooltip('Reload commands'));
      final settings = tester.getCenter(find.byTooltip('Settings'));
      expect(settings.dx, greaterThan(reload.dx));
      expect(settings.dy, reload.dy);
    });

    testWidgets('offers the Syntila text sizes and applies them', (
      tester,
    ) async {
      final store = ViewPreferencesStore.memory();
      await pumpWith(tester, _FakeRunner(), store: store);
      expect(scaleOf(tester), 1.0);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Text size'), findsOneWidget);
      expect(find.text('Makes text larger across the app.'), findsOneWidget);
      for (final label in ['Default', 'Large', 'Extra large']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(
        tester
            .widget<SegmentedButton<TextSizeOption>>(
              find.byKey(const ValueKey('setting-text-size')),
            )
            .selected,
        {TextSizeOption.standard},
      );

      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();
      expect(scaleOf(tester), closeTo(1.15, 1e-9));
      expect(store.load().textSize, TextSizeOption.large);

      await tester.tap(find.text('Extra large'));
      await tester.pumpAndSettle();
      expect(scaleOf(tester), closeTo(1.3, 1e-9));

      await tester.tap(find.text('Default'));
      await tester.pumpAndSettle();
      expect(scaleOf(tester), 1.0);
    });

    testWidgets('remembers the choice for the next launch', (tester) async {
      final store = ViewPreferencesStore.memory(
        const GuiViewPreferences(textSize: TextSizeOption.large).encode(),
      );
      await pumpWith(tester, _FakeRunner(), store: store);
      expect(scaleOf(tester), closeTo(1.15, 1e-9));
    });

    testWidgets('the settings page stays open while the sidebar is used', (
      tester,
    ) async {
      await pumpWith(tester, _FakeRunner());
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workers'));
      await tester.pumpAndSettle();
      expect(find.text('Text size'), findsNothing, reason: 'left Settings');
    });
  });

  group('view preferences', () {
    test('round trip and fall back to defaults', () {
      const large = GuiViewPreferences(
        textSize: TextSizeOption.large,
        outputFormat: OutputFormatOption.yaml,
      );
      expect(GuiViewPreferences.decode(large.encode()), large);
      // Settings saved before the output format existed still load.
      expect(
        GuiViewPreferences.decode('{"textSize":"large"}'),
        const GuiViewPreferences(textSize: TextSizeOption.large),
      );
      for (final raw in [null, '', 'nope', '[]', '{"textSize":"huge"}']) {
        expect(
          GuiViewPreferences.decode(raw).textSize,
          TextSizeOption.standard,
          reason: '$raw',
        );
      }
      expect(TextSizeOption.values.map((o) => (o.label, o.scale)), [
        ('Default', 1.0),
        ('Large', 1.15),
        ('Extra large', 1.3),
      ]);
    });

    test('a file store keeps the choice between runs', () {
      final dir = Directory.systemTemp.createTempSync('gm_prefs');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/nested/view-preferences.json');
      ViewPreferencesStore.file(
        file,
      ).save(const GuiViewPreferences(textSize: TextSizeOption.extraLarge));
      expect(
        ViewPreferencesStore.file(file).load().textSize,
        TextSizeOption.extraLarge,
      );
      expect(
        ViewPreferencesStore.file(
          File('${dir.path}/none.json'),
        ).load().textSize,
        TextSizeOption.standard,
      );
    });

    test('forApp chooses the platform settings folder', () {
      // Each platform gets its own folder under a temporary home.
      for (final (expected, mac, win) in [
        ('Library/Application Support/my-app', true, false),
        ('.config/my-app', false, false),
        ('AppData/my-app', false, true),
      ]) {
        final home = Directory.systemTemp.createTempSync('gm_home');
        addTearDown(() => home.deleteSync(recursive: true));
        ViewPreferencesStore.forApp(
          'my-app',
          environment: win
              ? {'APPDATA': '${home.path}/AppData'}
              : {'HOME': home.path},
          isMacOS: mac,
          isWindows: win,
        ).save(const GuiViewPreferences(textSize: TextSizeOption.large));
        expect(
          File('${home.path}/$expected/view-preferences.json').existsSync(),
          isTrue,
          reason: expected,
        );
      }
    });

    test('XDG_CONFIG_HOME wins on Linux; no home keeps it in memory', () {
      final xdg = Directory.systemTemp.createTempSync('gm_xdg');
      addTearDown(() => xdg.deleteSync(recursive: true));
      ViewPreferencesStore.forApp(
        'my-app',
        environment: {'XDG_CONFIG_HOME': xdg.path, 'HOME': '/nonexistent'},
        isMacOS: false,
        isWindows: false,
      ).save(const GuiViewPreferences(textSize: TextSizeOption.large));
      expect(
        File('${xdg.path}/my-app/view-preferences.json').existsSync(),
        isTrue,
      );

      final memory = ViewPreferencesStore.forApp(
        'my-app',
        environment: const {},
        isMacOS: false,
        isWindows: false,
      );
      memory.save(const GuiViewPreferences(textSize: TextSizeOption.large));
      expect(memory.load().textSize, TextSizeOption.large);
    });
  });

  group('content', () {
    Future<void> openWorkers(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('sidebar-row-nav:workers')));
      await tester.pumpAndSettle();
    }

    String commandLine(WidgetTester tester) => tester
        .widget<SelectableText>(find.byKey(const ValueKey('command-line')))
        .textSpan!
        .toPlainText();

    testWidgets('the command line follows the description, without a path', (
      tester,
    ) async {
      final runner = _FakeRunner(
        executable: '/opt/some/very/long/path/example',
      );
      await _pump(tester, runner);
      await openWorkers(tester);
      await tester.tap(find.text('Remove worker'));
      await tester.pumpAndSettle();

      // The CLI's name, not where it is installed; a missing value is a
      // placeholder until it is entered.
      expect(commandLine(tester), r'$ example workers remove <id>');
      await tester.enterText(find.byType(TextField), 'w1');
      await tester.pump();
      expect(commandLine(tester), r'$ example workers remove w1');
      await tester.enterText(find.byType(TextField), 'two words');
      await tester.pump();
      expect(commandLine(tester), r"$ example workers remove 'two words'");
      expect(find.textContaining('/opt/some'), findsNothing);

      // Title, description, command line, then the form and Run.
      double top(Finder f) => tester.getTopLeft(f).dy;
      expect(
        top(find.text('Remove worker').last),
        lessThan(top(find.text('Remove worker.'))),
      );
      expect(
        top(find.text('Remove worker.')),
        lessThan(top(find.byKey(const ValueKey('command-line')))),
      );
      expect(
        top(find.byKey(const ValueKey('command-line'))),
        lessThan(top(find.byType(TextField))),
      );
    });

    testWidgets('a result shows the executed command with a \$, no path', (
      tester,
    ) async {
      final runner = _FakeRunner(
        executable: '/opt/some/very/long/path/example',
      );
      await _pump(tester, runner);
      // Status ran when the app opened.
      expect(find.byType(ResultCard), findsOneWidget);
      expect(find.text(r'$ example status --json'), findsNWidgets(2));
      expect(find.textContaining('/opt/some'), findsNothing);
      expect(runner.calls.single, ['status', '--json']);
    });

    testWidgets('results pile up instead of replacing each other', (
      tester,
    ) async {
      final runner = _FakeRunner(
        outputs: {'workers list --json': '[{"id": "w1", "type": "gemini"}]'},
      );
      await _pump(tester, runner);
      await openWorkers(tester);
      expect(find.byType(ResultCard), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Run'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Run'));
      await tester.pumpAndSettle();
      expect(find.byType(ResultCard), findsNWidgets(3));
      expect(runner.calls.where((c) => c.first == 'workers'), hasLength(3));
    });

    testWidgets('results survive opening another page', (tester) async {
      final runner = _FakeRunner(
        outputs: {'workers list --json': '[{"id": "w1", "type": "gemini"}]'},
      );
      await _pump(tester, runner);
      await openWorkers(tester);
      expect(find.textContaining('type gemini'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('sidebar-row-nav:status')));
      await tester.pumpAndSettle();
      expect(find.textContaining('type gemini'), findsNothing);
      await openWorkers(tester);

      expect(find.textContaining('type gemini'), findsOneWidget);
      expect(
        runner.calls.where((c) => c.first == 'workers'),
        hasLength(1),
        reason: 'coming back does not rerun it',
      );
      // And the other page kept its result too.
      await tester.tap(find.byKey(const ValueKey('sidebar-row-nav:status')));
      await tester.pumpAndSettle();
      expect(find.byType(ResultCard), findsOneWidget);
      expect(runner.calls.where((c) => c.first == 'status'), hasLength(1));
    });

    testWidgets('Clear results removes them only when asked', (tester) async {
      final runner = _FakeRunner();
      await _pump(tester, runner);
      expect(find.byType(ResultCard), findsOneWidget);
      await tester.tap(find.text('Clear results'));
      await tester.pumpAndSettle();
      expect(find.byType(ResultCard), findsNothing);
      expect(find.text('Clear results'), findsNothing);
    });

    /// Frames without waiting for animations: a held command's progress
    /// spinner never settles.
    Future<void> frames(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> start(WidgetTester tester, _FakeRunner runner) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(GuiManifestApp(runner: runner, title: 'Example'));
      await frames(tester);
      runner.finish(); // Status, which runs when the app opens.
      await frames(tester);
    }

    Future<void> select(WidgetTester tester, String row) async {
      await tester.tap(find.byKey(ValueKey('sidebar-row-nav:$row')));
      await frames(tester);
    }

    testWidgets('a command keeps running when its page is closed', (
      tester,
    ) async {
      final runner = _FakeRunner(
        hold: true,
        outputs: {'workers list --json': '[{"id": "w1", "type": "gemini"}]'},
      );
      await start(tester, runner);
      await select(tester, 'workers');
      expect(find.text('Running…'), findsOneWidget);

      await select(tester, 'status');
      expect(runner.cancelled, isEmpty, reason: 'leaving does not stop it');

      runner.finish();
      await frames(tester);
      await select(tester, 'workers');
      expect(find.text('Running…'), findsNothing);
      expect(find.textContaining('type gemini'), findsOneWidget);
    });

    testWidgets('Cancel stops a running command from another visit', (
      tester,
    ) async {
      final runner = _FakeRunner(hold: true);
      await start(tester, runner);
      await select(tester, 'workers');
      await select(tester, 'status');
      await select(tester, 'workers');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await frames(tester);
      expect(runner.cancelled, [
        ['workers', 'list', '--json'],
      ]);
    });
  });

  group('output format', () {
    const status = {'status --json': '{"state": "running", "slots": 2}'};

    Future<void> openSettingsAnd(WidgetTester tester, String format) async {
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(format));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sidebar-row-nav:status')));
      await tester.pumpAndSettle();
    }

    testWidgets('results are written as Nano Markup by default', (
      tester,
    ) async {
      await _pump(tester, _FakeRunner(outputs: status));
      expect(find.textContaining('state running'), findsOneWidget);
      expect(find.textContaining('..'), findsWidgets);
      expect(find.text('Nano'), findsOneWidget, reason: 'tab label');
    });

    testWidgets('Settings offers Nano first, then JSON and YAML', (
      tester,
    ) async {
      await _pump(tester, _FakeRunner(outputs: status));
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Output format'), findsOneWidget);
      final x = [
        for (final label in ['Nano', 'JSON', 'YAML'])
          tester.getCenter(find.text(label)).dx,
      ];
      expect(x[0], lessThan(x[1]));
      expect(x[1], lessThan(x[2]));
      expect(
        tester
            .widget<SegmentedButton<OutputFormatOption>>(
              find.byKey(const ValueKey('setting-output-format')),
            )
            .selected,
        {OutputFormatOption.nano},
      );
    });

    testWidgets('changing it rewrites earlier results', (tester) async {
      final store = ViewPreferencesStore.memory();
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        GuiManifestApp(
          runner: _FakeRunner(outputs: status),
          title: 'Example',
          preferencesStore: store,
        ),
      );
      await tester.pumpAndSettle();

      await openSettingsAnd(tester, 'JSON');
      expect(find.textContaining('"state": "running"'), findsOneWidget);
      expect(store.load().outputFormat, OutputFormatOption.json);

      await openSettingsAnd(tester, 'YAML');
      expect(find.textContaining('state: running'), findsOneWidget);
      expect(find.textContaining('slots: 2'), findsOneWidget);

      await openSettingsAnd(tester, 'Nano');
      expect(find.textContaining('state running'), findsOneWidget);
    });

    testWidgets('the choice is remembered', (tester) async {
      final store = ViewPreferencesStore.memory(
        const GuiViewPreferences(
          outputFormat: OutputFormatOption.yaml,
        ).encode(),
      );
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        GuiManifestApp(
          runner: _FakeRunner(outputs: status),
          title: 'Example',
          preferencesStore: store,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('state: running'), findsOneWidget);
    });

    testWidgets('the original output is one tap away', (tester) async {
      await _pump(tester, _FakeRunner(outputs: status));
      expect(find.textContaining('{"state"'), findsNothing);
      await tester.tap(find.text('Show original output'));
      await tester.pump();
      expect(find.text('{"state": "running", "slots": 2}'), findsOneWidget);
      await tester.tap(find.text('Show as Nano'));
      await tester.pump();
      expect(find.textContaining('{"state"'), findsNothing);
    });

    testWidgets('a table view is available next to the text', (tester) async {
      final runner = _FakeRunner(
        outputs: {'workers list --json': '[{"id": "w1", "type": "gemini"}]'},
      );
      await _pump(tester, runner);
      await tester.tap(find.byKey(const ValueKey('sidebar-row-nav:workers')));
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsNothing);
      await tester.tap(find.text('Table'));
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('gemini'), findsOneWidget);
    });

    testWidgets('plain text output is shown as printed', (tester) async {
      final manifest = {
        'manifestVersion': '1',
        'cli': {'name': 'x', 'version': '1'},
        'navigation': [
          {'id': 'hi', 'label': 'Hi', 'command': 'hi'},
        ],
        'commands': [
          {
            'id': 'hi',
            'argv': ['hi'],
            'title': 'Hi',
            'output': {'format': 'text', 'view': 'raw'},
          },
        ],
      };
      await _pump(
        tester,
        _FakeRunner(manifest: manifest, outputs: {'hi': 'hello world\n'}),
      );
      expect(find.text('hello world'), findsOneWidget);
      expect(find.text('Table'), findsNothing);
      expect(find.text('Show original output'), findsNothing);
    });
  });

  group('INFO and ACTIONS', () {
    testWidgets('read-only commands and actions get their own sections', (
      tester,
    ) async {
      await _pump(tester, _FakeRunner(manifest: _kindManifest));
      double y(String label) => tester.getTopLeft(find.text(label)).dy;
      expect(find.text('INFO'), findsOneWidget);
      expect(find.text('ACTIONS'), findsOneWidget);
      expect(find.text('COMMANDS'), findsNothing);
      expect(y('INFO'), lessThan(y('Version')));
      expect(y('Version'), lessThan(y('ACTIONS')));
      expect(y('ACTIONS'), lessThan(y('Sign in')));
    });
  });

  group('icons', () {
    testWidgets('rows show the manifest icon or the default command icon', (
      tester,
    ) async {
      await _pump(tester, _FakeRunner(manifest: _kindManifest));
      Finder iconIn(String rowId, IconData icon) => find.descendant(
        of: find.byKey(ValueKey('sidebar-row-$rowId')),
        matching: find.byIcon(icon),
      );
      expect(iconIn('cmd:version', iconFor('tag')), findsOneWidget);
      expect(iconIn('cmd:login', iconFor('login')), findsOneWidget);
      // No icon declared: the default, never a folder.
      expect(iconIn('cmd:version', Icons.folder_outlined), findsNothing);
      // Open Config > Tools: a name this GUI does not know also falls back.
      await tester.tap(
        find.byKey(const ValueKey('sidebar-row-group:config:action')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('sidebar-row-group:tools:action')),
      );
      await tester.pumpAndSettle();
      expect(
        iconIn('cmd:config.tools.run', defaultCommandIcon),
        findsOneWidget,
      );
    });

    test(
      'every name in the vocabulary has a glyph and unknown names fall back',
      () {
        for (final name in GuiIcons.all) {
          expect(manifestIcons.containsKey(name), isTrue, reason: name);
        }
        expect(manifestIcons.length, GuiIcons.all.length);
        expect(iconFor(null), defaultCommandIcon);
        expect(iconFor('no-such-icon'), defaultCommandIcon);
        expect(iconFor(GuiIcons.command), defaultCommandIcon);
        expect(iconFor(GuiIcons.cpu), isNot(defaultCommandIcon));
      },
    );
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

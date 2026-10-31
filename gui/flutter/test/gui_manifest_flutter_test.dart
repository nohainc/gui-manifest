import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

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
    // "COMMANDS" section.
    expect(find.text('COMMANDS'), findsNothing);
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
    expect(find.text('gemini'), findsOneWidget);
    expect(find.text('Remove worker'), findsOneWidget, reason: 'expanded');

    // Tapping the open group again hides its commands, like a Space.
    await tester.tap(find.text('Workers'));
    await tester.pumpAndSettle();
    expect(find.text('Remove worker'), findsNothing);
    expect(find.text('gemini'), findsOneWidget, reason: 'page stays open');

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
      // A Space shows a folder icon; a Thread leaves that slot empty.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('sidebar-row-nav:workers')),
          matching: find.byType(GuiFolderIcon),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('sidebar-row-cmd:workers.remove')),
          matching: find.byType(GuiFolderIcon),
        ),
        findsNothing,
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
      expect(
        find.descendant(of: version, matching: find.byType(GuiFolderIcon)),
        findsOneWidget,
      );
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
      const large = GuiViewPreferences(textSize: TextSizeOption.large);
      expect(GuiViewPreferences.decode(large.encode()), large);
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

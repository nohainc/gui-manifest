import 'package:flutter/material.dart';

import 'cli_runner.dart';
import 'command_page.dart';
import 'manifest.dart';
import 'settings_page.dart';
import 'sidebar.dart';
import 'sidebar_model.dart';
import 'view_preferences.dart';

/// Builds a host-registered screen for a `builtin` navigation entry.
typedef BuiltinScreenBuilder =
    Widget Function(
      BuildContext context,
      CliRunner runner,
      GuiManifestModel manifest,
    );

/// Replaces the generated page of one manifest command.
typedef CommandPageBuilder =
    Widget Function(
      BuildContext context,
      CommandSpec command,
      CliRunner runner,
    );

/// A complete desktop app for one CLI.
///
/// The host app supplies the CLI, theme and optional custom screens; all
/// navigation and command pages come from the CLI's `--gui-manifest`.
class GuiManifestApp extends StatelessWidget {
  const GuiManifestApp({
    super.key,
    required this.runner,
    required this.title,
    this.theme,
    this.darkTheme,
    this.themeMode = ThemeMode.system,
    this.builtins = const {},
    this.commandPages = const {},
    this.preferencesStore,
    this.logo,
  });

  final CliRunner runner;
  final String title;
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeMode themeMode;
  final Map<String, BuiltinScreenBuilder> builtins;

  /// Custom pages by command id; other commands get the generated page.
  final Map<String, CommandPageBuilder> commandPages;

  /// Where view settings (text size) are kept; they last only for the
  /// session when null.
  final ViewPreferencesStore? preferencesStore;
  final Widget? logo;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: title,
    theme: theme,
    darkTheme: darkTheme,
    themeMode: themeMode,
    debugShowCheckedModeBanner: false,
    home: GuiManifestShell(
      runner: runner,
      title: title,
      builtins: builtins,
      commandPages: commandPages,
      preferencesStore: preferencesStore,
      logo: logo,
    ),
  );
}

/// Sidebar + content shell. Usable inside an existing [MaterialApp].
class GuiManifestShell extends StatefulWidget {
  const GuiManifestShell({
    super.key,
    required this.runner,
    required this.title,
    this.builtins = const {},
    this.commandPages = const {},
    this.preferencesStore,
    this.logo,
  });

  final CliRunner runner;
  final String title;
  final Map<String, BuiltinScreenBuilder> builtins;
  final Map<String, CommandPageBuilder> commandPages;
  final ViewPreferencesStore? preferencesStore;
  final Widget? logo;

  @override
  State<GuiManifestShell> createState() => _GuiManifestShellState();
}

class _GuiManifestShellState extends State<GuiManifestShell> {
  late Future<GuiManifestModel> _manifest = widget.runner.loadManifest();
  String? _selected;

  /// Ids of expanded sidebar rows.
  final _expanded = <String>{};

  late final ViewPreferencesStore _store =
      widget.preferencesStore ?? ViewPreferencesStore.memory();
  late GuiViewPreferences _preferences = _store.load();

  void _setPreferences(GuiViewPreferences value) {
    setState(() => _preferences = value);
    _store.save(value);
  }

  void _reload() => setState(() {
    _manifest = widget.runner.loadManifest();
  });

  bool _navVisible(GuiManifestModel m, NavEntry n) =>
      n.command != null && m.command(n.command!) != null ||
      n.builtin != null && widget.builtins.containsKey(n.builtin);

  void _select(SidebarModel sidebar, String key) => setState(() {
    _selected = key;
    // Open the groups that lead to the page (not the page's own group: a tap
    // on it decides that).
    for (final entry in sidebar.pathTo(key).reversed.skip(1)) {
      if (entry.isExpandable) _expanded.add(entry.id);
    }
  });

  void _toggle(String id) => setState(() {
    if (!_expanded.remove(id)) _expanded.add(id);
  });

  Widget _commandPage(String key, CommandSpec command, {bool autoRun = false}) {
    final custom = widget.commandPages[command.id];
    if (custom != null) {
      return KeyedSubtree(
        key: ValueKey(key),
        child: custom(context, command, widget.runner),
      );
    }
    return CommandPage(
      key: ValueKey(key),
      command: command,
      runner: widget.runner,
      autoRun: autoRun,
    );
  }

  Widget _content(GuiManifestModel m, String key) {
    if (key == settingsPageKey) {
      return SettingsPage(
        preferences: _preferences,
        onChanged: _setPreferences,
      );
    }
    if (key.startsWith('nav:')) {
      final id = key.substring(4);
      final entry = m.navigation.firstWhere((n) => n.id == id);
      if (entry.builtin != null) {
        return widget.builtins[entry.builtin]!(context, widget.runner, m);
      }
      return _commandPage(key, m.command(entry.command!)!, autoRun: true);
    }
    return _commandPage(key, m.command(key.substring(4))!);
  }

  @override
  Widget build(BuildContext context) {
    // The text size applies to the whole shell, like the Syntila app.
    final media = MediaQuery.of(context);
    final scale = (media.textScaler.scale(1) * _preferences.textSize.scale)
        .clamp(1.0, 1.6);
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: FutureBuilder<GuiManifestModel>(
          future: _manifest,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorScreen(error: '${snapshot.error}', onRetry: _reload);
            }
            final m = snapshot.data;
            if (m == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final sidebar = buildSidebar(
              m,
              navVisible: (n) => _navVisible(m, n),
            );
            final keys = sidebar.keys.toList();
            final selected = _selected == settingsPageKey
                ? settingsPageKey
                : keys.contains(_selected)
                ? _selected!
                : keys.isEmpty
                ? null
                : keys.first;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GuiSidebar(
                  header:
                      widget.logo ??
                      Text(
                        m.cli.displayName ?? widget.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                  version: m.cli.version,
                  model: sidebar,
                  selected: selected,
                  expanded: _expanded,
                  onSelect: (key) => _select(sidebar, key),
                  onToggle: _toggle,
                  onReload: _reload,
                  onOpenSettings: () =>
                      setState(() => _selected = settingsPageKey),
                ),
                Expanded(
                  child: selected == null
                      ? const Center(child: Text('This CLI has no commands.'))
                      : _content(m, selected),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 40,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          SelectableText(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

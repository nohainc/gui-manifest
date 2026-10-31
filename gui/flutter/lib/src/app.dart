import 'package:flutter/material.dart';

import 'cli_runner.dart';
import 'command_page.dart';
import 'icons.dart';
import 'manifest.dart';
import 'sidebar_model.dart';

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
    this.logo,
  });

  final CliRunner runner;
  final String title;
  final Map<String, BuiltinScreenBuilder> builtins;
  final Map<String, CommandPageBuilder> commandPages;
  final Widget? logo;

  @override
  State<GuiManifestShell> createState() => _GuiManifestShellState();
}

class _GuiManifestShellState extends State<GuiManifestShell> {
  late Future<GuiManifestModel> _manifest = widget.runner.loadManifest();
  String? _selected;

  /// Ids of expanded sidebar rows.
  final _expanded = <String>{};

  void _reload() => setState(() {
    _manifest = widget.runner.loadManifest();
  });

  bool _navVisible(GuiManifestModel m, NavEntry n) =>
      n.command != null && m.command(n.command!) != null ||
      n.builtin != null && widget.builtins.containsKey(n.builtin);

  void _select(SidebarModel sidebar, String key) => setState(() {
    _selected = key;
    // Open the rows that lead to the page.
    for (final entry in sidebar.pathTo(key)) {
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
    return Scaffold(
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
          final sidebar = buildSidebar(m, navVisible: (n) => _navVisible(m, n));
          final keys = sidebar.keys.toList();
          final selected = keys.contains(_selected)
              ? _selected!
              : keys.isEmpty
              ? null
              : keys.first;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Sidebar(
                header:
                    widget.logo ??
                    Text(
                      m.cli.displayName ?? widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                version: m.cli.version,
                sidebar: sidebar,
                selected: selected,
                expanded: {
                  ..._expanded,
                  // The rows leading to the open page stay open (the page's own
                  // row can still be collapsed).
                  if (selected != null)
                    for (final e in sidebar.pathTo(selected).reversed.skip(1))
                      e.id,
                },
                onSelect: (key) => _select(sidebar, key),
                onToggle: _toggle,
                onReload: _reload,
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: selected == null
                    ? const Center(child: Text('This CLI has no commands.'))
                    : _content(m, selected),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.header,
    required this.version,
    required this.sidebar,
    required this.selected,
    required this.expanded,
    required this.onSelect,
    required this.onToggle,
    required this.onReload,
  });

  final Widget header;
  final String version;
  final SidebarModel sidebar;
  final String? selected;
  final Set<String> expanded;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onToggle;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.all(16), child: header),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final entry in sidebar.primary) _row(context, entry, 0),
                if (sidebar.more.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
                    child: Text(
                      'Commands',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (final entry in sidebar.more) _row(context, entry, 0),
                ],
              ],
            ),
          ),
          ListTile(
            dense: true,
            title: Text('v$version', style: theme.textTheme.bodySmall),
            trailing: IconButton(
              tooltip: 'Reload commands',
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: onReload,
            ),
          ),
        ],
      ),
    );
  }

  /// One row, plus its children when expanded.
  Widget _row(BuildContext context, SidebarEntry entry, int depth) {
    final theme = Theme.of(context);
    final open = expanded.contains(entry.id);
    final tile = ListTile(
      dense: true,
      contentPadding: EdgeInsets.only(left: 16.0 + depth * 16, right: 4),
      leading: entry.icon == null && depth > 0
          ? null
          : Icon(iconFor(entry.icon), size: 20),
      title: Text(entry.label, overflow: TextOverflow.ellipsis),
      selected: entry.selectKey != null && entry.selectKey == selected,
      selectedTileColor: theme.colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      trailing: entry.isExpandable
          ? IconButton(
              tooltip: '${open ? 'Hide' : 'Show'} ${entry.label} commands',
              icon: Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              onPressed: () => onToggle(entry.id),
            )
          : null,
      onTap: () {
        final key = entry.selectKey;
        if (key != null) {
          onSelect(key);
        } else {
          onToggle(entry.id);
        }
      },
    );
    if (!entry.isExpandable || !open) return tile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tile,
        for (final child in entry.children) _row(context, child, depth + 1),
      ],
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

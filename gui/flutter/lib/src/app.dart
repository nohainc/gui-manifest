import 'package:flutter/material.dart';

import 'cli_runner.dart';
import 'command_page.dart';
import 'icons.dart';
import 'manifest.dart';

/// Builds a host-registered screen for a `builtin` navigation entry.
typedef BuiltinScreenBuilder =
    Widget Function(
      BuildContext context,
      CliRunner runner,
      GuiManifestModel manifest,
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
    this.logo,
  });

  final CliRunner runner;
  final String title;
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeMode themeMode;
  final Map<String, BuiltinScreenBuilder> builtins;
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
    this.logo,
  });

  final CliRunner runner;
  final String title;
  final Map<String, BuiltinScreenBuilder> builtins;
  final Widget? logo;

  @override
  State<GuiManifestShell> createState() => _GuiManifestShellState();
}

/// A sidebar destination: a manifest nav entry or a command from "All
/// commands".
typedef _Destination = ({String key, String label, IconData icon});

class _GuiManifestShellState extends State<GuiManifestShell> {
  late Future<GuiManifestModel> _manifest = widget.runner.loadManifest();
  String? _selected;

  void _reload() => setState(() {
    _manifest = widget.runner.loadManifest();
  });

  List<NavEntry> _visibleNav(GuiManifestModel m) => [
    for (final n in m.navigation)
      if (n.command != null && m.command(n.command!) != null ||
          n.builtin != null && widget.builtins.containsKey(n.builtin))
        n,
  ];

  List<CommandSpec> _otherCommands(GuiManifestModel m) {
    final linked = {for (final n in m.navigation) n.command};
    return [
      for (final c in m.commands)
        if (!c.hidden && !linked.contains(c.id)) c,
    ];
  }

  Widget _content(GuiManifestModel m, String key) {
    if (key.startsWith('nav:')) {
      final id = key.substring(4);
      final entry = m.navigation.firstWhere((n) => n.id == id);
      if (entry.builtin != null) {
        return widget.builtins[entry.builtin]!(context, widget.runner, m);
      }
      return CommandPage(
        key: ValueKey(key),
        command: m.command(entry.command!)!,
        runner: widget.runner,
        autoRun: true,
      );
    }
    return CommandPage(
      key: ValueKey(key),
      command: m.command(key.substring(4))!,
      runner: widget.runner,
    );
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
          final nav = _visibleNav(m);
          final others = _otherCommands(m);
          final destinations = <_Destination>[
            for (final n in nav)
              (key: 'nav:${n.id}', label: n.label, icon: iconFor(n.icon)),
          ];
          final commandDestinations = <_Destination>[
            for (final c in others)
              (key: 'cmd:${c.id}', label: c.title, icon: fallbackIcon),
          ];
          final all = [...destinations, ...commandDestinations];
          final selected = all.any((d) => d.key == _selected)
              ? _selected!
              : all.isEmpty
              ? null
              : all.first.key;
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
                primary: destinations,
                commands: commandDestinations,
                selected: selected,
                onSelect: (key) => setState(() => _selected = key),
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
    required this.primary,
    required this.commands,
    required this.selected,
    required this.onSelect,
    required this.onReload,
  });

  final Widget header;
  final String version;
  final List<_Destination> primary;
  final List<_Destination> commands;
  final String? selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget item(_Destination d) => ListTile(
      dense: true,
      leading: Icon(d.icon, size: 20),
      title: Text(d.label, overflow: TextOverflow.ellipsis),
      selected: d.key == selected,
      selectedTileColor: theme.colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () => onSelect(d.key),
    );
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
                ...primary.map(item),
                if (commands.isNotEmpty)
                  ExpansionTile(
                    title: Text(
                      'All commands',
                      style: theme.textTheme.labelLarge,
                    ),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 8),
                    initiallyExpanded: commands.any((d) => d.key == selected),
                    children: commands.map(item).toList(),
                  ),
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

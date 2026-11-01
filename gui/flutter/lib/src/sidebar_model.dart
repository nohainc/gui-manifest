import 'manifest.dart';

/// One row of the sidebar: a selectable page, a section that only expands, or
/// a page that also expands (a group's main action with its other commands).
final class SidebarEntry {
  const SidebarEntry({
    required this.id,
    required this.label,
    this.icon,
    this.selectKey,
    this.children = const [],
  });

  /// Unique within the sidebar; used to remember expansion.
  final String id;
  final String label;

  /// Manifest icon name; null shows the default command icon.
  final String? icon;

  /// Page this row opens (`nav:<id>` or `cmd:<id>`); null for a section header.
  final String? selectKey;
  final List<SidebarEntry> children;

  bool get isExpandable => children.isNotEmpty;

  /// Every page key at or below this row.
  Iterable<String> get keys sync* {
    if (selectKey != null) yield selectKey!;
    for (final child in children) {
      yield* child.keys;
    }
  }
}

/// A labelled block of rows under the main actions, e.g. `INFO`.
final class SidebarSection {
  const SidebarSection({required this.label, required this.entries});

  final String label;
  final List<SidebarEntry> entries;

  /// Every page key in this section.
  Iterable<String> get keys => entries.expand((e) => e.keys);
}

/// The sidebar as data: [primary] rows are the CLI's main actions, [sections]
/// hold every other command, split into what only reads (`INFO`) and what
/// does something (`ACTIONS`).
final class SidebarModel {
  const SidebarModel({required this.primary, required this.sections});

  final List<SidebarEntry> primary;
  final List<SidebarSection> sections;

  Iterable<SidebarEntry> get _all sync* {
    yield* primary;
    for (final section in sections) {
      yield* section.entries;
    }
  }

  /// All page keys in display order.
  Iterable<String> get keys sync* {
    for (final entry in _all) {
      yield* entry.keys;
    }
  }

  /// The rows from the top down to the one that opens [key] (empty if none).
  List<SidebarEntry> pathTo(String key) {
    List<SidebarEntry>? search(SidebarEntry entry) {
      if (entry.selectKey == key) return [entry];
      for (final child in entry.children) {
        final found = search(child);
        if (found != null) return [entry, ...found];
      }
      return null;
    }

    for (final entry in _all) {
      final found = search(entry);
      if (found != null) return found;
    }
    return const [];
  }
}

/// Builds the sidebar from a manifest.
///
/// A navigation entry whose id is the group of the command it opens becomes
/// one expandable row: its label opens that command and the rest of the
/// group's commands sit under it. Every other command goes under one of two
/// sections by its [CommandKind]: `INFO` for commands that only read and
/// `ACTIONS` for those that do something. A group with commands of both kinds
/// appears in both, holding the matching ones. When no command is `info` (a
/// manifest that does not classify) there is a single `COMMANDS` section.
/// Commands marked hidden never appear and a command that is already a main
/// action is not repeated.
SidebarModel buildSidebar(
  GuiManifestModel manifest, {
  bool Function(NavEntry entry)? navVisible,
}) {
  final nav = [
    for (final n in manifest.navigation)
      if (navVisible?.call(n) ?? true) n,
  ];
  final navTargets = {
    for (final n in nav)
      if (n.command != null) n.command!,
  };
  bool listed(CommandSpec c) => !c.hidden && !navTargets.contains(c.id);

  final usedGroups = <String>{};
  final primary = <SidebarEntry>[];
  for (final n in nav) {
    final command = n.command == null ? null : manifest.command(n.command!);
    final groupId = command?.group;
    final group = groupId == null ? null : manifest.group(groupId);
    final isGroupEntry = group != null && group.id == n.id;
    if (isGroupEntry) usedGroups.add(group.id);
    primary.add(
      SidebarEntry(
        id: 'nav:${n.id}',
        label: n.label,
        icon: n.icon,
        selectKey: 'nav:${n.id}',
        children: isGroupEntry
            ? _childrenOf(manifest, group.id, (c) => listed(c), '')
            : const [],
      ),
    );
  }

  String rootOf(String groupId) {
    var current = groupId;
    final seen = <String>{};
    while (seen.add(current)) {
      final parent = manifest.group(current)?.parent;
      if (parent == null || manifest.group(parent) == null) break;
      current = parent;
    }
    return current;
  }

  /// The commands outside the main actions that match [accept], grouped.
  List<SidebarEntry> others(bool Function(CommandSpec) accept, String tag) {
    bool wanted(CommandSpec c) => listed(c) && accept(c);
    final entries = <SidebarEntry>[];
    final seenRoots = <String>{};
    for (final c in manifest.commands) {
      if (!wanted(c)) continue;
      final groupId = c.group;
      if (groupId == null || manifest.group(groupId) == null) {
        entries.add(_leaf(c));
        continue;
      }
      final root = rootOf(groupId);
      if (usedGroups.contains(root) || !seenRoots.add(root)) continue;
      final section = _section(manifest, manifest.group(root)!, wanted, tag);
      if (section != null) entries.add(section);
    }
    return entries;
  }

  final info = others((c) => c.kind == CommandKind.info, 'info');
  final sections = info.isEmpty
      ? [SidebarSection(label: 'COMMANDS', entries: others((_) => true, 'all'))]
      : [
          SidebarSection(label: 'INFO', entries: info),
          SidebarSection(
            label: 'ACTIONS',
            entries: others((c) => c.kind == CommandKind.action, 'action'),
          ),
        ];
  return SidebarModel(
    primary: primary,
    sections: [
      for (final s in sections)
        if (s.entries.isNotEmpty) s,
    ],
  );
}

SidebarEntry _leaf(CommandSpec c) => SidebarEntry(
  id: 'cmd:${c.id}',
  label: c.title,
  icon: c.icon,
  selectKey: 'cmd:${c.id}',
);

/// Commands directly in [groupId] followed by its subgroups.
List<SidebarEntry> _childrenOf(
  GuiManifestModel manifest,
  String groupId,
  bool Function(CommandSpec) wanted,
  String tag,
) => [
  for (final c in manifest.commands)
    if (c.group == groupId && wanted(c)) _leaf(c),
  for (final g in manifest.groups)
    if (g.parent == groupId) ?_section(manifest, g, wanted, tag),
];

SidebarEntry? _section(
  GuiManifestModel manifest,
  GroupSpec group,
  bool Function(CommandSpec) wanted,
  String tag,
) {
  final children = _childrenOf(manifest, group.id, wanted, tag);
  if (children.isEmpty) return null;
  return SidebarEntry(
    id: tag.isEmpty ? 'group:${group.id}' : 'group:${group.id}:$tag',
    label: group.label,
    icon: group.icon,
    children: children,
  );
}

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

/// The sidebar as data: [primary] rows are the CLI's main actions, [more]
/// holds every other command, grouped.
final class SidebarModel {
  const SidebarModel({required this.primary, required this.more});

  final List<SidebarEntry> primary;
  final List<SidebarEntry> more;

  /// All page keys in display order.
  Iterable<String> get keys sync* {
    for (final entry in [...primary, ...more]) {
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

    for (final entry in [...primary, ...more]) {
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
/// group's commands sit under it. Other groups become sections under
/// [SidebarModel.more], followed by commands that belong to no group.
/// Commands marked hidden never appear, and a command that is already a main
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

  SidebarEntry leaf(CommandSpec c) =>
      SidebarEntry(id: 'cmd:${c.id}', label: c.title, selectKey: 'cmd:${c.id}');

  final usedGroups = <String>{};
  final primary = <SidebarEntry>[];
  for (final n in nav) {
    final command = n.command == null ? null : manifest.command(n.command!);
    final groupId = command?.group;
    final group = groupId == null ? null : manifest.group(groupId);
    if (group != null && group.id == n.id) {
      usedGroups.add(group.id);
      primary.add(
        SidebarEntry(
          id: 'nav:${n.id}',
          label: n.label,
          icon: n.icon,
          selectKey: 'nav:${n.id}',
          children: _childrenOf(manifest, group.id, listed, leaf),
        ),
      );
    } else {
      primary.add(
        SidebarEntry(
          id: 'nav:${n.id}',
          label: n.label,
          icon: n.icon,
          selectKey: 'nav:${n.id}',
        ),
      );
    }
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

  final more = <SidebarEntry>[];
  final seenRoots = <String>{};
  for (final c in manifest.commands) {
    final groupId = c.group;
    if (groupId == null || manifest.group(groupId) == null) {
      if (listed(c)) more.add(leaf(c));
      continue;
    }
    final root = rootOf(groupId);
    if (usedGroups.contains(root) || !seenRoots.add(root)) continue;
    final section = _section(manifest, manifest.group(root)!, listed, leaf);
    if (section != null) more.add(section);
  }
  return SidebarModel(primary: primary, more: more);
}

/// Commands directly in [groupId] followed by its subgroups.
List<SidebarEntry> _childrenOf(
  GuiManifestModel manifest,
  String groupId,
  bool Function(CommandSpec) listed,
  SidebarEntry Function(CommandSpec) leaf,
) => [
  for (final c in manifest.commands)
    if (c.group == groupId && listed(c)) leaf(c),
  for (final g in manifest.groups)
    if (g.parent == groupId) ?_section(manifest, g, listed, leaf),
];

SidebarEntry? _section(
  GuiManifestModel manifest,
  GroupSpec group,
  bool Function(CommandSpec) listed,
  SidebarEntry Function(CommandSpec) leaf,
) {
  final children = _childrenOf(manifest, group.id, listed, leaf);
  if (children.isEmpty) return null;
  return SidebarEntry(
    id: 'group:${group.id}',
    label: group.label,
    icon: group.icon,
    children: children,
  );
}

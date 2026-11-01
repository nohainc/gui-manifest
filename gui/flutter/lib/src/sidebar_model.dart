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

/// The sidebar as data: navigation and unsectioned commands appear first;
/// [sections] are supplied by command metadata.
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
/// Navigation groups retain their children; remaining commands are grouped
/// by their optional section label, or placed at the top when it is absent.
SidebarModel buildSidebar(
  GuiManifestModel manifest, {
  bool Function(NavEntry entry)? navVisible,
}) {
  final nav = [
    for (final n in manifest.navigation)
      if ((navVisible?.call(n) ?? true) &&
          (n.command == null || manifest.command(n.command!)?.hidden == false))
        n,
  ];
  final navTargets = {
    for (final n in nav)
      if (n.command != null) n.command!,
  };
  bool listed(CommandSpec c) => !c.hidden && !navTargets.contains(c.id);

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

  final usedGroups = <String>{};
  final primary = <SidebarEntry>[];
  final sectionNav = <String, List<SidebarEntry>>{};
  for (final n in nav) {
    final command = n.command == null ? null : manifest.command(n.command!);
    final groupId = command?.group;
    final group = groupId == null ? null : manifest.group(groupId);
    final isGroupEntry = group != null && group.id == n.id;
    if (isGroupEntry) usedGroups.add(group.id);
    final entry = SidebarEntry(
      id: 'nav:${n.id}',
      label: n.label,
      icon: n.icon,
      selectKey: 'nav:${n.id}',
      children: isGroupEntry
          ? _childrenOf(manifest, group.id, (c) => listed(c), '')
          : const [],
    );
    final section = isGroupEntry
        ? manifest.group(rootOf(group.id))?.section
        : null;
    if (section == null) {
      primary.add(entry);
    } else {
      (sectionNav[section] ??= []).add(entry);
    }
  }

  // A root group owns placement for every descendant, even when an
  // individual command or nested group declares a different section.
  String? sectionOf(CommandSpec command) {
    final groupId = command.group;
    if (groupId == null || manifest.group(groupId) == null) {
      return command.section;
    }
    return manifest.group(rootOf(groupId))?.section;
  }

  List<SidebarEntry> entriesFor(String? section) {
    final entries = <SidebarEntry>[];
    final seenRoots = <String>{};
    for (final c in manifest.commands) {
      if (!listed(c) || sectionOf(c) != section) continue;
      final groupId = c.group;
      if (groupId == null || manifest.group(groupId) == null) {
        entries.add(_leaf(c));
        continue;
      }
      final root = rootOf(groupId);
      if (usedGroups.contains(root) || !seenRoots.add(root)) continue;
      final group = _section(manifest, manifest.group(root)!, listed, '');
      if (group != null) entries.add(group);
    }
    return entries;
  }

  primary.addAll(entriesFor(null));
  final labels = <String>{...sectionNav.keys};
  for (final c in manifest.commands) {
    if (!listed(c)) continue;
    if (c.group != null && usedGroups.contains(rootOf(c.group!))) continue;
    final section = sectionOf(c);
    if (section != null) labels.add(section);
  }
  return SidebarModel(
    primary: primary,
    sections: [
      for (final label in labels)
        if ((sectionNav[label]?.isNotEmpty ?? false) ||
            entriesFor(label).isNotEmpty)
          SidebarSection(
            label: label,
            entries: [...?sectionNav[label], ...entriesFor(label)],
          ),
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

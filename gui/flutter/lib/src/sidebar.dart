import 'package:flutter/material.dart';

import 'icons.dart';
import 'sidebar_model.dart';
import 'sidebar_theme.dart';

/// Page key of the Settings page, opened from the sidebar footer.
const settingsPageKey = 'settings';

/// The sidebar, styled like the Syntila app's Space tree.
///
/// - A group of commands is a **Space**: its icon and 12.5px name, with a
///   chevron showing whether its commands are listed.
/// - The commands inside a group are its **Threads**: 11.5px, indented under
///   the name without a command icon.
/// - Commands that belong to no group are Spaces without Threads.
/// - Other commands are grouped by their optional manifest section label.
///
/// Top-level rows show their manifest icon or a generic command icon.
///
/// A row is highlighted while selected or hovered. Tapping a group opens its
/// main page and shows its commands; tapping it again hides them.
class GuiSidebar extends StatelessWidget {
  const GuiSidebar({
    super.key,
    required this.header,
    required this.version,
    required this.model,
    required this.selected,
    required this.expanded,
    required this.onSelect,
    required this.onToggle,
    required this.onReload,
    required this.onOpenSettings,
  });

  final Widget header;
  final String version;
  final SidebarModel model;
  final String? selected;
  final Set<String> expanded;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onToggle;
  final VoidCallback onReload;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = GuiSidebarTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        border: Border(right: BorderSide(color: theme.borderColor)),
      ),
      child: SizedBox(
        width: GuiSidebarMetrics.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: header,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                children: [
                  for (final entry in model.primary) _row(context, entry, 0),
                  for (final section in model.sections) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 14, 8, 6),
                      child: Text(
                        section.label,
                        style: TextStyle(
                          fontSize: GuiSidebarMetrics.labelFontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: theme.labelColor,
                        ),
                      ),
                    ),
                    for (final entry in section.entries)
                      _row(context, entry, 0),
                  ],
                ],
              ),
            ),
            _footer(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context, GuiSidebarTheme theme) {
    final settingsOpen = selected == settingsPageKey;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.borderColor)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'v$version',
              style: TextStyle(
                fontSize: GuiSidebarMetrics.threadFontSize,
                color: theme.textColor,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Reload commands',
            icon: Icon(Icons.refresh, size: 18, color: theme.textColor),
            onPressed: onReload,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: settingsOpen ? theme.selectedColor : Colors.transparent,
              borderRadius: BorderRadius.circular(
                GuiSidebarMetrics.spaceRadius,
              ),
            ),
            child: IconButton(
              key: const ValueKey('sidebar-settings'),
              tooltip: 'Settings',
              icon: Icon(
                Icons.settings_outlined,
                size: 18,
                color: theme.textColor,
              ),
              onPressed: onOpenSettings,
            ),
          ),
        ],
      ),
    );
  }

  /// One row plus, when expanded, its children one level deeper.
  Widget _row(BuildContext context, SidebarEntry entry, int depth) {
    final open = expanded.contains(entry.id);
    final row = _HoverRow(
      builder: (context, hovered) =>
          _rowBody(context, entry, depth, open, hovered),
    );
    if (!entry.isExpandable || !open) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        for (final child in entry.children) _row(context, child, depth + 1),
      ],
    );
  }

  Widget _rowBody(
    BuildContext context,
    SidebarEntry entry,
    int depth,
    bool open,
    bool hovered,
  ) {
    final theme = GuiSidebarTheme.of(context);
    final isSpace = depth == 0;
    final isSelected = entry.selectKey != null && entry.selectKey == selected;
    final active = isSelected || hovered;
    final radius = BorderRadius.circular(
      isSpace ? GuiSidebarMetrics.spaceRadius : GuiSidebarMetrics.threadRadius,
    );
    final textStyle = TextStyle(
      color: theme.textColor,
      fontSize: isSpace
          ? GuiSidebarMetrics.spaceFontSize
          : GuiSidebarMetrics.threadFontSize,
      fontWeight: FontWeight.w400,
    );
    return Container(
      key: ValueKey('sidebar-row-${entry.id}'),
      height: GuiSidebarMetrics.rowHeight,
      decoration: BoxDecoration(
        color: active ? theme.selectedColor : Colors.transparent,
        borderRadius: radius,
      ),
      child: InkWell(
        hoverColor: Colors.transparent,
        borderRadius: radius,
        onTap: () => _tap(entry, open, isSelected),
        child: Padding(
          padding: EdgeInsets.only(
            left:
                GuiSidebarMetrics.rowPadding +
                (depth > 1 ? (depth - 1) * GuiSidebarMetrics.nestedIndent : 0),
            right: 8,
          ),
          child: Row(
            children: [
              if (isSpace) ...[
                Icon(
                  iconFor(entry.icon),
                  size: GuiSidebarMetrics.iconSize,
                  color: theme.textColor,
                ),
                const SizedBox(width: GuiSidebarMetrics.iconGap),
              ] else
                const SizedBox(width: GuiSidebarMetrics.threadLeading),
              Expanded(
                child: Text(
                  entry.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
              if (entry.isExpandable)
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: theme.labelColor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _tap(SidebarEntry entry, bool open, bool isSelected) {
    final key = entry.selectKey;
    if (key == null) {
      onToggle(entry.id);
      return;
    }
    // Like a Space in the Syntila app: opening a closed group shows its
    // commands, tapping the open group again hides them.
    if (entry.isExpandable && (!open || isSelected)) onToggle(entry.id);
    onSelect(key);
  }
}

/// Tracks pointer hover for a row.
class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.builder});

  final Widget Function(BuildContext context, bool hovered) builder;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: widget.builder(context, _hovered),
  );
}

import 'package:flutter/material.dart';

/// Sidebar colors. The host app supplies its own through
/// `ThemeData.extensions`; without one they come from the [ColorScheme].
///
/// ```dart
/// theme.copyWith(extensions: [
///   GuiSidebarTheme(
///     backgroundColor: ..., selectedColor: ..., textColor: ...,
///     labelColor: ..., borderColor: ...,
///   ),
/// ])
/// ```
@immutable
class GuiSidebarTheme extends ThemeExtension<GuiSidebarTheme> {
  const GuiSidebarTheme({
    required this.backgroundColor,
    required this.selectedColor,
    required this.textColor,
    required this.labelColor,
    required this.borderColor,
  });

  factory GuiSidebarTheme.fromColorScheme(ColorScheme scheme) =>
      GuiSidebarTheme(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.secondaryContainer,
        textColor: scheme.onSurfaceVariant,
        labelColor: scheme.outline,
        borderColor: scheme.outlineVariant,
      );

  /// The theme in effect at [context].
  static GuiSidebarTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<GuiSidebarTheme>() ??
        GuiSidebarTheme.fromColorScheme(theme.colorScheme);
  }

  /// Sidebar panel.
  final Color backgroundColor;

  /// Selected or hovered row.
  final Color selectedColor;

  /// Row text and icons.
  final Color textColor;

  /// Small uppercase section labels.
  final Color labelColor;

  /// Line between the sidebar and the content.
  final Color borderColor;

  @override
  GuiSidebarTheme copyWith({
    Color? backgroundColor,
    Color? selectedColor,
    Color? textColor,
    Color? labelColor,
    Color? borderColor,
  }) => GuiSidebarTheme(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    selectedColor: selectedColor ?? this.selectedColor,
    textColor: textColor ?? this.textColor,
    labelColor: labelColor ?? this.labelColor,
    borderColor: borderColor ?? this.borderColor,
  );

  @override
  GuiSidebarTheme lerp(GuiSidebarTheme? other, double t) {
    if (other == null) return this;
    return GuiSidebarTheme(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t)!,
      selectedColor: Color.lerp(selectedColor, other.selectedColor, t)!,
      textColor: Color.lerp(textColor, other.textColor, t)!,
      labelColor: Color.lerp(labelColor, other.labelColor, t)!,
      borderColor: Color.lerp(borderColor, other.borderColor, t)!,
    );
  }
}

/// Sidebar sizes, matching the Syntila app: Spaces (groups and commands) and
/// Threads (a group's sub-commands) keep the same height, type size and
/// rounding.
abstract final class GuiSidebarMetrics {
  static const double width = 260;
  static const double rowHeight = 30;
  static const double spaceFontSize = 12.5;
  static const double threadFontSize = 11.5;
  static const double spaceRadius = 8;
  static const double threadRadius = 6;
  static const double folderIconSize = 16;

  /// Space row: left padding, gap between folder icon and name.
  static const double rowPadding = 8;
  static const double iconGap = 8;

  /// Width of a Thread row's leading slot (Syntila shows activity dots there).
  static const double threadLeading = 26;

  /// Extra indent for each level below a Thread row.
  static const double nestedIndent = 14;

  static const double labelFontSize = 9;
}

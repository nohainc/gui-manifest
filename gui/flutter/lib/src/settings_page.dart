import 'package:flutter/material.dart';

import 'view_preferences.dart';

/// Device-local view settings. Changes apply immediately.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.preferences,
    required this.onChanged,
  });

  final GuiViewPreferences preferences;
  final ValueChanged<GuiViewPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'These preferences apply to this device.',
            style: TextStyle(fontSize: 12.5, color: muted),
          ),
          const SizedBox(height: 24),
          Text(
            'APPEARANCE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: scheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Text size', style: TextStyle(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      'Makes text larger across the app.',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SegmentedButton<TextSizeOption>(
                key: const ValueKey('setting-text-size'),
                showSelectedIcon: false,
                segments: [
                  for (final option in TextSizeOption.values)
                    ButtonSegment(value: option, label: Text(option.label)),
                ],
                selected: {preferences.textSize},
                onSelectionChanged: (selection) =>
                    onChanged(preferences.copyWith(textSize: selection.first)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

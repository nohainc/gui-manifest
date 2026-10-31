import 'package:flutter/material.dart';

/// Manifest icon names → Material icons. Unknown names use [fallbackIcon].
const Map<String, IconData> manifestIcons = {
  'pulse': Icons.monitor_heart_outlined,
  'cpu': Icons.memory,
  'folder': Icons.folder_outlined,
  'tasks': Icons.checklist,
  'log': Icons.receipt_long_outlined,
  'server': Icons.dns_outlined,
  'settings': Icons.settings_outlined,
  'user': Icons.person_outline,
  'key': Icons.key_outlined,
  'cloud': Icons.cloud_outlined,
  'play': Icons.play_arrow_outlined,
  'stop': Icons.stop_outlined,
  'trash': Icons.delete_outline,
  'info': Icons.info_outline,
};

const IconData fallbackIcon = Icons.terminal;

IconData iconFor(String? name) => manifestIcons[name] ?? fallbackIcon;

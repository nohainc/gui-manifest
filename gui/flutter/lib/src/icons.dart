import 'package:flutter/material.dart';
import 'package:gui_manifest/gui_manifest.dart' show GuiIcons;

/// Shown for a command without an icon, or with a name this GUI does not know.
/// It is a terminal prompt: a command, not a folder.
const IconData defaultCommandIcon = Icons.terminal;

/// The glyph for each name in the manifest icon vocabulary ([GuiIcons]).
const Map<String, IconData> manifestIcons = {
  GuiIcons.command: defaultCommandIcon,
  GuiIcons.pulse: Icons.monitor_heart_outlined,
  GuiIcons.cpu: Icons.memory,
  GuiIcons.folder: Icons.folder_outlined,
  GuiIcons.tasks: Icons.checklist,
  GuiIcons.log: Icons.receipt_long_outlined,
  GuiIcons.server: Icons.dns_outlined,
  GuiIcons.settings: Icons.settings_outlined,
  GuiIcons.sliders: Icons.tune,
  GuiIcons.user: Icons.person_outline,
  GuiIcons.key: Icons.key_outlined,
  GuiIcons.lock: Icons.lock_outline,
  GuiIcons.shield: Icons.shield_outlined,
  GuiIcons.cloud: Icons.cloud_outlined,
  GuiIcons.cloudOff: Icons.cloud_off_outlined,
  GuiIcons.link: Icons.link,
  GuiIcons.unlink: Icons.link_off,
  GuiIcons.play: Icons.play_arrow_outlined,
  GuiIcons.stop: Icons.stop_outlined,
  GuiIcons.pause: Icons.pause_circle_outline,
  GuiIcons.refresh: Icons.refresh,
  GuiIcons.power: Icons.power_settings_new,
  GuiIcons.trash: Icons.delete_outline,
  GuiIcons.info: Icons.info_outline,
  GuiIcons.plus: Icons.add_circle_outline,
  GuiIcons.edit: Icons.edit_outlined,
  GuiIcons.check: Icons.check_circle_outline,
  GuiIcons.bug: Icons.bug_report_outlined,
  GuiIcons.test: Icons.science_outlined,
  GuiIcons.list: Icons.list_alt_outlined,
  GuiIcons.table: Icons.table_chart_outlined,
  GuiIcons.chart: Icons.bar_chart,
  GuiIcons.gauge: Icons.speed,
  GuiIcons.download: Icons.download_outlined,
  GuiIcons.upload: Icons.upload_outlined,
  GuiIcons.wrench: Icons.build_outlined,
  GuiIcons.file: Icons.description_outlined,
  GuiIcons.code: Icons.code,
  GuiIcons.book: Icons.menu_book_outlined,
  GuiIcons.search: Icons.search,
  GuiIcons.home: Icons.home_outlined,
  GuiIcons.login: Icons.login,
  GuiIcons.logout: Icons.logout,
  GuiIcons.id: Icons.badge_outlined,
  GuiIcons.tag: Icons.sell_outlined,
  GuiIcons.database: Icons.storage_outlined,
  GuiIcons.package: Icons.inventory_2_outlined,
  GuiIcons.clock: Icons.schedule,
  GuiIcons.bell: Icons.notifications_none,
  GuiIcons.mail: Icons.mail_outline,
  GuiIcons.globe: Icons.public,
  GuiIcons.eye: Icons.visibility_outlined,
  GuiIcons.copy: Icons.content_copy,
  GuiIcons.rocket: Icons.rocket_launch_outlined,
};

/// The glyph for [name], or [defaultCommandIcon] when it is null or unknown.
IconData iconFor(String? name) => manifestIcons[name] ?? defaultCommandIcon;

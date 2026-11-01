import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'output_format.dart';

/// Text sizes offered in Settings, as in the Syntila app.
enum TextSizeOption {
  standard('Default', 1.0),
  large('Large', 1.15),
  extraLarge('Extra large', 1.3);

  const TextSizeOption(this.label, this.scale);

  final String label;

  /// Multiplier applied on top of the system text scale.
  final double scale;

  static TextSizeOption fromName(Object? name) => values.firstWhere(
    (option) => option.name == name,
    orElse: () => standard,
  );
}

/// View choices that apply to this device only.
@immutable
class GuiViewPreferences {
  const GuiViewPreferences({
    this.textSize = TextSizeOption.standard,
    this.outputFormat = OutputFormatOption.nano,
  });

  final TextSizeOption textSize;

  /// How structured command results are written as text. Nano by default.
  final OutputFormatOption outputFormat;

  GuiViewPreferences copyWith({
    TextSizeOption? textSize,
    OutputFormatOption? outputFormat,
  }) => GuiViewPreferences(
    textSize: textSize ?? this.textSize,
    outputFormat: outputFormat ?? this.outputFormat,
  );

  String encode() => jsonEncode({
    'textSize': textSize.name,
    'outputFormat': outputFormat.name,
  });

  /// Unknown or damaged input gives the defaults.
  static GuiViewPreferences decode(String? raw) {
    if (raw == null) return const GuiViewPreferences();
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return const GuiViewPreferences();
      return GuiViewPreferences(
        textSize: TextSizeOption.fromName(json['textSize']),
        outputFormat: OutputFormatOption.fromName(json['outputFormat']),
      );
    } on FormatException {
      return const GuiViewPreferences();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is GuiViewPreferences &&
      other.textSize == textSize &&
      other.outputFormat == outputFormat;

  @override
  int get hashCode => Object.hash(textSize, outputFormat);
}

/// Device-local storage for [GuiViewPreferences].
class ViewPreferencesStore {
  ViewPreferencesStore({required this.read, required this.write});

  /// Keeps the choice for this session only.
  factory ViewPreferencesStore.memory([String? initial]) {
    var value = initial;
    return ViewPreferencesStore(read: () => value, write: (v) => value = v);
  }

  /// Keeps the choice in [file], created on first save.
  factory ViewPreferencesStore.file(File file) => ViewPreferencesStore(
    read: () => file.existsSync() ? file.readAsStringSync() : null,
    write: (value) {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(value);
    },
  );

  /// Keeps the choice in the platform's per-user settings folder for [appId]
  /// (`~/Library/Application Support`, `$XDG_CONFIG_HOME` or `~/.config`,
  /// `%APPDATA%`), falling back to memory when there is none.
  factory ViewPreferencesStore.forApp(
    String appId, {
    Map<String, String>? environment,
    bool? isMacOS,
    bool? isWindows,
  }) {
    final env = environment ?? Platform.environment;
    final home = env['HOME'];
    final Directory? base;
    if (isWindows ?? Platform.isWindows) {
      final appData = env['APPDATA'];
      base = appData == null ? null : Directory(appData);
    } else if (isMacOS ?? Platform.isMacOS) {
      base = home == null
          ? null
          : Directory('$home/Library/Application Support');
    } else {
      final xdg = env['XDG_CONFIG_HOME'];
      base = xdg != null && xdg.isNotEmpty
          ? Directory(xdg)
          : home == null
          ? null
          : Directory('$home/.config');
    }
    if (base == null) return ViewPreferencesStore.memory();
    return ViewPreferencesStore.file(
      File('${base.path}/$appId/view-preferences.json'),
    );
  }

  final String? Function() read;
  final void Function(String value) write;

  GuiViewPreferences load() {
    try {
      return GuiViewPreferences.decode(read());
    } on Object {
      return const GuiViewPreferences();
    }
  }

  void save(GuiViewPreferences preferences) {
    try {
      write(preferences.encode());
    } on Object {
      // Storage can be unavailable; this session still keeps the choice.
    }
  }
}

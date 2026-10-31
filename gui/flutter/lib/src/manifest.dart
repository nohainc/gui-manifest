import 'package:gui_manifest/gui_manifest.dart' show validateManifest;

/// Thrown when a CLI's manifest violates the spec.
final class ManifestException implements Exception {
  const ManifestException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class CliInfo {
  const CliInfo({
    required this.name,
    required this.version,
    this.displayName,
    this.description,
  });

  final String name;
  final String version;
  final String? displayName;
  final String? description;
}

final class NavEntry {
  const NavEntry({
    required this.id,
    required this.label,
    this.icon,
    this.group,
    this.command,
    this.screen,
    this.builtin,
  });

  final String id;
  final String label;
  final String? icon;
  final String? group;
  final String? command;
  final String? screen;
  final String? builtin;
}

final class CommandParameter {
  const CommandParameter({
    required this.name,
    required this.kind,
    required this.type,
    this.required = false,
    this.defaultValue,
    this.values = const [],
    this.multiple = false,
    this.label,
    this.help,
  });

  final String name;

  /// `option`, `flag` or `positional`.
  final String kind;

  /// `string`, `integer`, `number`, `boolean`, `enum`, `path` or `secret`.
  final String type;
  final bool required;
  final String? defaultValue;
  final List<String> values;
  final bool multiple;
  final String? label;
  final String? help;

  bool get isSecret => type == 'secret';
  String get displayLabel => label ?? name;
}

final class CommandSpec {
  const CommandSpec({
    required this.id,
    required this.argv,
    required this.title,
    this.description,
    this.parameters = const [],
    this.format = 'text',
    this.view = 'raw',
    this.destructive = false,
    this.interactive = false,
    this.longRunning = false,
    this.requires = const [],
    this.hidden = false,
  });

  final String id;
  final List<String> argv;
  final String title;
  final String? description;
  final List<CommandParameter> parameters;
  final String format;
  final String view;
  final bool destructive;
  final bool interactive;
  final bool longRunning;
  final List<String> requires;
  final bool hidden;

  /// Builds the argument list for [values] (parameter name → entered text).
  ///
  /// Empty values are omitted; flags are added when `"true"`. Throws
  /// [ArgumentError] when a required parameter is missing.
  List<String> buildArgs(Map<String, String> values) {
    final options = <String>[];
    final positionals = <String>[];
    for (final p in parameters) {
      final value = values[p.name]?.trim() ?? '';
      if (p.kind == 'flag') {
        if (value == 'true') options.add('--${p.name}');
        continue;
      }
      if (value.isEmpty) {
        if (p.required) {
          throw ArgumentError('${p.displayLabel} is required');
        }
        continue;
      }
      if (p.kind == 'positional') {
        positionals.add(value);
      } else {
        options.addAll(['--${p.name}', value]);
      }
    }
    return [...argv, ...options, ...positionals];
  }
}

final class GuiManifestModel {
  const GuiManifestModel({
    required this.manifestVersion,
    required this.cli,
    required this.navigation,
    required this.commands,
  });

  /// Validates [tree] (a decoded Nano Markup document) and builds the model.
  factory GuiManifestModel.fromTree(Object tree) {
    final issues = validateManifest(tree);
    if (issues.isNotEmpty) {
      throw ManifestException(
        'Invalid GUI manifest:\n${issues.map((i) => '  $i').join('\n')}',
      );
    }
    final doc = tree as Map<String, Object>;
    final cli = doc['cli'] as Map<String, Object>;
    return GuiManifestModel(
      manifestVersion: int.parse(doc['manifestVersion'] as String),
      cli: CliInfo(
        name: cli['name'] as String,
        version: cli['version'] as String,
        displayName: cli['displayName'] as String?,
        description: cli['description'] as String?,
      ),
      navigation: [
        for (final n in (doc['navigation'] as List).cast<Map<String, Object>>())
          NavEntry(
            id: n['id'] as String,
            label: n['label'] as String,
            icon: n['icon'] as String?,
            group: n['group'] as String?,
            command: n['command'] as String?,
            screen: n['screen'] as String?,
            builtin: n['builtin'] as String?,
          ),
      ],
      commands: [
        for (final c in (doc['commands'] as List).cast<Map<String, Object>>())
          _command(c),
      ],
    );
  }

  final int manifestVersion;
  final CliInfo cli;
  final List<NavEntry> navigation;
  final List<CommandSpec> commands;

  CommandSpec? command(String id) {
    for (final c in commands) {
      if (c.id == id) return c;
    }
    return null;
  }
}

bool _flag(Map<String, Object> m, String key) => m[key] == 'true';

List<String> _strings(Map<String, Object> m, String key) =>
    (m[key] as List? ?? const []).cast<String>();

CommandSpec _command(Map<String, Object> c) {
  final output = c['output'] as Map<String, Object>? ?? const {};
  return CommandSpec(
    id: c['id'] as String,
    argv: _strings(c, 'argv'),
    title: c['title'] as String,
    description: c['description'] as String?,
    parameters: [
      for (final p
          in (c['parameters'] as List? ?? const []).cast<Map<String, Object>>())
        CommandParameter(
          name: p['name'] as String,
          kind: p['kind'] as String,
          type: p['type'] as String,
          required: _flag(p, 'required'),
          defaultValue: p['default'] as String?,
          values: _strings(p, 'values'),
          multiple: _flag(p, 'multiple'),
          label: p['label'] as String?,
          help: p['help'] as String?,
        ),
    ],
    format: output['format'] as String? ?? 'text',
    view: output['view'] as String? ?? 'raw',
    destructive: _flag(c, 'destructive'),
    interactive: _flag(c, 'interactive'),
    longRunning: _flag(c, 'longRunning'),
    requires: _strings(c, 'requires'),
    hidden: _flag(c, 'hidden'),
  );
}

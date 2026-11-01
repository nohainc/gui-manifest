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

/// A named set of related commands (e.g. `workers`).
final class GroupSpec {
  const GroupSpec({
    required this.id,
    required this.label,
    this.icon,
    this.description,
    this.parent,
    this.section,
  });

  final String id;
  final String label;
  final String? icon;
  final String? description;

  /// Id of the enclosing group, if any.
  final String? parent;

  /// Sidebar section for the entire root group.
  final String? section;
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
    this.stdinFlag,
  });

  final String name;

  /// `option`, `flag`, `positional` or `stdin`.
  final String kind;

  /// `string`, `integer`, `number`, `boolean`, `enum`, `path` or `secret`.
  final String type;
  final bool required;
  final String? defaultValue;
  final List<String> values;
  final bool multiple;
  final String? label;
  final String? help;

  final String? stdinFlag;

  bool get isSecret => type == 'secret';
  String get displayLabel => label ?? name;
}

/// What a command does: [info] only reads and reports, [action] does
/// something (and is the default for manifests that do not say).
enum CommandKind { info, action }

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
    this.group,
    this.icon,
    this.kind = CommandKind.action,
    this.section,
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

  /// Id of the [GroupSpec] this command belongs to.
  final String? group;

  /// Icon name from the manifest vocabulary; null or unknown shows the default.
  final String? icon;

  final CommandKind kind;

  /// Optional sidebar section label.
  final String? section;

  /// The command line as the user will read it, e.g. `syntila workers remove
  /// w1`. [program] is the CLI's name (never its install path). A missing
  /// required value shows as `<name>`, secrets as `••••`, and values with
  /// spaces are quoted.
  String preview(Map<String, String> values, {required String program}) {
    String quote(String v) => RegExp(r'^[\w@%+=:,./-]+$').hasMatch(v)
        ? v
        : "'${v.replaceAll("'", r"'\''")}'";
    final options = <String>[];
    final positionals = <String>[];
    for (final p in parameters) {
      final raw = values[p.name]?.trim() ?? '';
      if (p.stdinFlag != null) {
        if (raw.isNotEmpty) options.add('--${p.stdinFlag}');
        continue;
      }
      if (p.kind == 'flag') {
        if (raw == 'true') options.add('--${p.name}');
        continue;
      }
      final String? shown = raw.isNotEmpty
          ? (p.isSecret ? '••••' : quote(raw))
          : p.required
          ? '<${p.name}>'
          : null;
      if (shown == null) continue;
      if (p.kind == 'positional') {
        positionals.add(shown);
      } else {
        options.addAll(['--${p.name}', shown]);
      }
    }
    return [program, ...argv, ...options, ...positionals].join(' ');
  }

  /// Builds the argument list for [values] (parameter name → entered text).
  ///
  /// Empty values are omitted; flags are added when `"true"`. Throws
  /// [ArgumentError] when a required parameter is missing.
  List<String> buildArgs(Map<String, String> values) {
    final options = <String>[];
    final positionals = <String>[];
    for (final p in parameters) {
      final value = values[p.name]?.trim() ?? '';
      if (p.stdinFlag != null) {
        if (value.isEmpty && p.required) {
          throw ArgumentError('${p.displayLabel} is required');
        }
        if (value.contains('\n') || value.contains('\r')) {
          throw ArgumentError('${p.displayLabel} must be a single line');
        }
        if (value.isNotEmpty) options.add('--${p.stdinFlag}');
        continue;
      }
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
    this.groups = const [],
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
      groups: [
        for (final g
            in (doc['groups'] as List? ?? const []).cast<Map<String, Object>>())
          GroupSpec(
            id: g['id'] as String,
            label: g['label'] as String,
            icon: g['icon'] as String?,
            description: g['description'] as String?,
            parent: g['parent'] as String?,
            section: g['section'] as String?,
          ),
      ],
    );
  }

  final int manifestVersion;
  final CliInfo cli;
  final List<NavEntry> navigation;
  final List<CommandSpec> commands;
  final List<GroupSpec> groups;

  GroupSpec? group(String id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

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
          stdinFlag: p['stdinFlag'] as String?,
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
    group: c['group'] as String?,
    icon: c['icon'] as String?,
    kind: c['kind'] == 'info' ? CommandKind.info : CommandKind.action,
    section: c['section'] as String?,
  );
}

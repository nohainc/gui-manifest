/// Manifest versions this SDK can produce.
const List<int> supportedManifestVersions = <int>[1];

/// Fixed set of result views (SPEC §7).
enum GuiView { form, table, keyValue, card, log, confirm, raw }

/// Result formats a command can produce (SPEC §5.2).
enum GuiFormat { text, json, jsonLines, nano }

/// Parameter value types (SPEC §5.1).
enum GuiParamType {
  string,
  integer,
  number,
  boolean,
  enumeration,
  path,
  secret,
}

/// Parameter kinds (SPEC §5.1).
enum GuiParamKind { option, flag, positional }

String _bool(bool value) => value ? 'true' : 'false';

final class GuiCliInfo {
  const GuiCliInfo({
    required this.name,
    required this.version,
    this.displayName,
    this.description,
  });

  final String name;
  final String version;
  final String? displayName;
  final String? description;

  Map<String, Object> toTree() => <String, Object>{
        'name': name,
        'version': version,
        if (displayName != null) 'displayName': displayName!,
        if (description != null) 'description': description!,
      };
}

/// A named set of commands, e.g. `workers` containing `workers.list`.
final class GuiGroup {
  const GuiGroup({
    required this.id,
    required this.label,
    this.icon,
    this.description,
    this.parent,
  });

  final String id;
  final String label;
  final String? icon;
  final String? description;

  /// Id of the enclosing group, if any.
  final String? parent;

  Map<String, Object> toTree() => <String, Object>{
        'id': id,
        'label': label,
        if (icon != null) 'icon': icon!,
        if (description != null) 'description': description!,
        if (parent != null) 'parent': parent!,
      };
}

final class GuiOutput {
  const GuiOutput({this.format = GuiFormat.text, this.view = GuiView.raw});

  final GuiFormat format;
  final GuiView view;

  Map<String, Object> toTree() => <String, Object>{
        'format': format.name,
        'view': view.name,
      };
}

final class GuiParameter {
  const GuiParameter({
    required this.name,
    required this.kind,
    required this.type,
    this.required = false,
    this.defaultValue,
    this.values = const <String>[],
    this.multiple = false,
    this.label,
    this.help,
    this.hidden = false,
  });

  final String name;
  final GuiParamKind kind;
  final GuiParamType type;
  final bool required;
  final String? defaultValue;
  final List<String> values;
  final bool multiple;
  final String? label;
  final String? help;

  /// Accepted on the command line (for compatibility) but left out of help
  /// and of the GUI manifest.
  final bool hidden;

  Map<String, Object> toTree() => <String, Object>{
        'name': name,
        'kind': kind.name,
        'type': type == GuiParamType.enumeration ? 'enum' : type.name,
        if (required) 'required': _bool(true),
        if (defaultValue != null) 'default': defaultValue!,
        if (values.isNotEmpty) 'values': List<Object>.of(values),
        if (multiple) 'multiple': _bool(true),
        if (label != null) 'label': label!,
        if (help != null) 'help': help!,
      };
}

final class GuiCommand {
  const GuiCommand({
    required this.id,
    required this.argv,
    required this.title,
    this.description,
    this.parameters = const <GuiParameter>[],
    this.output = const GuiOutput(),
    this.destructive = false,
    this.interactive = false,
    this.longRunning = false,
    this.requires = const <String>[],
    this.hidden = false,
    this.group,
  });

  final String id;
  final List<String> argv;
  final String title;
  final String? description;
  final List<GuiParameter> parameters;
  final GuiOutput output;
  final bool destructive;
  final bool interactive;
  final bool longRunning;
  final List<String> requires;
  final bool hidden;

  /// Id of the [GuiGroup] this command belongs to.
  final String? group;

  Map<String, Object> toTree() => <String, Object>{
        'id': id,
        'argv': List<Object>.of(argv),
        'title': title,
        if (description != null) 'description': description!,
        if (group != null) 'group': group!,
        if (destructive) 'destructive': _bool(true),
        if (interactive) 'interactive': _bool(true),
        if (longRunning) 'longRunning': _bool(true),
        if (hidden) 'hidden': _bool(true),
        if (requires.isNotEmpty) 'requires': List<Object>.of(requires),
        if (parameters.isNotEmpty)
          'parameters': <Object>[for (final p in parameters) p.toTree()],
        'output': output.toTree(),
      };
}

/// A sidebar entry. Exactly one of [command], [screen], [builtin] is set.
final class GuiNavItem {
  const GuiNavItem.command(
    this.id,
    this.label,
    String this.command, {
    this.icon,
    this.group,
  })  : screen = null,
        builtin = null;

  const GuiNavItem.screen(
    this.id,
    this.label,
    String this.screen, {
    this.icon,
    this.group,
  })  : command = null,
        builtin = null;

  const GuiNavItem.builtin(
    this.id,
    this.label,
    String this.builtin, {
    this.icon,
    this.group,
  })  : command = null,
        screen = null;

  final String id;
  final String label;
  final String? icon;
  final String? group;
  final String? command;
  final String? screen;
  final String? builtin;

  Map<String, Object> toTree() => <String, Object>{
        'id': id,
        'label': label,
        if (icon != null) 'icon': icon!,
        if (group != null) 'group': group!,
        if (command != null) 'command': command!,
        if (screen != null) 'screen': screen!,
        if (builtin != null) 'builtin': builtin!,
      };
}

final class GuiManifest {
  const GuiManifest({
    required this.cli,
    required this.navigation,
    required this.commands,
    this.groups = const <GuiGroup>[],
    this.manifestVersion = 1,
  });

  final int manifestVersion;
  final GuiCliInfo cli;
  final List<GuiNavItem> navigation;
  final List<GuiCommand> commands;
  final List<GuiGroup> groups;

  /// The Nano Markup value tree (strings, maps, lists only).
  Map<String, Object> toTree() => <String, Object>{
        'manifestVersion': '$manifestVersion',
        'cli': cli.toTree(),
        'navigation': <Object>[for (final n in navigation) n.toTree()],
        if (groups.isNotEmpty)
          'groups': <Object>[for (final g in groups) g.toTree()],
        'commands': <Object>[for (final c in commands) c.toTree()],
      };
}

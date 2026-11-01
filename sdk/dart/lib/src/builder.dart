import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'ids.dart';
import 'model.dart';

/// GUI metadata attached to a `package:args` [Command].
final class GuiMeta {
  const GuiMeta({
    this.title,
    this.icon,
    this.group,
    this.output = const GuiOutput(),
    this.extraArgv = const <String>[],
    this.positionals = const <GuiParameter>[],
    this.secretOptions = const <String>{},
    this.pathOptions = const <String>{},
    this.destructive = false,
    this.interactive = false,
    this.longRunning = false,
    this.requires = const <String>[],
    this.hidden = false,
    this.showInNavigation = false,
    this.kind = GuiCommandKind.action,
    this.section,
  });

  final String? title;
  final String? icon;
  final String? group;
  final GuiOutput output;

  /// Appended to the command path, e.g. `['--json']`.
  final List<String> extraArgv;
  final List<GuiParameter> positionals;
  final Set<String> secretOptions;
  final Set<String> pathOptions;
  final bool destructive;
  final bool interactive;
  final bool longRunning;
  final List<String> requires;
  final bool hidden;

  /// Adds a sidebar entry pointing to this command.
  final bool showInNavigation;

  /// Whether the command only reads ([GuiCommandKind.info]) or does something.
  final GuiCommandKind kind;

  /// Optional sidebar section label.
  final String? section;
}

/// Implement on a [Command] to describe it to the GUI.
mixin GuiDescribed<T> on Command<T> {
  GuiMeta get gui;
}

/// Builds a manifest from [runner]'s command tree.
///
/// Every leaf command becomes a manifest command whose id is its path joined
/// with `.`. Commands without [GuiDescribed] are included with defaults.
/// [navigation] replaces the generated sidebar when given.
GuiManifest buildManifest(
  CommandRunner<Object?> runner, {
  required GuiCliInfo cli,
  List<GuiNavItem>? navigation,
}) {
  final commands = <GuiCommand>[];
  final nav = <GuiNavItem>[];

  void visit(Command<Object?> command, List<String> path) {
    final current = <String>[...path, command.name];
    if (command.subcommands.isNotEmpty) {
      for (final sub in _sorted(command.subcommands)) {
        visit(sub, current);
      }
      return;
    }
    final meta =
        command is GuiDescribed<Object?> ? command.gui : const GuiMeta();
    final id = commandId(current);
    final title = meta.title ?? _titleFor(command);
    commands.add(
      GuiCommand(
        id: id,
        argv: <String>[...current, ...meta.extraArgv],
        title: title,
        description: command.description.isEmpty ? null : command.description,
        parameters: <GuiParameter>[
          ..._options(command.argParser, meta),
          ...meta.positionals,
        ],
        output: meta.output,
        destructive: meta.destructive,
        interactive: meta.interactive,
        longRunning: meta.longRunning,
        requires: meta.requires,
        hidden: meta.hidden || command.hidden,
        icon: meta.icon,
        kind: meta.kind,
        section: meta.section,
      ),
    );
    if (meta.showInNavigation) {
      nav.add(
        GuiNavItem.command(id, title, id, icon: meta.icon, group: meta.group),
      );
    }
  }

  for (final command in _sorted(runner.commands)) {
    visit(command, const <String>[]);
  }
  return GuiManifest(
    cli: cli,
    navigation: navigation ?? nav,
    commands: commands,
  );
}

Iterable<Command<Object?>> _sorted(Map<String, Command<Object?>> commands) {
  // Aliases map to the same instance; keep the first, in registration order.
  final seen = <Command<Object?>>{};
  return commands.entries
      .where((e) => e.key == e.value.name && seen.add(e.value))
      .where((e) => e.value.name != 'help')
      .map((e) => e.value);
}

String _titleFor(Command<Object?> command) {
  final summary = command.summary.trim();
  if (summary.isEmpty) return command.name;
  final firstLine = summary.split('\n').first;
  return firstLine.endsWith('.')
      ? firstLine.substring(0, firstLine.length - 1)
      : firstLine;
}

Iterable<GuiParameter> _options(ArgParser parser, GuiMeta meta) sync* {
  for (final option in parser.options.values) {
    if (option.name == 'help' || option.hide) continue;
    if (option.isFlag) {
      yield GuiParameter(
        name: option.name,
        kind: GuiParamKind.flag,
        type: GuiParamType.boolean,
        defaultValue: option.defaultsTo == true ? 'true' : null,
        help: option.help,
      );
      continue;
    }
    final allowed = option.allowed ?? const <String>[];
    final type = meta.secretOptions.contains(option.name)
        ? GuiParamType.secret
        : meta.pathOptions.contains(option.name)
            ? GuiParamType.path
            : allowed.isNotEmpty
                ? GuiParamType.enumeration
                : GuiParamType.string;
    final defaultsTo = option.defaultsTo;
    yield GuiParameter(
      name: option.name,
      kind: GuiParamKind.option,
      type: type,
      required: option.mandatory,
      defaultValue: type == GuiParamType.secret || defaultsTo == null
          ? null
          : defaultsTo is List
              ? null
              : '$defaultsTo',
      values: allowed,
      multiple: option.isMultiple,
      help: option.help,
    );
  }
}

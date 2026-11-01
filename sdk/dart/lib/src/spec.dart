import 'dart:async';

import 'package:args/args.dart';

import 'ids.dart';
import 'model.dart';

/// Runs a command and returns its exit code.
typedef CliHandler = FutureOr<int> Function(CliInvocation invocation);

/// Thrown when a [CliSpec] is inconsistent. This is a programming error in
/// the CLI's command list, found when the spec is created (so in tests).
final class CliSpecError implements Exception {
  const CliSpecError(this.message);

  final String message;

  @override
  String toString() => 'Invalid CLI spec: $message';
}

/// One entry of the command tree: a [CliGroup] or a [CliCommand].
sealed class CliNode {
  CliNode({
    required this.name,
    required this.title,
    required this.description,
    this.icon,
    this.navigation = false,
    this.aliases = const <String>[],
    this.visible,
  });

  /// The word typed on the command line, e.g. `workers` or `work-dir`.
  final String name;

  /// Short human title shown in the GUI.
  final String title;

  /// One-sentence description shown in help and the GUI.
  final String description;

  /// Icon name from the manifest icon vocabulary.
  final String? icon;

  /// Adds a sidebar entry for this node. For a group the entry opens its
  /// [CliGroup.defaultCommand].
  final bool navigation;

  /// Extra names accepted on the command line.
  final List<String> aliases;

  /// Decides at runtime whether help lists this node (it can still be run).
  /// The manifest always lists it.
  final bool Function()? visible;
}

/// A node with children, e.g. `workers` containing `list`, `add`, `remove`.
final class CliGroup extends CliNode {
  CliGroup({
    required super.name,
    required super.title,
    required super.description,
    required this.children,
    this.defaultCommand,
    this.navigationCommand,
    this.section,
    super.icon,
    super.navigation,
    super.aliases,
    super.visible,
  });

  final List<CliNode> children;

  /// Sidebar section for this group and all its descendants.
  final String? section;

  /// Child run when the group is invoked alone (`syntila workers` runs
  /// `workers list`). Without it, invoking the group alone is a usage error.
  final String? defaultCommand;

  /// Child the sidebar entry opens (defaults to [defaultCommand]). Lets a
  /// group have a sidebar entry without changing what running it alone does.
  final String? navigationCommand;

  /// Child opened by the sidebar entry.
  String? get sidebarCommand => navigationCommand ?? defaultCommand;
}

/// A runnable command.
final class CliCommand extends CliNode {
  CliCommand({
    required super.name,
    required super.title,
    required super.description,
    required this.handler,
    this.parameters = const <GuiParameter>[],
    this.output = const GuiOutput(),
    this.destructive = false,
    this.interactive = false,
    this.longRunning = false,
    this.requires = const <String>[],
    this.guiHidden = false,
    this.kind = GuiCommandKind.action,
    this.section,
    super.icon,
    super.navigation,
    super.aliases,
    super.visible,
  });

  final CliHandler handler;

  /// Options, flags and positionals, in order. Positionals are matched in
  /// the order listed.
  final List<GuiParameter> parameters;

  /// Format of what the handler writes when the GUI runs it, and how to show
  /// it.
  final GuiOutput output;

  /// The GUI asks for confirmation first.
  final bool destructive;

  /// Needs a terminal (prompts); the GUI warns instead of auto-running.
  final bool interactive;

  /// May take long; the GUI offers Cancel.
  final bool longRunning;

  /// Preconditions such as `serviceRunning`.
  final List<String> requires;

  /// Keeps the command out of the GUI's generic command list.
  final bool guiHidden;

  /// [GuiCommandKind.info] for commands that only read and report,
  /// [GuiCommandKind.action] (the default) for those that do something. A GUI
  /// can use this as classification independent of the sidebar section.
  final GuiCommandKind kind;

  /// Optional sidebar section label.
  final String? section;
}

/// Everything a CLI declares about itself: identity, shared options and the
/// command tree. The runner, help and `--gui-manifest` all derive from it.
final class CliSpec {
  CliSpec({
    required this.name,
    required this.description,
    required this.version,
    required this.nodes,
    this.displayName,
    this.globals = const <GuiParameter>[],
    this.jsonArgs = const <String>['--json'],
    this.usageExitCode = 64,
    this.usageBuilder,
  }) {
    _validate(this);
  }

  /// Executable name, e.g. `syntila`.
  final String name;
  final String description;
  final String version;
  final String? displayName;

  /// Options and flags accepted before or after any command, e.g. `--json`
  /// and `--data-dir`.
  final List<GuiParameter> globals;

  /// Top-level commands and groups, in display order.
  final List<CliNode> nodes;

  /// Arguments the GUI appends to commands whose output format is JSON.
  final List<String> jsonArgs;

  /// Exit code for usage errors (unknown command, missing argument).
  final int usageExitCode;

  /// Replaces the top-level usage text (printed by `--help` and with
  /// top-level usage errors). Use [flatUsage] for a one-line-per-command
  /// listing; without it `package:args` lists top-level commands only.
  final String Function(CliSpec spec)? usageBuilder;

  /// Calls [visit] for every command with its path, in declaration order.
  void forEachCommand(
    void Function(List<String> path, CliCommand command) visit,
  ) {
    void walk(CliNode node, List<String> path) {
      final here = <String>[...path, node.name];
      switch (node) {
        case CliGroup():
          for (final child in node.children) {
            walk(child, here);
          }
        case CliCommand():
          visit(here, node);
      }
    }

    for (final node in nodes) {
      walk(node, const <String>[]);
    }
  }
}

/// What a handler receives: the parsed command line.
final class CliInvocation {
  CliInvocation({
    required this.command,
    required this.path,
    required this.out,
    required this.err,
    required ArgResults args,
    required Map<String, Object?> globals,
  })  : _args = args, // ignore: prefer_initializing_formals
        _globals = globals; // ignore: prefer_initializing_formals

  final CliCommand command;

  /// Words that selected the command, e.g. `[workers, add]`.
  final List<String> path;

  final StringSink out;
  final StringSink err;
  final ArgResults _args;
  final Map<String, Object?> _globals;

  /// Value of a flag declared in the command's parameters.
  bool flag(String name) => _args.flag(name);

  /// Value of an option declared in the command's parameters (the default
  /// when not given).
  String? option(String name) => _args.option(name);

  /// Values of a `multiple` option.
  List<String> multiOption(String name) => _args.multiOption(name);

  /// Value of a global flag, wherever it was given on the command line.
  bool globalFlag(String name) => _globals[name] == true;

  /// Value of a global option, wherever it was given on the command line.
  String? globalOption(String name) => _globals[name] as String?;

  /// Positional values in order.
  List<String> get positionals => _args.rest;

  /// Value of the positional named [name] (null when optional and absent).
  String? positional(String name) {
    final index = _positionals.indexWhere((p) => p.name == name);
    if (index < 0) {
      throw ArgumentError.value(name, 'name', 'no such positional');
    }
    return index < positionals.length ? positionals[index] : null;
  }

  /// All values of the `multiple` positional named [name].
  List<String> positionalList(String name) {
    final index = _positionals.indexWhere((p) => p.name == name);
    if (index < 0) {
      throw ArgumentError.value(name, 'name', 'no such positional');
    }
    return positionals.skip(index).toList();
  }

  List<GuiParameter> get _positionals => command.parameters
      .where((p) => p.kind == GuiParamKind.positional)
      .toList();
}

final _word = RegExp(r'^[a-z][a-z0-9]*(-[a-z0-9]+)*$');

void _validate(CliSpec spec) {
  void fail(String message) => throw CliSpecError(message);

  final globalNames = <String>{};
  for (final g in spec.globals) {
    if (g.kind == GuiParamKind.positional) {
      fail('global "${g.name}" cannot be positional');
    }
    _validateParameter(g, 'global "${g.name}"');
    if (g.name == 'help' || !globalNames.add(g.name)) {
      fail('global option name "${g.name}" is reserved or duplicated');
    }
  }

  final ids = <String>{};
  void walk(List<CliNode> nodes, List<String> path) {
    final names = <String>{};
    for (final node in nodes) {
      final here = <String>[...path, node.name];
      final label = here.join(' ');
      if (!_word.hasMatch(node.name)) {
        fail('"$label": names are lowercase words joined by "-"');
      }
      for (final name in [node.name, ...node.aliases]) {
        if (!_word.hasMatch(name)) fail('"$label": invalid alias "$name"');
        if (name == 'help' && path.isEmpty) {
          fail('"help" is reserved for the generated help command');
        }
        if (!names.add(name)) {
          fail('"${[...path, name].join(' ')}" is declared twice');
        }
      }
      if (!ids.add(commandId(here))) {
        fail('"$label" has the same manifest id as another command');
      }
      switch (node) {
        case CliGroup():
          if (node.children.isEmpty) fail('group "$label" has no children');
          final def = node.defaultCommand;
          for (final (field, value) in [
            ('defaultCommand', def),
            ('navigationCommand', node.navigationCommand),
          ]) {
            if (value != null &&
                !node.children.any((c) => c is CliCommand && c.name == value)) {
              fail('group "$label": $field "$value" is not a command child');
            }
          }
          if (node.navigation && node.sidebarCommand == null) {
            fail(
              'group "$label" has a sidebar entry but no defaultCommand or '
              'navigationCommand',
            );
          }
          walk(node.children, here);
        case CliCommand():
          _validateCommand(node, label, globalNames);
      }
    }
  }

  walk(spec.nodes, const <String>[]);
}

void _validateCommand(CliCommand command, String label, Set<String> globals) {
  void fail(String message) => throw CliSpecError('"$label": $message');

  final seen = <String>{};
  final stdinParameters =
      command.parameters.where((p) => p.stdinFlag != null).toList();
  if (stdinParameters.length > 1) fail('only one stdin secret is supported');
  for (final p in stdinParameters) {
    if (!command.parameters.any(
        (flag) => flag.name == p.stdinFlag && flag.kind == GuiParamKind.flag)) {
      fail('stdinFlag "${p.stdinFlag}" must refer to a declared flag');
    }
  }
  var sawOptionalPositional = false;
  final positionals = command.parameters.where(
    (p) => p.kind == GuiParamKind.positional,
  );
  for (final p in command.parameters) {
    _validateParameter(p, '"$label" parameter "${p.name}"');
    if (p.name == 'help' || globals.contains(p.name) || !seen.add(p.name)) {
      fail('parameter name "${p.name}" is reserved or duplicated');
    }
    if (p.kind != GuiParamKind.positional) continue;
    if (p.required && sawOptionalPositional) {
      fail('required positional "${p.name}" follows an optional one');
    }
    if (!p.required) sawOptionalPositional = true;
    if (p.multiple && p != positionals.last) {
      fail('only the last positional can be multiple ("${p.name}")');
    }
  }
}

void _validateParameter(GuiParameter p, String label) {
  void fail(String message) => throw CliSpecError('$label: $message');

  if (p.stdinFlag != null &&
      (p.type != GuiParamType.secret ||
          p.kind != GuiParamKind.option ||
          !_word.hasMatch(p.stdinFlag!) ||
          p.multiple)) {
    fail('stdinFlag requires a single secret option and a valid flag name');
  }
  if (!_word.hasMatch(p.name)) {
    fail('names are lowercase words joined by "-"');
  }
  switch (p.kind) {
    case GuiParamKind.flag:
      if (p.type != GuiParamType.boolean) fail('a flag must be boolean');
      if (p.multiple || p.required) {
        fail('a flag cannot be multiple or required');
      }
    case GuiParamKind.option:
      if (p.type == GuiParamType.boolean) {
        fail('use a flag for boolean values');
      }
    case GuiParamKind.positional:
      if (p.type == GuiParamType.boolean) {
        fail('a positional cannot be boolean');
      }
  }
  if (p.type == GuiParamType.enumeration && p.values.isEmpty) {
    fail('an enum needs values');
  }
  if (p.type != GuiParamType.enumeration && p.values.isNotEmpty) {
    fail('values are only for enums');
  }
  if (p.type == GuiParamType.secret && p.defaultValue != null) {
    fail('a secret cannot have a default');
  }
  final def = p.defaultValue;
  if (def != null && p.values.isNotEmpty && !p.values.contains(def)) {
    fail('default "$def" is not an allowed value');
  }
}

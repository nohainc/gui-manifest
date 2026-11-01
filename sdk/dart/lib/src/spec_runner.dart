import 'dart:async';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'model.dart';
import 'negotiation.dart';
import 'spec.dart';
import 'spec_manifest.dart';

/// Runs a CLI described by a [CliSpec]: answers `--gui-manifest[=N]`, otherwise
/// parses [args] with `package:args` and runs the selected handler. Returns
/// the exit code.
Future<int> runCli(
  CliSpec spec,
  List<String> args, {
  required StringSink out,
  required StringSink err,
}) async {
  switch (GuiManifestRequest.parse(args)) {
    case GuiManifestAccepted():
      out.write(encodeManifest(manifestFromSpec(spec)));
      return 0;
    case GuiManifestRejected(:final message):
      err.writeln('${spec.name}: $message');
      return 2;
    case null:
      return CliRunner(spec, out: out, err: err).execute(args);
  }
}

/// The `package:args` runner generated from a [CliSpec].
///
/// Global options are accepted anywhere on the command line, a group invoked
/// alone runs its default command, and usage errors become
/// [CliSpec.usageExitCode].
final class CliRunner extends CommandRunner<int> {
  CliRunner(this.spec, {required this.out, required this.err})
      : super(spec.name, spec.description) {
    for (final g in spec.globals) {
      _addParameter(argParser, g);
    }
    for (final node in spec.nodes) {
      addCommand(_build(node));
    }
  }

  final CliSpec spec;
  final StringSink out;
  final StringSink err;
  Map<String, Object?> _globals = const <String, Object?>{};

  Command<int> _build(CliNode node) => switch (node) {
        CliGroup() => _GroupCommand(node, this),
        CliCommand() => _LeafCommand(node, this),
      };

  /// Runs [args]; never throws for bad input.
  Future<int> execute(List<String> args) async {
    try {
      return await run(args) ?? 0;
    } on UsageException catch (e) {
      err
        ..writeln(e.message)
        ..writeln()
        ..writeln(e.usage);
      return spec.usageExitCode;
    }
  }

  @override
  void printUsage() => out.writeln(usage);

  @override
  String get usage {
    final custom = spec.usageBuilder?.call(spec);
    // Callers add the final newline.
    return custom == null ? super.usage : custom.trimRight();
  }

  /// `args` builds this text from a private field; use [usage] so errors and
  /// `--help` agree.
  @override
  Never usageException(String message) => throw UsageException(message, usage);

  @override
  Future<int?> runCommand(ArgResults topLevelResults) {
    var top = topLevelResults;
    final chain = _chain(top);
    final last = chain.last;
    // Nothing to run: `args` prints help and succeeds; a CLI wants a usage
    // error so scripts notice.
    if (chain.length == 1 && top.rest.isEmpty && !top.flag('help')) {
      usageException('Missing command.');
    }
    // `syntila workers` runs `workers list`; `args` itself would report a
    // missing subcommand.
    final defaultCommand = last.command is _GroupCommand
        ? (last.command as _GroupCommand).group.defaultCommand
        : null;
    if (defaultCommand != null &&
        last.results.rest.isEmpty &&
        !chain.any(
          (c) => c.results.options.contains('help') && c.results.flag('help'),
        )) {
      top = parse([...top.arguments, defaultCommand]);
    }
    _globals = _resolveGlobals(top);
    return super.runCommand(top);
  }

  /// The results from the top level down to the selected command, each with
  /// the command it selected (null for the top level).
  List<({ArgResults results, Command<int>? command})> _chain(ArgResults top) {
    final chain = <({ArgResults results, Command<int>? command})>[
      (results: top, command: null),
    ];
    var results = top;
    Map<String, Command<int>> commands = this.commands;
    while (results.command != null) {
      results = results.command!;
      final command = commands[results.name];
      chain.add((results: results, command: command));
      commands = command?.subcommands ?? const <String, Command<int>>{};
    }
    return chain;
  }

  /// A global's value is the last one given anywhere on the command line,
  /// else the default.
  Map<String, Object?> _resolveGlobals(ArgResults top) {
    final results = [for (final c in _chain(top)) c.results];
    final values = <String, Object?>{};
    for (final g in spec.globals) {
      Object? value;
      for (final r in results) {
        if (!r.options.contains(g.name)) continue;
        if (identical(r, results.first) || r.wasParsed(g.name)) {
          value = r[g.name];
        }
      }
      values[g.name] = value;
    }
    return values;
  }
}

void _addParameter(ArgParser parser, GuiParameter p) {
  if (p.stdinFlag != null) return;
  switch (p.kind) {
    case GuiParamKind.flag:
      parser.addFlag(
        p.name,
        help: p.help ?? p.label,
        negatable: false,
        defaultsTo: p.defaultValue == 'true',
        hide: p.hidden,
      );
    case GuiParamKind.option:
      final help = p.help ?? p.label;
      if (p.multiple) {
        parser.addMultiOption(
          p.name,
          help: help,
          allowed: p.values.isEmpty ? null : p.values,
          defaultsTo: p.defaultValue == null ? null : [p.defaultValue!],
          hide: p.hidden,
        );
      } else {
        parser.addOption(
          p.name,
          help: help,
          allowed: p.values.isEmpty ? null : p.values,
          defaultsTo: p.defaultValue,
          mandatory: p.required,
          hide: p.hidden,
        );
      }
    case GuiParamKind.positional:
      break;
  }
}

mixin _NodeCommand on Command<int> {
  CliNode get node;
  CliRunner get cliRunner => runner as CliRunner;

  @override
  String get name => node.name;

  @override
  String get description => node.description;

  @override
  List<String> get aliases => node.aliases;

  @override
  bool get hidden => node.visible?.call() == false || super.hidden;

  @override
  void printUsage() => cliRunner.out.writeln(usage);
}

final class _GroupCommand extends Command<int> with _NodeCommand {
  _GroupCommand(this.group, CliRunner runner) {
    for (final g in runner.spec.globals) {
      _addParameter(argParser, g);
    }
    for (final child in group.children) {
      addSubcommand(runner._build(child));
    }
  }

  final CliGroup group;

  @override
  CliNode get node => group;

  @override
  Future<int> run() async => throw StateError('groups are not run directly');
}

final class _LeafCommand extends Command<int> with _NodeCommand {
  _LeafCommand(this.command, CliRunner runner) {
    for (final g in runner.spec.globals) {
      _addParameter(argParser, g);
    }
    for (final p in command.parameters) {
      _addParameter(argParser, p);
    }
  }

  final CliCommand command;

  @override
  CliNode get node => command;

  /// `example workers remove [options] <id>` instead of `[arguments]`.
  @override
  String get invocation {
    final words = [
      for (final p in command.parameters)
        if (p.kind == GuiParamKind.positional)
          p.required
              ? '<${p.name}>${p.multiple ? '...' : ''}'
              : '[<${p.name}>${p.multiple ? '...' : ''}]',
    ];
    return super.invocation.replaceFirst(
          RegExp(r' \[arguments\]$'),
          ' [options]${words.isEmpty ? '' : ' ${words.join(' ')}'}',
        );
  }

  @override
  Future<int> run() async {
    final args = argResults!;
    // `args` only complains about a missing mandatory option when its value
    // is read, as an ArgumentError; report it as a usage error up front.
    for (final p in command.parameters) {
      if (p.stdinFlag == null &&
          p.kind == GuiParamKind.option &&
          p.required &&
          !args.wasParsed(p.name)) {
        usageException('Option "--${p.name}" is mandatory.');
      }
    }
    final positionals = command.parameters
        .where((p) => p.kind == GuiParamKind.positional)
        .toList();
    final required = positionals.where((p) => p.required).length;
    final unlimited = positionals.isNotEmpty && positionals.last.multiple;
    if (args.rest.length < required) {
      usageException(
        'Missing required argument "${positionals[args.rest.length].name}".',
      );
    }
    if (!unlimited && args.rest.length > positionals.length) {
      usageException('Unexpected argument "${args.rest[positionals.length]}".');
    }
    return command.handler(
      CliInvocation(
        command: command,
        path: _path(),
        out: cliRunner.out,
        err: cliRunner.err,
        args: args,
        globals: cliRunner._globals,
      ),
    );
  }

  List<String> _path() {
    final path = <String>[];
    for (Command<int>? c = this; c != null; c = c.parent) {
      path.insert(0, (c as _NodeCommand).node.name);
    }
    return path;
  }
}

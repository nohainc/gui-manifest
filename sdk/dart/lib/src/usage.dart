import 'model.dart';
import 'spec.dart';

/// One line per command, sorted by top-level name:
///
/// ```text
/// Usage: mycli [--data-dir DIR] [--json] <command>
///
///   folders                       List allowed folders
///   folders add PATH [--name NAME]  Add an allowed folder
/// ```
///
/// A command's syntax shows its positionals (`NAME`, `[NAME]`) and options
/// (`[--name NAME]`, `--token TOKEN`), not flags. A group with a
/// `defaultCommand` is listed under its own name with that command's
/// description. Nodes whose [CliNode.visible] returns false, and everything
/// under them, are left out. [header] replaces the generated `Usage:` line.
String flatUsage(CliSpec spec, {String? header}) {
  final buffer = StringBuffer(header ?? _header(spec))
    ..writeln()
    ..writeln();

  void line(String syntax, String description) {
    if (syntax.length > 28) {
      buffer
        ..writeln('  $syntax')
        ..writeln('${' ' * 32}$description');
    } else {
      buffer.writeln('  ${syntax.padRight(30)}$description');
    }
  }

  void emit(CliNode node, List<String> path) {
    if (node.visible?.call() == false) return;
    final here = [...path, node.name];
    switch (node) {
      case CliGroup():
        final defaultCommand = node.defaultCommand;
        if (defaultCommand != null) {
          final child = node.children.firstWhere(
            (c) => c.name == defaultCommand,
          );
          line(_syntax(here, child as CliCommand), child.description);
        }
        for (final child in node.children) {
          if (child.name != defaultCommand) emit(child, here);
        }
      case CliCommand():
        line(_syntax(here, node), node.description);
    }
  }

  final sorted = [...spec.nodes]..sort((a, b) => a.name.compareTo(b.name));
  for (final node in sorted) {
    emit(node, const <String>[]);
  }
  return buffer.toString();
}

String _header(CliSpec spec) {
  final globals = [
    for (final g in spec.globals)
      g.kind == GuiParamKind.flag
          ? '[--${g.name}]'
          : '[--${g.name} ${_placeholder(g.name)}]',
  ];
  return 'Usage: ${spec.name}${globals.isEmpty ? '' : ' ${globals.join(' ')}'}'
      ' <command>';
}

String _syntax(List<String> path, CliCommand command) {
  final words = <String>[...path];
  for (final p in command.parameters) {
    if (p.hidden || p.stdinFlag != null) continue;
    switch (p.kind) {
      case GuiParamKind.positional:
        final name = '${_placeholder(p.name)}${p.multiple ? '...' : ''}';
        words.add(p.required ? name : '[$name]');
      case GuiParamKind.option:
        final option = '--${p.name} ${_placeholder(p.name)}';
        words.add(p.required ? option : '[$option]');
      case GuiParamKind.flag:
        break;
    }
  }
  return words.join(' ');
}

String _placeholder(String name) => name.toUpperCase().replaceAll('-', '_');

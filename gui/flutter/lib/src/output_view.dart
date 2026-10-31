import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nanomarkup/nanomarkup.dart' as nano;

import 'cli_runner.dart';
import 'manifest.dart';

/// Shows a command result: a formatted view when the output parses, plus the
/// raw stdout/stderr, exit code and exact command line (spec §8).
class OutputView extends StatelessWidget {
  const OutputView({
    super.key,
    required this.command,
    required this.result,
    required this.executable,
  });

  final CommandSpec command;
  final CliResult result;
  final String executable;

  Object? _parsed() {
    final text = result.stdout.trim();
    if (text.isEmpty) return null;
    try {
      return switch (command.format) {
        'json' => jsonDecode(text),
        'nano' => nano.decode(text),
        'jsonLines' => [
          for (final line in const LineSplitter().convert(text))
            if (line.trim().isNotEmpty) jsonDecode(line),
        ],
        _ => null,
      };
    } on FormatException {
      return null;
    } on nano.DecodeError {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = _parsed();
    final status = result.cancelled
        ? 'Cancelled'
        : result.ok
        ? 'Succeeded'
        : 'Failed (exit ${result.exitCode})';
    final formatted = parsed == null || command.view == 'raw'
        ? null
        : _Formatted(value: parsed, view: command.view);
    return DefaultTabController(
      length: formatted == null ? 1 : 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                result.ok ? Icons.check_circle_outline : Icons.error_outline,
                color: result.ok
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '$status · ${result.duration.inMilliseconds} ms',
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            '\$ ${[executable, ...result.args].join(' ')}',
            style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              if (formatted != null) const Tab(text: 'Result'),
              const Tab(text: 'Raw output'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                if (formatted != null) SingleChildScrollView(child: formatted),
                _Raw(result: result),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Raw extends StatelessWidget {
  const _Raw({required this.result});

  final CliResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              result.stdout.isEmpty ? '(no output)' : result.stdout,
              style: mono,
            ),
            if (result.stderr.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                result.stderr,
                style: mono?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _cell(Object? v) => switch (v) {
  null => '',
  String() => v,
  num() || bool() => '$v',
  _ => jsonEncode(v),
};

/// Finds the rows for a table: a list, or the first list inside a map.
List<Map<String, Object?>>? _rows(Object? value) {
  if (value is List && value.every((e) => e is Map)) {
    return [for (final e in value) (e as Map).cast<String, Object?>()];
  }
  if (value is Map) {
    for (final v in value.values) {
      final rows = _rows(v);
      if (rows != null) return rows;
    }
  }
  return null;
}

class _Formatted extends StatelessWidget {
  const _Formatted({required this.value, required this.view});

  final Object value;
  final String view;

  @override
  Widget build(BuildContext context) {
    if (view == 'table') {
      final rows = _rows(value);
      if (rows != null) return _table(context, rows);
    }
    if (view == 'log' && value is List) {
      return SelectableText(
        (value as List).map(_cell).join('\n'),
        style: const TextStyle(fontFamily: 'monospace'),
      );
    }
    if (value is Map) return _keyValue(context, (value as Map).cast());
    final rows = _rows(value);
    if (rows != null) return _table(context, rows);
    return SelectableText(const JsonEncoder.withIndent('  ').convert(value));
  }

  Widget _table(BuildContext context, List<Map<String, Object?>> rows) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No items'),
      );
    }
    final columns = <String>{for (final r in rows) ...r.keys}.toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [for (final c in columns) DataColumn(label: Text(c))],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                for (final c in columns) DataCell(SelectableText(_cell(r[c]))),
              ],
            ),
        ],
      ),
    );
  }

  Widget _keyValue(BuildContext context, Map<String, Object?> map) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final MapEntry(:key, :value) in map.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 200,
                    child: Text(
                      key,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(child: SelectableText(_cell(value))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';

String _cell(Object? v) => switch (v) {
  null => '',
  String() => v,
  num() || bool() => '$v',
  _ => jsonEncode(v),
};

/// Finds the rows for a table: a list of maps, or the first one inside a map.
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

/// A decoded result as a table, key/value list or log, per the manifest's
/// `view`.
class FormattedView extends StatelessWidget {
  const FormattedView({super.key, required this.value, required this.view});

  final Object value;
  final String view;

  @override
  Widget build(BuildContext context) {
    if (view == 'table') {
      final rows = _rows(value);
      if (rows != null) return _table(rows);
    }
    if (view == 'log' && value is List) {
      return SelectableText(
        (value as List).map(_cell).join('\n'),
        style: const TextStyle(fontFamily: 'monospace'),
      );
    }
    if (value is Map) return _keyValue(context, (value as Map).cast());
    final rows = _rows(value);
    if (rows != null) return _table(rows);
    return SelectableText(const JsonEncoder.withIndent('  ').convert(value));
  }

  Widget _table(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) {
      return const Padding(padding: EdgeInsets.all(8), child: Text('No items'));
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
    return Column(
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
    );
  }
}

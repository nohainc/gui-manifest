import 'dart:convert';

import 'package:nanomarkup/nanomarkup.dart' as nano;

/// How a command's structured result is written out as text.
enum OutputFormatOption {
  nano('Nano'),
  json('JSON'),
  yaml('YAML');

  const OutputFormatOption(this.label);

  final String label;

  static OutputFormatOption fromName(Object? name) =>
      values.firstWhere((option) => option.name == name, orElse: () => nano);
}

/// Decodes a command's stdout according to the format the manifest declares
/// (`json`, `jsonLines`, `nano`). Returns null for plain text or output that
/// does not parse, so the caller shows it verbatim.
Object? parseOutput(String stdout, String declaredFormat) {
  final text = stdout.trim();
  if (text.isEmpty) return null;
  try {
    return switch (declaredFormat) {
      'json' => jsonDecode(text),
      'jsonLines' => [
        for (final line in const LineSplitter().convert(text))
          if (line.trim().isNotEmpty) jsonDecode(line),
      ],
      'nano' => nano.decode(text),
      _ => null,
    };
  } on FormatException {
    return null;
  } on nano.DecodeError {
    return null;
  }
}

/// Writes [data] (maps, lists and scalars, as decoded from JSON or Nano
/// Markup) in [format].
///
/// Nano Markup has only strings, so numbers, booleans and null become their
/// text (null is empty). Data Nano cannot express (for example a key with
/// forbidden characters) is written as JSON instead.
String renderData(Object? data, OutputFormatOption format) {
  switch (format) {
    case OutputFormatOption.json:
      return const JsonEncoder.withIndent('  ').convert(data);
    case OutputFormatOption.yaml:
      return _yaml(data).join('\n');
    case OutputFormatOption.nano:
      try {
        return nano.encode(_nanoValue(data));
      } on nano.EncodeError {
        return const JsonEncoder.withIndent('  ').convert(data);
      }
  }
}

Object _nanoValue(Object? v) => switch (v) {
  Map() => {for (final e in v.entries) '${e.key}': _nanoValue(e.value)},
  List() => [for (final e in v) _nanoValue(e)],
  null => '',
  _ => '$v',
};

List<String> _yaml(Object? value) {
  switch (value) {
    case Map() when value.isNotEmpty:
      final lines = <String>[];
      for (final e in value.entries) {
        final key = _yamlString('${e.key}');
        final child = e.value;
        if (_isBlock(child)) {
          lines.add('$key:');
          lines.addAll(_yaml(child).map((l) => '  $l'));
        } else {
          lines.add('$key: ${_scalar(child)}');
        }
      }
      return lines;
    case List() when value.isNotEmpty:
      final lines = <String>[];
      for (final item in value) {
        if (_isBlock(item)) {
          final inner = _yaml(item);
          lines.add('- ${inner.first}');
          lines.addAll(inner.skip(1).map((l) => '  $l'));
        } else {
          lines.add('- ${_scalar(item)}');
        }
      }
      return lines;
    default:
      return [_scalar(value)];
  }
}

bool _isBlock(Object? v) =>
    (v is Map && v.isNotEmpty) || (v is List && v.isNotEmpty);

String _scalar(Object? v) => switch (v) {
  null => 'null',
  bool() || num() => '$v',
  Map() => '{}',
  List() => '[]',
  _ => _yamlString('$v'),
};

final _plain = RegExp(r'^[A-Za-z_./@][A-Za-z0-9_./@ -]*$');
final _reserved = RegExp(
  r'^(true|false|null|yes|no|on|off|y|n|~)$|^[-+]?(\d[\d_]*)?\.?\d+([eE][-+]?\d+)?$|^0[xo][0-9a-fA-F]+$',
  caseSensitive: false,
);

/// Plain when that is safe, otherwise double-quoted (JSON strings are valid
/// YAML double-quoted scalars).
String _yamlString(String s) {
  final plain =
      _plain.hasMatch(s) &&
      !_reserved.hasMatch(s) &&
      !s.endsWith(' ') &&
      !s.contains(' #');
  return plain ? s : jsonEncode(s);
}

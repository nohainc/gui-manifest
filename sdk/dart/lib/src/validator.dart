import 'package:nanomarkup/nanomarkup.dart';

/// A spec violation at a path like `$.commands[2].argv`.
final class ManifestIssue {
  const ManifestIssue(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

final _id = RegExp(r'^[a-z][a-zA-Z0-9]*(\.[a-z][a-zA-Z0-9]*)*$');
const _bools = {'true', 'false'};
const _kindValues = {'info', 'action'};
const _views = {'form', 'table', 'keyValue', 'card', 'log', 'confirm', 'raw'};
const _formats = {'text', 'json', 'jsonLines', 'nano'};
const _kinds = {'option', 'flag', 'positional'};
const _types = {
  'string', 'integer', 'number', 'boolean', 'enum', 'path', 'secret', //
};

/// Decodes Nano Markup [source] and validates it as a v1 manifest.
///
/// Throws [DecodeError] when [source] is not Nano Markup.
List<ManifestIssue> validateManifestSource(String source) =>
    validateManifest(decode(source));

/// Validates a decoded Nano Markup tree against SPEC v1.
List<ManifestIssue> validateManifest(Object root) {
  final issues = <ManifestIssue>[];
  void issue(String path, String message) =>
      issues.add(ManifestIssue(path, message));

  Map<String, Object>? map(Object? v, String path) {
    if (v is Map<String, Object>) return v;
    issue(path, 'expected a mapping');
    return null;
  }

  List<Object>? list(Object? v, String path) {
    if (v is List<Object>) return v;
    issue(path, 'expected a sequence');
    return null;
  }

  Map<String, Object>? mapRequired(Object? v, String path) {
    if (v != null) return map(v, path);
    issue(path, 'is required');
    return null;
  }

  List<Object>? listRequired(Object? v, String path) {
    if (v != null) return list(v, path);
    issue(path, 'is required');
    return null;
  }

  String? str(
    Map<String, Object> m,
    String key,
    String path, {
    bool required = false,
    Set<String>? oneOf,
    RegExp? pattern,
  }) {
    final v = m[key];
    if (v == null) {
      if (required) issue('$path.$key', 'is required');
      return null;
    }
    if (v is! String) {
      issue('$path.$key', 'expected a string');
      return null;
    }
    if (oneOf != null && !oneOf.contains(v)) {
      issue('$path.$key', '"$v" is not one of ${oneOf.join(', ')}');
    }
    if (pattern != null && !pattern.hasMatch(v)) {
      issue('$path.$key', '"$v" is not a valid id');
    }
    return v;
  }

  void strings(
    Map<String, Object> m,
    String key,
    String path, {
    bool required = false,
  }) {
    final v = m[key];
    if (v == null) {
      if (required) issue('$path.$key', 'is required');
      return;
    }
    final items = list(v, '$path.$key');
    if (items == null) return;
    for (final (i, item) in items.indexed) {
      if (item is! String) issue('$path.$key[$i]', 'expected a string');
    }
  }

  void uniqueIds(List<Object> items, String path) {
    final seen = <String>{};
    for (final (i, item) in items.indexed) {
      if (item is Map<String, Object> && item['id'] is String) {
        if (!seen.add(item['id'] as String)) {
          issue('$path[$i].id', 'duplicate id "${item['id']}"');
        }
      }
    }
  }

  final doc = map(root, r'$');
  if (doc == null) return issues;

  final version = str(doc, 'manifestVersion', r'$', required: true);
  if (version != null && version != '1') {
    issue(r'$.manifestVersion', 'expected "1", got "$version"');
  }

  final cli = mapRequired(doc['cli'], r'$.cli');
  if (cli != null) {
    str(cli, 'name', r'$.cli', required: true);
    str(cli, 'version', r'$.cli', required: true);
  }

  final groupIds = <String>{};
  final groupsRaw = doc['groups'];
  if (groupsRaw != null) {
    final groups = list(groupsRaw, r'$.groups');
    if (groups != null) {
      uniqueIds(groups, r'$.groups');
      for (final raw in groups) {
        if (raw is Map<String, Object> && raw['id'] is String) {
          groupIds.add(raw['id'] as String);
        }
      }
      for (final (i, raw) in groups.indexed) {
        final p = '\$.groups[$i]';
        final g = map(raw, p);
        if (g == null) continue;
        str(g, 'id', p, required: true, pattern: _id);
        str(g, 'label', p, required: true);
        final parent = str(g, 'parent', p, pattern: _id);
        if (parent != null && !groupIds.contains(parent)) {
          issue('$p.parent', 'unknown group "$parent"');
        }
        if (parent != null && parent == g['id']) {
          issue('$p.parent', 'a group cannot be its own parent');
        }
      }
    }
  }

  final commandIds = <String>{};
  final commands = listRequired(doc['commands'], r'$.commands');
  if (commands != null) {
    uniqueIds(commands, r'$.commands');
    for (final (i, raw) in commands.indexed) {
      final p = '\$.commands[$i]';
      final c = map(raw, p);
      if (c == null) continue;
      final id = str(c, 'id', p, required: true, pattern: _id);
      if (id != null) commandIds.add(id);
      strings(c, 'argv', p, required: true);
      str(c, 'title', p, required: true);
      str(c, 'icon', p);
      str(c, 'kind', p, oneOf: _kindValues);
      final group = str(c, 'group', p, pattern: _id);
      if (group != null && !groupIds.contains(group)) {
        issue('$p.group', 'unknown group "$group"');
      }
      for (final key in [
        'destructive',
        'interactive',
        'longRunning',
        'hidden',
      ]) {
        str(c, key, p, oneOf: _bools);
      }
      strings(c, 'requires', p);
      if (c['output'] != null) {
        final o = map(c['output'], '$p.output');
        if (o != null) {
          str(o, 'format', '$p.output', oneOf: _formats);
          str(o, 'view', '$p.output', oneOf: _views);
        }
      }
      if (c['parameters'] != null) {
        final params = list(c['parameters'], '$p.parameters');
        for (final (j, rawParam) in (params ?? const <Object>[]).indexed) {
          final pp = '$p.parameters[$j]';
          final param = map(rawParam, pp);
          if (param == null) continue;
          str(param, 'name', pp, required: true);
          str(param, 'kind', pp, required: true, oneOf: _kinds);
          final type = str(param, 'type', pp, required: true, oneOf: _types);
          str(param, 'required', pp, oneOf: _bools);
          str(param, 'multiple', pp, oneOf: _bools);
          strings(param, 'values', pp);
          if (type == 'enum' && param['values'] == null) {
            issue('$pp.values', 'is required for type enum');
          }
          if (type == 'secret' && param['default'] != null) {
            issue('$pp.default', 'secret parameters must not have a default');
          }
        }
      }
    }
  }

  final navigation = listRequired(doc['navigation'], r'$.navigation');
  if (navigation != null) {
    uniqueIds(navigation, r'$.navigation');
    for (final (i, raw) in navigation.indexed) {
      final p = '\$.navigation[$i]';
      final n = map(raw, p);
      if (n == null) continue;
      str(n, 'id', p, required: true, pattern: _id);
      str(n, 'label', p, required: true);
      final targets = [
        'command',
        'screen',
        'builtin',
      ].where(n.containsKey).toList();
      if (targets.length != 1) {
        issue(p, 'needs exactly one of command, screen, builtin');
      }
      final command = str(n, 'command', p);
      if (command != null &&
          commands != null &&
          !commandIds.contains(command)) {
        issue('$p.command', 'unknown command "$command"');
      }
      str(n, 'builtin', p, pattern: _id);
    }
  }
  return issues;
}

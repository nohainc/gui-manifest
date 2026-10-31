/// Turns a command word into a manifest id segment: `work-dir` → `workDir`.
String idSegment(String name) {
  final parts = name.split(RegExp(r'[-_]')).where((p) => p.isNotEmpty);
  final buffer = StringBuffer();
  for (final (i, p) in parts.indexed) {
    buffer.write(
      i == 0
          ? p.toLowerCase()
          : '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}',
    );
  }
  return buffer.toString();
}

/// Manifest id of the command or group at [path]: `[workers, add]` →
/// `workers.add`.
String commandId(Iterable<String> path) => path.map(idSegment).join('.');

import 'dart:convert';
import 'dart:io';

import 'package:gui_manifest/gui_manifest.dart';
import 'package:nanomarkup/nanomarkup.dart';

const _usage = '''
Usage:
  validate <manifest.nano>...   Validate manifest files ("-" reads stdin)
  validate --cli <executable>   Run "<executable> --gui-manifest=1" and validate

Exit status: 0 valid, 1 invalid, 2 usage or I/O error.''';

Future<void> main(List<String> args) async {
  exitCode = await run(args, stdout, stderr);
}

Future<int> run(List<String> args, IOSink out, IOSink err) async {
  if (args.isEmpty || args.contains('-h') || args.contains('--help')) {
    err.writeln(_usage);
    return args.isEmpty ? 2 : 0;
  }
  if (args.first == '--cli') {
    if (args.length != 2) {
      err.writeln(_usage);
      return 2;
    }
    final ProcessResult result;
    try {
      result = await Process.run(
        args[1],
        const ['--gui-manifest=1'],
        stdoutEncoding: null,
        stderrEncoding: utf8,
      );
    } on ProcessException catch (e) {
      err.writeln('${args[1]}: ${e.message}');
      return 2;
    }
    if (result.exitCode != 0) {
      err.writeln(
        '${args[1]}: exited with ${result.exitCode} '
        '(GUI manifest not supported)\n${result.stderr}',
      );
      return 1;
    }
    return _check(args[1], result.stdout as List<int>, out, err);
  }
  var status = 0;
  for (final path in args) {
    final List<int> bytes;
    try {
      bytes = path == '-'
          ? await stdin.fold<List<int>>(<int>[], (a, b) => a..addAll(b))
          : await File(path).readAsBytes();
    } on FileSystemException catch (e) {
      err.writeln('$path: ${e.message}');
      return 2;
    }
    final result = _check(path, bytes, out, err);
    if (result > status) status = result;
  }
  return status;
}

int _check(String name, List<int> bytes, IOSink out, IOSink err) {
  final Object tree;
  try {
    tree = decodeBytes(bytes);
  } on DecodeError catch (e) {
    err.writeln('$name: not Nano Markup: $e');
    return 1;
  }
  final issues = validateManifest(tree);
  if (issues.isEmpty) {
    out.writeln('$name: valid');
    return 0;
  }
  for (final issue in issues) {
    err.writeln('$name: $issue');
  }
  return 1;
}

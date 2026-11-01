import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nanomarkup/nanomarkup.dart';

import 'manifest.dart';

final class CliResult {
  CliResult({
    required this.args,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.duration,
    this.cancelled = false,
    DateTime? finishedAt,
  }) : finishedAt = finishedAt ?? DateTime.now();

  final List<String> args;
  final int exitCode;
  final String stdout;
  final String stderr;
  final Duration duration;
  final bool cancelled;

  /// When the command ended.
  final DateTime finishedAt;

  bool get ok => exitCode == 0 && !cancelled;
}

/// A started command that can be cancelled.
final class CliRun {
  CliRun(this.result, this._cancel);

  final Future<CliResult> result;
  final void Function() _cancel;

  void cancel() => _cancel();
}

/// Runs a CLI directly (never through a shell).
abstract interface class CliRunner {
  String get executable;

  Future<GuiManifestModel> loadManifest();

  CliRun start(List<String> args);
}

/// A runner that can securely provide a secret on standard input.
abstract interface class CliInputRunner {
  CliRun startWithInput(List<String> args, String input);
}

final class ProcessCliRunner implements CliRunner, CliInputRunner {
  ProcessCliRunner(this.executable, {this.environment});

  @override
  final String executable;
  final Map<String, String>? environment;

  @override
  Future<GuiManifestModel> loadManifest() async {
    final ProcessResult result;
    try {
      result = await Process.run(
        executable,
        const ['--gui-manifest=1'],
        environment: environment,
        stdoutEncoding: null,
        stderrEncoding: utf8,
      );
    } on ProcessException catch (e) {
      throw ManifestException('Cannot run $executable: ${e.message}');
    }
    if (result.exitCode != 0) {
      throw ManifestException(
        '$executable does not support the GUI manifest '
        '(exit ${result.exitCode}).\n${result.stderr}',
      );
    }
    final Object tree;
    try {
      tree = decodeBytes(result.stdout as List<int>);
    } on DecodeError catch (e) {
      throw ManifestException('$executable returned invalid Nano Markup: $e');
    }
    return GuiManifestModel.fromTree(tree);
  }

  @override
  CliRun start(List<String> args) => _start(args, null);

  @override
  CliRun startWithInput(List<String> args, String input) => _start(args, input);

  CliRun _start(List<String> args, String? input) {
    final watch = Stopwatch()..start();
    Process? process;
    var cancelled = false;
    Future<CliResult> run() async {
      try {
        process = await Process.start(
          executable,
          args,
          environment: environment,
        );
      } on ProcessException catch (e) {
        return CliResult(
          args: args,
          exitCode: -1,
          stdout: '',
          stderr: e.message,
          duration: watch.elapsed,
        );
      }
      final p = process!;
      if (input != null) p.stdin.writeln(input);
      unawaited(p.stdin.close());
      final out = p.stdout.transform(utf8.decoder).join();
      final err = p.stderr.transform(utf8.decoder).join();
      final code = await p.exitCode;
      return CliResult(
        args: args,
        exitCode: code,
        stdout: await out,
        stderr: await err,
        duration: watch.elapsed,
        cancelled: cancelled,
      );
    }

    return CliRun(run(), () {
      cancelled = true;
      process?.kill();
    });
  }
}

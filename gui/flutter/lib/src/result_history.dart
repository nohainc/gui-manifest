import 'package:flutter/foundation.dart';

import 'cli_runner.dart';

/// Every result of every command during this session, newest first, so
/// running a command again or opening another page never clears an earlier
/// result. A command left running keeps running when its page is closed.
class ResultHistory extends ChangeNotifier {
  ResultHistory({this.limitPerCommand = 50});

  /// Oldest results beyond this are dropped.
  final int limitPerCommand;

  final _results = <String, List<CliResult>>{};
  final _running = <String, CliRun>{};

  /// Results of [commandId], newest first.
  List<CliResult> resultsOf(String commandId) =>
      List.unmodifiable(_results[commandId] ?? const <CliResult>[]);

  bool isRunning(String commandId) => _running.containsKey(commandId);

  /// Records [run] as the command's running process, then its result.
  Future<CliResult> track(String commandId, CliRun run) async {
    _running[commandId] = run;
    notifyListeners();
    final result = await run.result;
    _running.remove(commandId);
    final list = _results.putIfAbsent(commandId, () => []);
    list.insert(0, result);
    if (list.length > limitPerCommand) {
      list.removeRange(limitPerCommand, list.length);
    }
    notifyListeners();
    return result;
  }

  void cancel(String commandId) => _running[commandId]?.cancel();

  /// Removes the results of [commandId] (only when the user asks).
  void clear(String commandId) {
    if (_results.remove(commandId) != null) notifyListeners();
  }
}

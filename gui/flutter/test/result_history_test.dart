import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gui_manifest_flutter/gui_manifest_flutter.dart';

CliResult _result(String tag) => CliResult(
  args: [tag],
  exitCode: 0,
  stdout: tag,
  stderr: '',
  duration: Duration.zero,
);

CliRun _run(Completer<CliResult> c, [void Function()? onCancel]) =>
    CliRun(c.future, onCancel ?? () {});

void main() {
  test('results are kept newest first and per command', () async {
    final history = ResultHistory();
    for (final tag in ['one', 'two', 'three']) {
      await history.track('a', CliRun(Future.value(_result(tag)), () {}));
    }
    await history.track('b', CliRun(Future.value(_result('other')), () {}));
    expect(history.resultsOf('a').map((r) => r.stdout), [
      'three',
      'two',
      'one',
    ]);
    expect(history.resultsOf('b').map((r) => r.stdout), ['other']);
    expect(history.resultsOf('none'), isEmpty);
  });

  test('a command is running until its result arrives', () async {
    final history = ResultHistory();
    final seen = <bool>[];
    history.addListener(() => seen.add(history.isRunning('a')));
    final done = Completer<CliResult>();
    final tracked = history.track('a', _run(done));
    expect(history.isRunning('a'), isTrue);
    expect(history.isRunning('b'), isFalse);
    done.complete(_result('x'));
    await tracked;
    expect(history.isRunning('a'), isFalse);
    expect(seen, [true, false]);
    expect(history.resultsOf('a'), hasLength(1));
  });

  test('cancel reaches the running process', () async {
    final history = ResultHistory();
    var cancelled = 0;
    final done = Completer<CliResult>();
    unawaited(history.track('a', _run(done, () => cancelled++)));
    history.cancel('a');
    history.cancel('other');
    expect(cancelled, 1);
    done.complete(_result('x'));
  });

  test('only the newest results are kept', () async {
    final history = ResultHistory(limitPerCommand: 3);
    for (var i = 1; i <= 5; i++) {
      await history.track('a', CliRun(Future.value(_result('$i')), () {}));
    }
    expect(history.resultsOf('a').map((r) => r.stdout), ['5', '4', '3']);
  });

  test('nothing is removed unless asked', () async {
    final history = ResultHistory();
    await history.track('a', CliRun(Future.value(_result('x')), () {}));
    await history.track('b', CliRun(Future.value(_result('y')), () {}));
    history.clear('a');
    expect(history.resultsOf('a'), isEmpty);
    expect(history.resultsOf('b'), hasLength(1));
  });

  test('a result records when it finished', () {
    final before = DateTime.now();
    final r = _result('x');
    expect(r.finishedAt.isBefore(before), isFalse);
  });
}

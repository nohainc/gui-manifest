import 'dart:io';

import 'package:test/test.dart';

import '../bin/validate.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('gm_validate'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<(int, String, String)> runIt(List<String> args) async {
    final out = File('${tmp.path}/out'), err = File('${tmp.path}/err');
    final o = out.openWrite(), e = err.openWrite();
    final code = await run(args, o, e);
    await o.close();
    await e.close();
    return (code, out.readAsStringSync(), err.readAsStringSync());
  }

  test('fixture is valid', () async {
    final (code, out, _) = await runIt([
      '../../conformance/fixtures/minimal.nano',
    ]);
    expect(code, 0);
    expect(out, contains('valid'));
  });

  test('invalid manifest exits 1 with issue paths', () async {
    final f = File('${tmp.path}/bad.nano')
      ..writeAsStringSync('..\n    manifestVersion 2');
    final (code, _, err) = await runIt([f.path]);
    expect(code, 1);
    expect(err, contains(r'$.manifestVersion'));
  });

  test('a scalar document is not a manifest', () async {
    final f = File('${tmp.path}/scalar.nano')..writeAsStringSync('{"a": 1}');
    final (code, _, err) = await runIt([f.path]);
    expect(code, 1);
    expect(err, contains(r'$: expected a mapping'));
  });

  test('non Nano Markup exits 1', () async {
    final f = File('${tmp.path}/bad.nano')
      ..writeAsStringSync('..\n   bad indentation');
    final (code, _, err) = await runIt([f.path]);
    expect(code, 1);
    expect(err, contains('not Nano Markup'));
  });

  test('missing file exits 2', () async {
    expect((await runIt(['${tmp.path}/none.nano'])).$1, 2);
  });
}

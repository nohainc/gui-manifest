import 'package:flutter_test/flutter_test.dart';
import 'package:gui_manifest_flutter/gui_manifest_flutter.dart';
import 'package:nanomarkup/nanomarkup.dart' as nano;

const _data = {
  'name': 'Mac',
  'slots': 2,
  'ready': true,
  'owner': null,
  'workers': [
    {'id': 'w1', 'type': 'gemini'},
    {'id': 'w2', 'type': 'codex'},
  ],
  'tags': ['a', 'b'],
};

void main() {
  group('Nano', () {
    test('writes maps and lists, scalars as text', () {
      expect(renderData(_data, OutputFormatOption.nano), '''..
    name Mac
    slots 2
    ready true
    owner
    workers:
        ..
            id w1
            type gemini
        ..
            id w2
            type codex
    tags:
        a
        b''');
    });

    test('is valid Nano Markup that decodes to the same text values', () {
      final text = renderData(_data, OutputFormatOption.nano);
      final back = nano.decode(text) as Map;
      expect(back['name'], 'Mac');
      expect(back['slots'], '2');
      expect(back['ready'], 'true');
      expect(back['owner'], '');
      expect((back['workers'] as List).length, 2);
    });

    test('a bare string or list works too', () {
      expect(renderData('hello', OutputFormatOption.nano), 'hello');
      expect(
        renderData(['a', 'b'], OutputFormatOption.nano),
        ':\n    a\n    b',
      );
    });

    test('data Nano cannot express falls back to JSON', () {
      final text = renderData({'bad key': 1}, OutputFormatOption.nano);
      expect(text, contains('"bad key": 1'));
    });
  });

  group('JSON', () {
    test('is indented and keeps types', () {
      expect(
        renderData({
          'a': 1,
          'b': [true, null],
        }, OutputFormatOption.json),
        '''{
  "a": 1,
  "b": [
    true,
    null
  ]
}''',
      );
    });
  });

  group('YAML', () {
    String yaml(Object? v) => renderData(v, OutputFormatOption.yaml);

    test('writes nested maps and lists with their types', () {
      expect(yaml(_data), '''name: Mac
slots: 2
ready: true
owner: null
workers:
  - id: w1
    type: gemini
  - id: w2
    type: codex
tags:
  - a
  - b''');
    });

    test('empty collections are inline', () {
      expect(yaml({'a': [], 'b': {}}), 'a: []\nb: {}');
    });

    test('lists of lists nest', () {
      expect(
        yaml([
          ['a', 'b'],
          ['c'],
        ]),
        '- - a\n  - b\n- - c',
      );
    });

    test('strings that would be read as something else are quoted', () {
      expect(
        yaml({
          'a': 'true',
          'b': 'null',
          'c': '42',
          'd': '',
          'e': ' pad',
          'f': 'x: y',
          'g': 'note # tail',
          'h': '- item',
          'i': 'two\nlines',
          'j': 'say "hi"',
          'k': '1.5e3',
          'l': 'No',
        }),
        '''a: "true"
b: "null"
c: "42"
d: ""
e: " pad"
f: "x: y"
g: "note # tail"
h: "- item"
i: "two\\nlines"
j: "say \\"hi\\""
k: "1.5e3"
l: "No"''',
      );
    });

    test('ordinary text stays plain', () {
      expect(
        yaml({
          'path': '/Users/me/Documents/Syntila',
          'url': 'wss://syntila.app',
          'name': 'Work Root',
          'mail': 'a@b.example',
        }),
        '''path: /Users/me/Documents/Syntila
url: "wss://syntila.app"
name: Work Root
mail: a@b.example''',
      );
    });
  });

  group('parseOutput', () {
    test('decodes by the declared format', () {
      expect(parseOutput('{"a": 1}', 'json'), {'a': 1});
      expect(parseOutput('{"a": 1}\n{"a": 2}\n', 'jsonLines'), [
        {'a': 1},
        {'a': 2},
      ]);
      expect(parseOutput('..\n    a 1', 'nano'), {'a': '1'});
    });

    test('plain text, empty or broken output is not data', () {
      expect(parseOutput('hello', 'text'), isNull);
      expect(parseOutput('', 'json'), isNull);
      expect(parseOutput('not json', 'json'), isNull);
      expect(parseOutput('..\n   bad', 'nano'), isNull);
    });
  });

  test('the options are Nano, JSON, YAML with Nano as the default', () {
    expect(OutputFormatOption.values.map((o) => o.label), [
      'Nano',
      'JSON',
      'YAML',
    ]);
    expect(OutputFormatOption.fromName('nope'), OutputFormatOption.nano);
    expect(OutputFormatOption.fromName(null), OutputFormatOption.nano);
  });
}

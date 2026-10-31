import 'package:gui_manifest/gui_manifest.dart';
import 'package:test/test.dart';

CliCommand _cmd(
  String name, {
  List<GuiParameter> parameters = const [],
  List<String> aliases = const [],
  bool navigation = false,
}) => CliCommand(
  name: name,
  title: name,
  description: name,
  parameters: parameters,
  aliases: aliases,
  navigation: navigation,
  handler: (_) => 0,
);

CliSpec _spec(List<CliNode> nodes, {List<GuiParameter> globals = const []}) =>
    CliSpec(
      name: 't',
      description: 't',
      version: '1',
      nodes: nodes,
      globals: globals,
    );

GuiParameter _param(
  String name, {
  GuiParamKind kind = GuiParamKind.option,
  GuiParamType type = GuiParamType.string,
  bool required = false,
  bool multiple = false,
  String? defaultValue,
  List<String> values = const [],
}) => GuiParameter(
  name: name,
  kind: kind,
  type: type,
  required: required,
  multiple: multiple,
  defaultValue: defaultValue,
  values: values,
);

Matcher _invalid(String part) => throwsA(
  isA<CliSpecError>().having((e) => e.message, 'message', contains(part)),
);

void main() {
  test('a valid spec is accepted', () {
    _spec([
      _cmd('status'),
      CliGroup(
        name: 'workers',
        title: 'Workers',
        description: 'Workers',
        defaultCommand: 'list',
        navigation: true,
        children: [
          _cmd('list'),
          _cmd(
            'add',
            parameters: [
              _param('type', kind: GuiParamKind.positional, required: true),
              _param('name'),
              _param(
                'force',
                kind: GuiParamKind.flag,
                type: GuiParamType.boolean,
              ),
            ],
          ),
        ],
      ),
    ]);
  });

  group('names', () {
    test('must be lowercase words', () {
      expect(() => _spec([_cmd('Status')]), _invalid('lowercase words'));
      expect(() => _spec([_cmd('work_dir')]), _invalid('lowercase words'));
    });
    test('siblings, aliases and "help" cannot clash', () {
      expect(() => _spec([_cmd('a'), _cmd('a')]), _invalid('declared twice'));
      expect(
        () => _spec([
          _cmd('a', aliases: ['b']),
          _cmd('b'),
        ]),
        _invalid('declared twice'),
      );
      expect(() => _spec([_cmd('help')]), _invalid('reserved'));
    });
    test('the same name may repeat in different groups', () {
      CliGroup g(String name) => CliGroup(
        name: name,
        title: name,
        description: name,
        children: [_cmd('list')],
      );
      _spec([g('workers'), g('folders')]);
    });
  });

  group('groups', () {
    CliGroup group({String? defaultCommand, bool navigation = false}) =>
        CliGroup(
          name: 'g',
          title: 'G',
          description: 'G',
          defaultCommand: defaultCommand,
          navigation: navigation,
          children: [_cmd('list')],
        );

    test('need children', () {
      expect(
        () => _spec([
          CliGroup(name: 'g', title: 'G', description: 'G', children: []),
        ]),
        _invalid('no children'),
      );
    });
    test('defaultCommand must be a command child', () {
      expect(
        () => _spec([group(defaultCommand: 'nope')]),
        _invalid('defaultCommand'),
      );
    });
    test('a sidebar entry needs a defaultCommand', () {
      expect(
        () => _spec([group(navigation: true)]),
        _invalid('defaultCommand'),
      );
      _spec([group(navigation: true, defaultCommand: 'list')]);
    });
  });

  group('parameters', () {
    CliSpec with_(
      List<GuiParameter> parameters, {
      List<GuiParameter> globals = const [],
    }) => _spec([_cmd('c', parameters: parameters)], globals: globals);

    test('required positionals cannot follow optional ones', () {
      expect(
        () => with_([
          _param('a', kind: GuiParamKind.positional),
          _param('b', kind: GuiParamKind.positional, required: true),
        ]),
        _invalid('follows an optional'),
      );
    });
    test('only the last positional can be multiple', () {
      expect(
        () => with_([
          _param('a', kind: GuiParamKind.positional, multiple: true),
          _param('b', kind: GuiParamKind.positional),
        ]),
        _invalid('last positional'),
      );
    });
    test('flags are boolean, options are not', () {
      expect(
        () => with_([_param('f', kind: GuiParamKind.flag)]),
        _invalid('flag must be boolean'),
      );
      expect(
        () => with_([_param('o', type: GuiParamType.boolean)]),
        _invalid('use a flag'),
      );
    });
    test('enums need values and defaults must be allowed', () {
      expect(
        () => with_([_param('e', type: GuiParamType.enumeration)]),
        _invalid('enum needs values'),
      );
      expect(
        () => with_([
          _param(
            'e',
            type: GuiParamType.enumeration,
            values: ['a'],
            defaultValue: 'b',
          ),
        ]),
        _invalid('not an allowed value'),
      );
    });
    test('secrets cannot have defaults', () {
      expect(
        () =>
            with_([_param('s', type: GuiParamType.secret, defaultValue: 'x')]),
        _invalid('secret'),
      );
    });
    test('names cannot clash with globals, help or each other', () {
      final json = _param(
        'json',
        kind: GuiParamKind.flag,
        type: GuiParamType.boolean,
      );
      expect(
        () => with_([json], globals: [json]),
        _invalid('reserved or duplicated'),
      );
      expect(() => with_([_param('help')]), _invalid('reserved or duplicated'));
      expect(
        () => with_([_param('a'), _param('a')]),
        _invalid('reserved or duplicated'),
      );
    });
  });
}

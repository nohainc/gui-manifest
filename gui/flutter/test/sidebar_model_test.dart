import 'package:flutter_test/flutter_test.dart';
import 'package:gui_manifest_flutter/gui_manifest_flutter.dart';
import 'package:gui_manifest_flutter/src/sidebar_model.dart';

Map<String, Object> _command(
  String id,
  String title, {
  String? group,
  bool hidden = false,
  String? kind,
  String? icon,
  String? section,
  bool unsectioned = false,
}) => {
  'id': id,
  'argv': id.split('.'),
  'title': title,
  'group': ?group,
  if (hidden) 'hidden': 'true',
  'kind': ?kind,
  if (!unsectioned) 'section': section ?? (kind == 'info' ? 'INFO' : 'ACTIONS'),
  'icon': ?icon,
};

final _groups = [
  {'id': 'workers', 'label': 'Workers', 'icon': 'cpu'},
  {
    'id': 'config',
    'label': 'Config',
    'icon': 'sliders',
    'section': 'WORKSPACE',
  },
  {'id': 'tools', 'label': 'Tools', 'parent': 'config'},
];

GuiManifestModel _manifest({
  List<Map<String, Object>>? navigation,
  List<Map<String, Object>>? groups,
  List<Map<String, Object>>? commands,
}) => GuiManifestModel.fromTree({
  'manifestVersion': '1',
  'cli': {'name': 'x', 'version': '1'},
  'navigation':
      navigation ??
      [
        {
          'id': 'status',
          'label': 'Status',
          'icon': 'pulse',
          'command': 'status',
        },
        {
          'id': 'workers',
          'label': 'Workers',
          'icon': 'cpu',
          'command': 'workers.list',
        },
      ],
  'groups': groups ?? _groups,
  'commands':
      commands ??
      [
        _command('status', 'Status', kind: 'info'),
        _command('workers.list', 'Workers', group: 'workers', kind: 'info'),
        _command('workers.add', 'Add Worker', group: 'workers', icon: 'plus'),
        _command('workers.old', 'Old', group: 'workers', hidden: true),
        _command('config.show', 'Show config', group: 'config', kind: 'info'),
        _command('config.init', 'Create config', group: 'config'),
        _command('config.tools.run', 'Run tool', group: 'tools'),
        _command('version', 'Version', kind: 'info', icon: 'tag'),
        _command('login', 'Sign in'),
        _command('secret', 'Secret', hidden: true),
      ],
});

/// Rows as nested labels: `'Leaf'`, or `{'Group': [children]}`.
List<Object> _describe(Iterable<SidebarEntry> entries) => [
  for (final e in entries)
    if (e.children.isEmpty) e.label else {e.label: _describe(e.children)},
];

void main() {
  test('navigation groups keep all visible children', () {
    final sidebar = buildSidebar(_manifest());
    expect(_describe(sidebar.primary), [
      'Status',
      {
        'Workers': ['Add Worker'],
      },
    ]);
    expect(sidebar.keys, isNot(contains('cmd:workers.old')));
    expect(sidebar.keys, isNot(contains('cmd:workers.list')));
  });

  test('root group section keeps all descendants together', () {
    final sidebar = buildSidebar(_manifest());
    expect(sidebar.sections.map((s) => s.label), [
      'WORKSPACE',
      'INFO',
      'ACTIONS',
    ]);
    expect(_describe(sidebar.sections.first.entries), [
      {
        'Config': [
          'Show config',
          'Create config',
          {
            'Tools': ['Run tool'],
          },
        ],
      },
    ]);
    expect(sidebar.keys.where((k) => k.startsWith('cmd:config.')).length, 3);
    expect(sidebar.pathTo('cmd:config.tools.run').map((e) => e.label), [
      'Config',
      'Tools',
      'Run tool',
    ]);
  });

  test('navigation group follows its section and keeps its main page', () {
    final sidebar = buildSidebar(
      _manifest(
        navigation: [
          {'id': 'config', 'label': 'Config', 'command': 'config.show'},
        ],
      ),
    );
    final config = sidebar.sections
        .firstWhere((s) => s.label == 'WORKSPACE')
        .entries
        .single;
    expect(config.selectKey, 'nav:config');
    expect(_describe(config.children), [
      'Create config',
      {
        'Tools': ['Run tool'],
      },
    ]);
    expect(sidebar.primary.map((e) => e.label), isNot(contains('Config')));
  });

  test('unsectioned groups stay together at the top', () {
    final sidebar = buildSidebar(
      _manifest(
        navigation: [],
        groups: [
          {'id': 'config', 'label': 'Config'},
          {
            'id': 'tools',
            'label': 'Tools',
            'parent': 'config',
            'section': 'OTHER',
          },
        ],
        commands: [
          _command(
            'config.show',
            'Show config',
            group: 'config',
            section: 'INFO',
          ),
          _command(
            'config.tools.run',
            'Run tool',
            group: 'tools',
            section: 'ACTIONS',
          ),
          _command('version', 'Version', section: 'Diagnostics'),
        ],
      ),
    );
    expect(_describe(sidebar.primary), [
      {
        'Config': [
          'Show config',
          {
            'Tools': ['Run tool'],
          },
        ],
      },
    ]);
    expect(sidebar.sections.map((s) => s.label), ['Diagnostics']);
  });

  test('arbitrary command sections follow first appearance', () {
    final sidebar = buildSidebar(
      _manifest(
        navigation: [],
        groups: [],
        commands: [
          _command('a', 'A', section: 'Diagnostics'),
          _command('b', 'B', section: 'Maintenance'),
          _command('c', 'C', kind: 'info', section: 'Diagnostics'),
          _command('d', 'D', kind: 'info', unsectioned: true),
        ],
      ),
    );
    expect(sidebar.primary.single.label, 'D');
    expect(sidebar.sections.map((s) => s.label), [
      'Diagnostics',
      'Maintenance',
    ]);
    expect(_describe(sidebar.sections.first.entries), ['A', 'C']);
  });

  test('hidden and navigation commands are not duplicated', () {
    final keys = buildSidebar(_manifest()).keys.toList();
    expect(keys, isNot(contains('cmd:secret')));
    expect(keys, isNot(contains('cmd:status')));
    expect(keys.toSet().length, keys.length);
  });
  test('filtering navigation keeps its commands available', () {
    final sidebar = buildSidebar(
      _manifest(),
      navVisible: (n) => n.id != 'workers',
    );
    expect(sidebar.keys, contains('cmd:workers.list'));
    expect(sidebar.keys, contains('cmd:workers.add'));
    expect(sidebar.keys, isNot(contains('nav:workers')));
    expect(sidebar.pathTo('cmd:workers.list').map((e) => e.label), [
      'Workers',
      'Workers',
    ]);
  });

  test('navigation not named after the group does not consume the group', () {
    final sidebar = buildSidebar(
      _manifest(
        navigation: [
          {'id': 'list', 'label': 'List', 'command': 'workers.list'},
        ],
      ),
    );
    expect(sidebar.keys, contains('cmd:workers.add'));
    expect(sidebar.keys, isNot(contains('cmd:workers.list')));
    expect(sidebar.pathTo('cmd:workers.add').map((e) => e.label), [
      'Workers',
      'Add Worker',
    ]);
  });
}

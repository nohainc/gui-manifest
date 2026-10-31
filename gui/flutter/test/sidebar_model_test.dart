import 'package:flutter_test/flutter_test.dart';
import 'package:gui_manifest_flutter/gui_manifest_flutter.dart';
import 'package:gui_manifest_flutter/src/sidebar_model.dart';

Map<String, Object> _command(
  String id,
  String title, {
  String? group,
  bool hidden = false,
}) => {
  'id': id,
  'argv': id.split('.'),
  'title': title,
  'group': ?group,
  if (hidden) 'hidden': 'true',
};

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
  if (groups != null || commands == null)
    'groups':
        groups ??
        [
          {'id': 'workers', 'label': 'Workers'},
          {'id': 'config', 'label': 'Config'},
          {'id': 'tools', 'label': 'Tools', 'parent': 'config'},
        ],
  'commands':
      commands ??
      [
        _command('status', 'Status'),
        _command('workers.list', 'Workers', group: 'workers'),
        _command('workers.add', 'Add Worker', group: 'workers'),
        _command('workers.old', 'Old', group: 'workers', hidden: true),
        _command('config.show', 'Show config', group: 'config'),
        _command('config.tools.run', 'Run tool', group: 'tools'),
        _command('version', 'Version'),
        _command('secret', 'Secret', hidden: true),
      ],
});

List<Object> _describe(Iterable<SidebarEntry> entries) => [
  for (final e in entries)
    if (e.children.isEmpty) e.label else {e.label: _describe(e.children)},
];

void main() {
  test('a group with a main action is one expandable row', () {
    final sidebar = buildSidebar(_manifest());
    expect(_describe(sidebar.primary), [
      'Status',
      {
        'Workers': ['Add Worker'],
      },
    ]);
    final workers = sidebar.primary[1];
    expect(workers.selectKey, 'nav:workers');
    expect(workers.children.single.selectKey, 'cmd:workers.add');
  });

  test('other groups become sections, then ungrouped commands', () {
    final sidebar = buildSidebar(_manifest());
    expect(_describe(sidebar.more), [
      {
        'Config': [
          'Show config',
          {
            'Tools': ['Run tool'],
          },
        ],
      },
      'Version',
    ]);
    expect(sidebar.more.first.selectKey, isNull, reason: 'header only');
  });

  test('hidden commands never appear and main actions are not repeated', () {
    final labels = buildSidebar(_manifest()).keys.toList();
    expect(labels, isNot(contains('cmd:workers.old')));
    expect(labels, isNot(contains('cmd:secret')));
    expect(labels, isNot(contains('cmd:workers.list')));
    expect(labels, isNot(contains('cmd:status')));
  });

  test('keys are in display order and pathTo leads to a page', () {
    final sidebar = buildSidebar(_manifest());
    expect(sidebar.keys.toList(), [
      'nav:status',
      'nav:workers',
      'cmd:workers.add',
      'cmd:config.show',
      'cmd:config.tools.run',
      'cmd:version',
    ]);
    expect(sidebar.pathTo('cmd:config.tools.run').map((e) => e.label), [
      'Config',
      'Tools',
      'Run tool',
    ]);
    expect(sidebar.pathTo('cmd:nope'), isEmpty);
  });

  test('a nav entry that is not its group stays a plain row', () {
    final sidebar = buildSidebar(
      _manifest(
        navigation: [
          {'id': 'list', 'label': 'List', 'command': 'workers.list'},
        ],
      ),
    );
    expect(_describe(sidebar.primary), ['List']);
    // The group still gets a section for its other commands.
    expect(
      _describe(sidebar.more),
      anyElement(
        equals({
          'Workers': ['Add Worker'],
        }),
      ),
    );
  });

  test('entries can be filtered, e.g. unregistered builtin screens', () {
    final sidebar = buildSidebar(
      _manifest(),
      navVisible: (n) => n.id != 'workers',
    );
    expect(_describe(sidebar.primary), ['Status']);
    expect(_describe(sidebar.more).first, {
      'Workers': ['Workers', 'Add Worker'],
    }, reason: 'its commands move to a section; the page is not a main action');
  });

  test('a manifest without groups keeps a flat list', () {
    final sidebar = buildSidebar(
      _manifest(
        groups: const [],
        commands: [
          _command('status', 'Status'),
          _command('workers.list', 'Workers'),
          _command('version', 'Version'),
        ],
      ),
    );
    expect(_describe(sidebar.primary), ['Status', 'Workers']);
    expect(_describe(sidebar.more), ['Version']);
  });
}

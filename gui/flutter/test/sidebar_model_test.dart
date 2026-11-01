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
}) => {
  'id': id,
  'argv': id.split('.'),
  'title': title,
  'group': ?group,
  if (hidden) 'hidden': 'true',
  'kind': ?kind,
  'icon': ?icon,
};

final _groups = [
  {'id': 'workers', 'label': 'Workers', 'icon': 'cpu'},
  {'id': 'config', 'label': 'Config', 'icon': 'sliders'},
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

  group('INFO and ACTIONS', () {
    test('commands that only read go under INFO, the rest under ACTIONS', () {
      final sidebar = buildSidebar(_manifest());
      expect(sidebar.sections.map((s) => s.label), ['INFO', 'ACTIONS']);
      expect(_describe(sidebar.sections[0].entries), [
        {
          'Config': ['Show config'],
        },
        'Version',
      ]);
      expect(_describe(sidebar.sections[1].entries), [
        {
          'Config': [
            'Create config',
            {
              'Tools': ['Run tool'],
            },
          ],
        },
        'Sign in',
      ]);
    });

    test('a group with both kinds appears in both, with distinct ids', () {
      final sidebar = buildSidebar(_manifest());
      final ids = [
        for (final s in sidebar.sections)
          for (final e in s.entries) e.id,
      ];
      expect(ids.toSet().length, ids.length);
      expect(ids, containsAll(['group:config:info', 'group:config:action']));
      expect(
        sidebar.sections[0].entries.first.selectKey,
        isNull,
        reason: 'a section header opens no page',
      );
    });

    test('a command without a kind is an action', () {
      final sidebar = buildSidebar(_manifest());
      final actions = sidebar.sections[1].keys;
      expect(actions, contains('cmd:login'));
      expect(sidebar.sections[0].keys, isNot(contains('cmd:login')));
    });

    test('a manifest that classifies nothing keeps one COMMANDS section', () {
      final sidebar = buildSidebar(
        _manifest(
          commands: [
            _command('status', 'Status'),
            _command('workers.list', 'Workers', group: 'workers'),
            _command('version', 'Version'),
            _command('config.show', 'Show config', group: 'config'),
          ],
        ),
      );
      expect(sidebar.sections.map((s) => s.label), ['COMMANDS']);
      expect(_describe(sidebar.sections.single.entries), [
        'Version',
        {
          'Config': ['Show config'],
        },
      ]);
    });

    test('an empty section is left out', () {
      final sidebar = buildSidebar(
        _manifest(
          commands: [
            _command('status', 'Status', kind: 'info'),
            _command('workers.list', 'Workers', group: 'workers'),
            _command('version', 'Version', kind: 'info'),
          ],
        ),
      );
      expect(sidebar.sections.map((s) => s.label), ['INFO']);
    });
  });

  test('every row carries the icon the manifest names for it', () {
    final sidebar = buildSidebar(_manifest());
    expect(sidebar.primary.map((e) => e.icon), ['pulse', 'cpu']);
    expect(sidebar.primary[1].children.single.icon, 'plus');
    final info = sidebar.sections[0].entries;
    expect(info.first.icon, 'sliders', reason: 'group icon');
    expect(info.last.icon, 'tag', reason: 'command icon');
    // No icon in the manifest: the row has none, so the GUI shows its default.
    expect(sidebar.sections[1].entries.last.icon, isNull);
  });

  test('hidden commands never appear and main actions are not repeated', () {
    final keys = buildSidebar(_manifest()).keys.toList();
    expect(keys, isNot(contains('cmd:workers.old')));
    expect(keys, isNot(contains('cmd:secret')));
    expect(keys, isNot(contains('cmd:workers.list')));
    expect(keys, isNot(contains('cmd:status')));
  });

  test('keys are in display order and pathTo leads to a page', () {
    final sidebar = buildSidebar(_manifest());
    expect(sidebar.keys.toList(), [
      'nav:status',
      'nav:workers',
      'cmd:workers.add',
      'cmd:config.show',
      'cmd:version',
      'cmd:config.init',
      'cmd:config.tools.run',
      'cmd:login',
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
      _describe(sidebar.sections.expand((s) => s.entries)),
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
    // Its page is no longer a main action, so it joins INFO with the rest.
    expect(
      _describe(sidebar.sections[0].entries),
      contains(
        equals({
          'Workers': ['Workers'],
        }),
      ),
    );
  });

  test('a manifest without groups keeps a flat list', () {
    final sidebar = buildSidebar(
      _manifest(
        groups: const [],
        commands: [
          _command('status', 'Status', kind: 'info'),
          _command('workers.list', 'Workers', kind: 'info'),
          _command('version', 'Version', kind: 'info'),
          _command('login', 'Sign in'),
        ],
      ),
    );
    expect(_describe(sidebar.primary), ['Status', 'Workers']);
    expect(sidebar.sections.map((s) => s.label), ['INFO', 'ACTIONS']);
    expect(_describe(sidebar.sections[0].entries), ['Version']);
    expect(_describe(sidebar.sections[1].entries), ['Sign in']);
  });
}

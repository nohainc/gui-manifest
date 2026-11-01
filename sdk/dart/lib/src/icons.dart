/// Icon names a manifest can use (`icon:` on commands, groups and sidebar
/// entries). A GUI maps each name to its own glyph and shows [command] for a
/// missing or unknown one, so a CLI never needs more than a string.
abstract final class GuiIcons {
  /// Shown when a command declares no icon, or one the GUI does not know.
  static const command = 'command';

  static const pulse = 'pulse';
  static const cpu = 'cpu';
  static const folder = 'folder';
  static const tasks = 'tasks';
  static const log = 'log';
  static const server = 'server';
  static const settings = 'settings';
  static const sliders = 'sliders';
  static const user = 'user';
  static const key = 'key';
  static const lock = 'lock';
  static const shield = 'shield';
  static const cloud = 'cloud';
  static const cloudOff = 'cloudOff';
  static const link = 'link';
  static const unlink = 'unlink';
  static const play = 'play';
  static const stop = 'stop';
  static const pause = 'pause';
  static const refresh = 'refresh';
  static const power = 'power';
  static const trash = 'trash';
  static const info = 'info';
  static const plus = 'plus';
  static const edit = 'edit';
  static const check = 'check';
  static const bug = 'bug';
  static const test = 'test';
  static const list = 'list';
  static const table = 'table';
  static const chart = 'chart';
  static const gauge = 'gauge';
  static const download = 'download';
  static const upload = 'upload';
  static const wrench = 'wrench';
  static const file = 'file';
  static const code = 'code';
  static const book = 'book';
  static const search = 'search';
  static const home = 'home';
  static const login = 'login';
  static const logout = 'logout';
  static const id = 'id';
  static const tag = 'tag';
  static const database = 'database';
  static const package = 'package';
  static const clock = 'clock';
  static const bell = 'bell';
  static const mail = 'mail';
  static const globe = 'globe';
  static const eye = 'eye';
  static const copy = 'copy';
  static const rocket = 'rocket';

  /// Every name above, for tests and tooling.
  static const all = <String>[
    command, pulse, cpu, folder, tasks, log, server, settings, sliders, user,
    key, lock, shield, cloud, cloudOff, link, unlink, play, stop, pause,
    refresh, power, trash, info, plus, edit, check, bug, test, list, table,
    chart, gauge, download, upload, wrench, file, code, book, search, home,
    login, logout, id, tag, database, package, clock, bell, mail, globe, eye,
    copy, rocket, //
  ];
}

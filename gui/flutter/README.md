# gui_manifest_flutter

Flutter desktop framework that turns any CLI answering `--gui-manifest=1`
into a sidebar + content app. Contains no product names or theme.

```dart
runApp(GuiManifestApp(
  runner: ProcessCliRunner('/path/to/cli'),
  title: 'My CLI',
  theme: myTheme,                       // host app's design system
  builtins: {'my.status': (context, runner, manifest) => MyStatusScreen()},
));
```

- Sidebar, styled like the Syntila app's Space tree (same row height 30,
  12.5px/11.5px type, 8/6px rounding, folder icon, selected/hover color): a group
  is a **Space** and its commands are its **Threads**; main actions and commands
  without a group are Spaces without Threads. A main action that is also a group
  (same id as its command's `group`) is one row: tapping it opens the page and
  shows its commands, tapping again hides them. Other groups and ungrouped
  commands sit under a COMMANDS label (hidden commands never appear).
- Footer: version, reload and **Settings**. Settings offers the Syntila text sizes
  (Default 1.0, Large 1.15, Extra large 1.3), applied to the whole shell.
- Command page: generated form (text, path, secret, enum, flag), exact
  command-line preview with secrets masked, Run/Cancel, confirmation for
  `destructive` commands, and a notice for `interactive` ones.
- Output: a Result tab (table / key-value / log from JSON, JSON Lines or Nano
  Markup) and a Raw output tab with stdout, stderr, exit code and duration.
- Navigation entries that point at a command run it on open unless it is
  destructive, interactive or needs input.
- The CLI is started directly with `Process.start` (no shell); stdin is
  closed, so prompts get EOF.

## Host styling and settings

Sidebar colors come from a `GuiSidebarTheme` theme extension (falling back to the
`ColorScheme`), so the framework carries no product colors:

```dart
theme.copyWith(extensions: [
  GuiSidebarTheme(
    backgroundColor: ..., selectedColor: ..., textColor: ...,
    labelColor: ..., borderColor: ...,
  ),
])
```

Pass `preferencesStore: ViewPreferencesStore.forApp('my-app')` to keep the text
size between launches (a per-user settings file; in memory when omitted).

`commandPages` replaces the generated page of a command id with a custom
widget (e.g. a live dashboard) while keeping the manifest as the source of
navigation. `GuiManifestShell` can be embedded in an existing `MaterialApp`.

```console
flutter test
```

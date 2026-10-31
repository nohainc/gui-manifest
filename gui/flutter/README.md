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

- Sidebar: manifest `navigation` entries (icons from `lib/src/icons.dart`),
  then "All commands" for the remaining non-hidden commands.
- Command page: generated form (text, path, secret, enum, flag), exact
  command-line preview with secrets masked, Run/Cancel, confirmation for
  `destructive` commands, and a notice for `interactive` ones.
- Output: a Result tab (table / key-value / log from JSON, JSON Lines or Nano
  Markup) and a Raw output tab with stdout, stderr, exit code and duration.
- Navigation entries that point at a command run it on open unless it is
  destructive, interactive or needs input.
- The CLI is started directly with `Process.start` (no shell); stdin is
  closed, so prompts get EOF.

`commandPages` replaces the generated page of a command id with a custom
widget (e.g. a live dashboard) while keeping the manifest as the source of
navigation. `GuiManifestShell` can be embedded in an existing `MaterialApp`.

```console
flutter test
```

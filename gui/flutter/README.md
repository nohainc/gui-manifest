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

- Sidebar, styled like the Syntila app's Space tree (row height 30, 12.5px/11.5px
  type, 8/6px rounding, selected/hover color). Every row shows the command's
  manifest `icon` (see `GuiIcons`), or a generic command icon when it has none or
  the name is unknown; never a folder. A group is a **Space** and its commands
  are its **Threads**; main actions and commands without a group are Spaces
  without Threads. A main action that is also a group (same id as its command's
  `group`) is one row: tapping it opens the page and shows its commands, tapping
  again hides them.
- Under the main actions, commands are split by their manifest `kind`: **INFO**
  (they only read and report) and **ACTIONS** (they do something; the default).
  A group with both kinds appears in both with the matching commands. A manifest
  that classifies nothing gets one COMMANDS section. Hidden commands never appear.
- Command page: title, description, then the command line as it will run
  (`$ mycli workers remove <id>`, using the CLI's name, never its install path;
  missing values show as placeholders, secrets are masked), the generated form,
  and Run/Cancel. Destructive commands ask for confirmation first.
- Results pile up: every run adds a card (newest first) showing the executed
  `$ mycli ...` line, outcome, time, and the output. Earlier results are never
  cleared by running again or opening another page (a **Clear results** button
  removes them when asked). A command keeps running if you leave its page.
- Output is written as text in the **Output format** chosen in Settings: **Nano**
  (default), JSON or YAML, with a **Table** tab for commands that declare a table,
  key/value or log view. Plain-text output is shown as printed, and the verbatim
  stdout stays one tap away. stderr and the exit code are always shown.
- Footer: version, reload and **Settings**. Settings has the Syntila text sizes
  (Default 1.0, Large 1.15, Extra large 1.3, applied to the whole shell) and the
  output format.

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

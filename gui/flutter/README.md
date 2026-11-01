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
  type, 8/6px rounding, selected/hover color). Top-level rows show their manifest
  `icon` (see `GuiIcons`), or a generic command icon when none is known. Nested
  items have no command icon; expandable groups retain their chevron. A group is a **Space** and its commands
  are its **Threads**; main actions and commands without a group are Spaces
  without Threads. A main action that is also a group (same id as its command's
  `group`) is one row: tapping it opens the page and shows its commands, tapping
  again hides them.
- Commands declare an optional `section` label. Commands without a section
  appear at the top; other commands appear under their label in first-seen
  order. A root group declares its own section and stays together with every
  descendant. A navigation group with a section also appears there, retaining
  its main page and expandable commands. Hidden commands never appear.
- Command page: title, description, then the command line as it will run
  (`$ mycli workers remove <id>`, using the CLI's name, never its install path;
  missing values show as placeholders, secrets are masked). The copy button copies
  that displayed command without the prompt. Below it are the generated form,
  and Run/Cancel. Destructive commands ask for confirmation first.
- Results pile up: every run adds a card (newest first) showing the executed
  `$ mycli ...` line, outcome, time, and the output. Earlier results are never
  cleared by running again or opening another page (a **Clear results** button
  removes them when asked). A command keeps running if you leave its page.
- Secret inputs with `stdinFlag` are sent through stdin instead of argv. Custom
  runners must implement `CliInputRunner` to run commands with such input.
- Results show stdout and stderr as returned by the CLI, together with its exit
  status. A copy button copies stdout followed by stderr for that result. The
  manifest determines the arguments passed to each command.
- Footer: version, reload and **Settings**. Settings offers Syntila text sizes
  (Default 1.0, Large 1.15, Extra large 1.3) across the whole shell.

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

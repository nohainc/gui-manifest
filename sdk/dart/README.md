# gui_manifest (Dart SDK)

Lets a Dart CLI declare its commands **once** and get, from that single
declaration:

- argument parsing and help, through `package:args`,
- the `--gui-manifest[=N]` answer (a GUI Manifest v1 Nano Markup document,
  see `spec/SPEC.md`),
- groups, so `workers list`, `workers add` … are a group the GUI can show as
  one section.

## Declare the commands

```dart
final spec = CliSpec(
  name: 'mycli',
  description: 'Manage my things',
  version: '1.0.0',
  globals: const [
    GuiParameter(name: 'json', kind: GuiParamKind.flag, type: GuiParamType.boolean),
  ],
  nodes: [
    CliCommand(
      name: 'status',
      title: 'Status',
      description: 'Show status.',
      icon: 'pulse',
      navigation: true,            // adds a sidebar entry
      output: const GuiOutput(format: GuiFormat.json, view: GuiView.keyValue),
      handler: (run) {
        run.out.writeln(run.globalFlag('json') ? '{"ok": true}' : 'ok');
        return 0;                  // exit code
      },
    ),
    CliGroup(
      name: 'workers',
      title: 'Workers',
      description: 'Manage workers.',
      icon: 'cpu',
      navigation: true,
      defaultCommand: 'list',      // `mycli workers` runs `mycli workers list`
      children: [
        CliCommand(
          name: 'remove',
          title: 'Remove worker',
          description: 'Remove a worker.',
          destructive: true,
          parameters: const [
            GuiParameter(
              name: 'id',
              kind: GuiParamKind.positional,
              type: GuiParamType.string,
              required: true,
            ),
          ],
          handler: (run) => removeWorker(run.positional('id')!),
        ),
        // ...
      ],
    ),
  ],
);

Future<void> main(List<String> args) async {
  exitCode = await runCli(spec, args, out: stdout, err: stderr);
}
```

`runCli` answers `--gui-manifest[=N]` first (version negotiation; exit 2 for
unsupported versions) and otherwise runs the matching handler.

## What the spec gives you

| Declared | Used for |
| --- | --- |
| `CliCommand` / `CliGroup` tree | nested `package:args` commands, help, aliases, manifest commands and groups |
| `parameters` (option, flag, positional) | `addOption` / `addFlag` / `addMultiOption`, positional count checks, GUI forms. Types `path`, `secret`, `enum` and `integer` reach the GUI |
| `globals` | options accepted before, between or after the command words (`--json`) |
| `defaultCommand` | a group invoked alone runs that child |
| `visible` | hides a command from help at run time (it still runs and stays in the manifest) |
| `output`, `destructive`, `interactive`, `longRunning`, `requires`, `icon`, `navigation` | GUI hints only |
| `jsonArgs` | arguments the GUI appends to JSON-format commands (default `--json`) |
| `usageExitCode` | exit code for usage errors (default 64) |

Handlers get a `CliInvocation`: `positional(name)`, `positionalList(name)`,
`option(name)`, `flag(name)`, `multiOption(name)`, `globalFlag(name)`,
`globalOption(name)`, `path`, `out`, `err`.

A `CliSpec` is validated when it is created and throws `CliSpecError` for
duplicate names, required positionals after optional ones, enums without
values, secrets with defaults, sidebar groups without a default command and
similar mistakes, so a test that constructs the spec checks it.

`manifestFromSpec(spec)` returns the manifest model if you need it without
running the CLI; `validateManifest` / `validateManifestSource` check any
decoded document against the spec.

## CLIs that already use `package:args`

Mix `GuiDescribed` into a `Command` and return a `GuiMeta`, then call
`buildManifest(runner, cli: info, navigation: nav)`. This reads the existing
command tree; groups are not available this way.

See `example/example_cli.dart`; its manifest is
`conformance/fixtures/minimal.nano`.

```console
dart test
dart run example/example_cli.dart --gui-manifest=1
dart run example/example_cli.dart workers remove w1
```

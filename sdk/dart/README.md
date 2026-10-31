# gui_manifest (Dart SDK)

Lets a `package:args` `CommandRunner` CLI answer `--gui-manifest=N` with a
GUI Manifest v1 Nano Markup document (see `spec/SPEC.md`).

## Usage

1. Mix `GuiDescribed` into commands and return a `GuiMeta` (title, output
   view, extra argv such as `--json`, flags like `destructive`, positional
   parameters, secret/path options). Commands without it get defaults.
2. Handle the request before running the normal CLI:

```dart
switch (GuiManifestRequest.parse(args)) {
  case GuiManifestAccepted():
    stdout.write(encodeManifest(buildManifest(runner, cli: info, navigation: nav)));
  case GuiManifestRejected(:final message):
    stderr.writeln(message);
    exitCode = 2;
  case null:
    await runner.run(args);
}
```

`buildManifest` walks the command tree: each leaf becomes a command with id
`parent.child` (kebab/snake names become camelCase segments), options become
parameters (flags → boolean, `allowed` → enum, `mandatory` → required,
`hide` and `help` skipped). `validateManifest` / `validateManifestSource`
check a decoded document against the spec.

See `example/example_cli.dart`. It produces `conformance/fixtures/minimal.nano`.

```console
dart test
dart run example/example_cli.dart --gui-manifest=1
```

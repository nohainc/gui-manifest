# gui-manifest

A language-neutral protocol that lets a CLI describe itself to a GUI, plus a
reference GUI framework and CLI-side SDKs.

A CLI that supports the protocol answers:

```
<cli> --gui-manifest=1
```

with a Nano Markup manifest on stdout. A GUI built on this framework calls that flag at
startup and builds its sidebar, screens, forms and result views dynamically.

## Layout

| Path | Purpose |
| --- | --- |
| `spec/` | Source of truth: specification, schema for the decoded tree, example manifests (`.nano`) |
| `gui/flutter/` | Flutter GUI framework: sidebar, generated command pages, result views |
| `sdk/dart/` | Dart SDK: build, encode and validate manifests for `package:args` CLIs |
| `sdk/python/` | Python SDK (planned) |
| `tools/validator/` | CLI that validates manifest files or a live CLI (`--cli`) |
| `conformance/` | Shared fixtures every SDK must pass |

## Principles

- The protocol is the product; the GUI and SDKs implement it.
- The GUI framework contains no product names and no product theme; apps inject
  their theme, CLI binding and custom screens.
- The building-block set is small and fixed. Custom screens are registered by the
  host app, never described in the manifest.

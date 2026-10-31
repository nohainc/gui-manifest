# GUI Manifest Specification — v1 (draft)

Status: draft. Outline only; sections marked TODO are to be filled in.

## 1. Discovery

- Request: `<cli> --gui-manifest=<N>` where `N` is the highest version the GUI supports.
- Response: the CLI writes one JSON document to stdout, using the highest
  version `<= N` it supports, and exits `0`.
- The call MUST have no side effects, MUST work offline, without
  authentication and without any background service running.
- Non-zero exit or non-JSON stdout means "unsupported". The GUI MUST NOT
  retry with other arguments.
- The flag SHOULD be hidden from regular `--help`.

## 2. Top-level document

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `manifestVersion` | integer | yes | Version actually returned |
| `cli` | object | yes | `name`, `version`, `displayName`, `description` |
| `navigation` | array | yes | Sidebar entries (see §3) |
| `commands` | object | yes | Map of command id → command (see §4) |
| `screens` | object | no | Map of screen id → screen (see §5) |

Unknown fields MUST be ignored by the GUI (forward compatibility).

## 3. Navigation

Each entry: `id`, `label`, `icon`, `group?`, and exactly one target:
`command` (command id), `screen` (screen id) or `builtin` (a host-registered
custom screen id such as `workspace.status`). Unknown `builtin` ids fall back
to the target's generated screen or are hidden.

## 4. Commands

| Field | Type | Notes |
| --- | --- | --- |
| `argv` | string[] | Fixed argument prefix, e.g. `["workers", "list"]` |
| `title`, `description` | string | |
| `parameters` | Parameter[] | See §4.1 |
| `output` | Output | See §4.2 |
| `destructive` | boolean | GUI asks for confirmation |
| `interactive` | boolean | Needs non-GUI interaction (browser hand-off etc.) |
| `longRunning` | boolean | GUI offers cancel |
| `requires` | string[] | Preconditions, e.g. `signedIn`, `serviceRunning` |
| `hidden` | boolean | Not shown in the generic Commands section |

### 4.1 Parameters

`name`, `kind` (`option` \| `flag` \| `positional`), `type` (`string` \|
`integer` \| `number` \| `boolean` \| `enum` \| `path` \| `secret`),
`required`, `default`, `values` (for `enum`), `multiple`, `label`, `help`.
`secret` values MUST NOT be displayed, logged or stored in history.

### 4.2 Output

`format`: `text` \| `json` \| `jsonLines`. `view`: one of the building blocks
in §6. Optional `bind` maps JSON paths to view fields (TODO).

## 5. Screens

A screen composes blocks bound to commands, e.g. a table fed by
`workers.list` with row actions `workers.stop` passing `{id}`. TODO: binding
and argument templating rules.

## 6. Building blocks (fixed set)

`form`, `table`, `keyValue`, `card`, `log`, `confirm`, `raw`.
Adding a block requires a new manifest version.

## 7. Execution rules

- The GUI executes the CLI directly, never through a shell.
- Only argv built from manifest commands and validated parameters is allowed.
- The raw stdout, stderr, exit code and the exact command line are always
  available to the user.

## 8. Versioning

- Additive, ignorable fields: same major version.
- Anything else: new `manifestVersion`. Schemas are kept per version in
  `spec/schema/`.

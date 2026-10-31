# GUI Manifest Specification — v1 (draft)

Status: draft. Outline only; sections marked TODO are to be filled in.

## 1. Discovery

- Request: `<cli> --gui-manifest=<N>` where `N` is the highest version the GUI supports.
- Response: the CLI writes one [Nano Markup 1.0](https://github.com/nohainc/nanomarkup.spec)
  document (UTF-8) to stdout, using the highest
  version `<= N` it supports, and exits `0`.
- The call MUST have no side effects, MUST work offline, without
  authentication and without any background service running.
- Non-zero exit or stdout that is not a valid Nano Markup document means "unsupported". The GUI MUST NOT
  retry with other arguments.
- The flag SHOULD be hidden from regular `--help`.

## 2. Encoding rules

Nano Markup has three value kinds: string, mapping and sequence.

- **Order.** Sequences are ordered; mapping key order is *not* part of the data
  model and MUST NOT carry meaning. Everything whose order affects the GUI
  (navigation, commands, parameters, screens, argv) is therefore a sequence.
  Items that need to be referenced carry an `id` field.
- **Scalars are strings.** The decoder never infers types; this spec defines
  how fields are interpreted:
  - *boolean*: exactly `true` or `false`; an absent field is `false`.
  - *integer*: ASCII digits only, no sign, no leading zeros (except `0`).
  - *number*: decimal per JSON number grammar.
  - *id*: alphanumeric segments starting with a lowercase letter, separated
    by `.`, e.g. `workers.list`, `workers.longRunning`.
  Any other value for a typed field makes the manifest invalid.
- **Validation.** `spec/schema/v1.json` is a JSON Schema applied to the
  *decoded* tree (mappings → objects, sequences → arrays, strings → strings).
- **Ids** MUST be unique within `navigation`, `commands` and `screens`.

## 3. Top-level document

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `manifestVersion` | integer | yes | Version actually returned |
| `cli` | mapping | yes | `name`, `version`, `displayName`, `description` |
| `navigation` | sequence | yes | Sidebar entries in display order (see §4) |
| `groups` | sequence | no | Command groups (see §4.1) |
| `commands` | sequence | yes | Commands in display order (see §5) |
| `screens` | sequence | no | Screens, each with an `id` (see §6) |

Unknown mapping keys MUST be ignored by the GUI (forward compatibility).

## 4. Navigation

Each entry: `id`, `label`, `icon`, `group?`, and exactly one target:
`command` (command id), `screen` (screen id) or `builtin` (a host-registered
custom screen id such as `workspace.status`). Unknown `builtin` ids fall back
to the target's generated screen or are hidden.

### 4.1 Groups

A group names a set of related commands (e.g. `workers` containing
`workers.list`, `workers.add`). Fields: `id`, `label`, `icon?`,
`description?`, `parent?` (id of an enclosing group). A command joins a group
with its `group` field. A GUI may show groups as sidebar sections; a
navigation entry for a group targets one command (normally its default
command). Every `group` and `parent` reference MUST name a declared group.

## 5. Commands

| Field | Type | Notes |
| --- | --- | --- |
| `id` | id | Unique command id |
| `group` | id | Optional; the group this command belongs to |
| `argv` | sequence of strings | Fixed argument prefix, e.g. `["workers", "list"]` |
| `title`, `description` | string | |
| `parameters` | Parameter[] | See §5.1 |
| `output` | Output | See §5.2 |
| `destructive` | boolean | GUI asks for confirmation |
| `interactive` | boolean | Needs non-GUI interaction (browser hand-off etc.) |
| `longRunning` | boolean | GUI offers cancel |
| `requires` | string[] | Preconditions, e.g. `signedIn`, `serviceRunning` |
| `hidden` | boolean | Not shown in the generic Commands section |

### 5.1 Parameters

`name`, `kind` (`option` \| `flag` \| `positional`), `type` (`string` \|
`integer` \| `number` \| `boolean` \| `enum` \| `path` \| `secret`),
`required` (boolean), `default` (string, interpreted per `type`), `values` (for `enum`), `multiple`, `label`, `help`.
`secret` values MUST NOT be displayed, logged or stored in history.

### 5.2 Output

`format` describes the command's *result* (not the manifest): `text` \|
`json` \| `jsonLines` \| `nano`. `view`: one of the building blocks
in §7. Optional `bind` maps paths in the decoded result to view fields (TODO).

## 6. Screens

A screen composes blocks bound to commands, e.g. a table fed by
`workers.list` with row actions `workers.stop` passing `{id}`. TODO: binding
and argument templating rules.

## 7. Building blocks (fixed set)

`form`, `table`, `keyValue`, `card`, `log`, `confirm`, `raw`.
Adding a block requires a new manifest version.

## 8. Execution rules

- The GUI executes the CLI directly, never through a shell.
- Only argv built from manifest commands and validated parameters is allowed.
- The raw stdout, stderr, exit code and the exact command line are always
  available to the user.

## 9. Versioning

- Additive, ignorable fields: same major version.
- Anything else: new `manifestVersion`. Schemas are kept per version in
  `spec/schema/`.

# Validator

```console
dart run bin/validate.dart spec/examples/minimal.nano   # files, or "-" for stdin
dart run bin/validate.dart --cli /path/to/cli           # runs <cli> --gui-manifest=1
```

Exit status: `0` valid, `1` invalid or unsupported, `2` usage or I/O error.
Issues are printed as `<source>: <path>: <message>`, e.g.
`cli: $.commands[0].destructive: "yes" is not one of true, false`.

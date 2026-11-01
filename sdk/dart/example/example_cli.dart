import 'dart:io';

import 'package:gui_manifest/gui_manifest.dart';

/// A small CLI declared once as a [CliSpec]. The same declaration drives
/// argument parsing, help, and `--gui-manifest`; its manifest is
/// `conformance/fixtures/minimal.nano`.
CliSpec createSpec() => CliSpec(
      name: 'example',
      description: 'Example CLI',
      displayName: 'Example CLI',
      version: '0.1.0',
      globals: const [
        GuiParameter(
          name: 'json',
          kind: GuiParamKind.flag,
          type: GuiParamType.boolean,
          help: 'Print machine-readable JSON.',
        ),
      ],
      nodes: [
        CliCommand(
          name: 'status',
          title: 'Status',
          description: 'Show status.',
          icon: GuiIcons.pulse,
          navigation: true,
          kind: GuiCommandKind.info,
          output:
              const GuiOutput(format: GuiFormat.json, view: GuiView.keyValue),
          handler: (run) {
            run.out.writeln(
              run.globalFlag('json') ? '{"state": "running"}' : 'running',
            );
            return 0;
          },
        ),
        CliGroup(
          name: 'workers',
          title: 'Workers',
          description: 'Manage workers.',
          icon: GuiIcons.cpu,
          navigation: true,
          defaultCommand: 'list',
          children: [
            CliCommand(
              name: 'list',
              title: 'List workers',
              description: 'List workers.',
              icon: GuiIcons.list,
              kind: GuiCommandKind.info,
              output:
                  const GuiOutput(format: GuiFormat.json, view: GuiView.table),
              handler: (run) {
                run.out.writeln(run.globalFlag('json') ? '[]' : 'No workers.');
                return 0;
              },
            ),
            CliCommand(
              name: 'remove',
              title: 'Remove worker',
              description: 'Remove worker.',
              icon: GuiIcons.trash,
              destructive: true,
              parameters: const [
                GuiParameter(
                  name: 'id',
                  kind: GuiParamKind.positional,
                  type: GuiParamType.string,
                  required: true,
                  label: 'Worker ID',
                ),
              ],
              handler: (run) {
                run.out.writeln('removed ${run.positional('id')}');
                return 0;
              },
            ),
          ],
        ),
      ],
    );

Future<void> main(List<String> args) async {
  exitCode = await runCli(createSpec(), args, out: stdout, err: stderr);
}

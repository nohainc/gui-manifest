import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gui_manifest/gui_manifest.dart';

class StatusCommand extends Command<void> with GuiDescribed<void> {
  @override
  final name = 'status';
  @override
  final description = 'Show status.';
  @override
  final gui = const GuiMeta(
    title: 'Status',
    extraArgv: ['--json'],
    output: GuiOutput(format: GuiFormat.json, view: GuiView.keyValue),
  );

  @override
  void run() => print('{"state": "running"}');
}

class WorkersCommand extends Command<void> {
  WorkersCommand() {
    addSubcommand(WorkersListCommand());
    addSubcommand(WorkersRemoveCommand());
  }

  @override
  final name = 'workers';
  @override
  final description = 'Manage workers.';
}

class WorkersListCommand extends Command<void> with GuiDescribed<void> {
  @override
  final name = 'list';
  @override
  final description = 'List workers.';
  @override
  final gui = const GuiMeta(
    title: 'List workers',
    extraArgv: ['--json'],
    output: GuiOutput(format: GuiFormat.json, view: GuiView.table),
  );

  @override
  void run() => print('[]');
}

class WorkersRemoveCommand extends Command<void> with GuiDescribed<void> {
  @override
  final name = 'remove';
  @override
  final description = 'Remove worker.';
  @override
  final gui = const GuiMeta(
    title: 'Remove worker',
    destructive: true,
    positionals: [
      GuiParameter(
        name: 'id',
        kind: GuiParamKind.positional,
        type: GuiParamType.string,
        required: true,
        label: 'Worker ID',
      ),
    ],
  );

  @override
  void run() => print('removed ${argResults!.rest.join(' ')}');
}

CommandRunner<void> createRunner() =>
    CommandRunner<void>('example', 'Example CLI')
      ..addCommand(StatusCommand())
      ..addCommand(WorkersCommand());

GuiManifest createManifest(CommandRunner<void> runner) => buildManifest(
  runner,
  cli: const GuiCliInfo(
    name: 'example',
    version: '0.1.0',
    displayName: 'Example CLI',
  ),
  navigation: const [
    GuiNavItem.command('status', 'Status', 'status', icon: 'pulse'),
    GuiNavItem.command('workers', 'Workers', 'workers.list', icon: 'cpu'),
  ],
);

Future<void> main(List<String> args) async {
  final runner = createRunner();

  switch (GuiManifestRequest.parse(args)) {
    case GuiManifestAccepted():
      stdout.write(encodeManifest(createManifest(runner)));
      return;
    case GuiManifestRejected(:final message):
      stderr.writeln(message);
      exitCode = 2;
      return;
    case null:
      await runner.run(args);
  }
}

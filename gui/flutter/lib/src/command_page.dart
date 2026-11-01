import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cli_runner.dart';
import 'manifest.dart';
import 'result_card.dart';
import 'result_history.dart';

/// Generated page for one command: description, the command line, the
/// parameter form, Run/Cancel and every result so far.
///
/// Results are kept in [history], so running again or opening another page
/// never clears an earlier result.
class CommandPage extends StatefulWidget {
  const CommandPage({
    super.key,
    required this.command,
    required this.runner,
    required this.programName,
    required this.history,
    this.autoRun = false,
  });

  final CommandSpec command;
  final CliRunner runner;

  /// The CLI's name, shown in command lines (never its install path).
  final String programName;
  final ResultHistory history;

  /// Runs once on first open when the command needs no input and is safe.
  final bool autoRun;

  @override
  State<CommandPage> createState() => _CommandPageState();
}

class _CommandPageState extends State<CommandPage> {
  final _values = <String, String>{};
  final _controllers = <String, TextEditingController>{};

  CommandSpec get _command => widget.command;

  @override
  void initState() {
    super.initState();
    for (final p in _command.parameters) {
      final initial = p.defaultValue ?? '';
      _values[p.name] = initial;
      if (p.kind != 'flag' && p.type != 'enum') {
        _controllers[p.name] = TextEditingController(text: initial)
          ..addListener(
            () => setState(() => _values[p.name] = _controllers[p.name]!.text),
          );
      }
    }
    final safe =
        !_command.destructive &&
        !_command.interactive &&
        !_command.parameters.any((p) => p.required);
    if (widget.autoRun &&
        safe &&
        widget.history.resultsOf(_command.id).isEmpty &&
        !widget.history.isRunning(_command.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<String>? _args() {
    try {
      return _command.buildArgs(_values);
    } on ArgumentError {
      return null;
    }
  }

  Future<void> _run() async {
    final args = _args();
    if (args == null || widget.history.isRunning(_command.id)) return;
    if (_command.destructive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${_command.title}?'),
          content: Text(_command.description ?? 'This cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_command.title),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final input = _command.parameters
        .where(
          (p) =>
              p.stdinFlag != null && (_values[p.name] ?? '').trim().isNotEmpty,
        )
        .firstOrNull;
    final runner = widget.runner;
    if (input != null && runner is! CliInputRunner) return;
    final run = input == null
        ? runner.start(args)
        : (runner as CliInputRunner).startWithInput(
            args,
            _values[input.name] ?? '',
          );
    await widget.history.track(_command.id, run);
  }

  Widget _field(CommandParameter p) {
    if (p.kind == 'flag') {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(p.displayLabel),
        subtitle: p.help == null ? null : Text(p.help!),
        value: _values[p.name] == 'true',
        onChanged: (v) =>
            setState(() => _values[p.name] = v == true ? 'true' : ''),
      );
    }
    final decoration = InputDecoration(
      labelText: p.required ? '${p.displayLabel} *' : p.displayLabel,
      helperText: p.help,
      border: const OutlineInputBorder(),
    );
    if (p.type == 'enum') {
      return DropdownButtonFormField<String>(
        initialValue: (_values[p.name] ?? '').isEmpty ? null : _values[p.name],
        decoration: decoration,
        items: [
          if (!p.required) const DropdownMenuItem(value: '', child: Text('—')),
          for (final v in p.values) DropdownMenuItem(value: v, child: Text(v)),
        ],
        onChanged: (v) => setState(() => _values[p.name] = v ?? ''),
      );
    }
    return TextField(
      controller: _controllers[p.name],
      obscureText: p.isSecret,
      enableSuggestions: !p.isSecret,
      autocorrect: false,
      keyboardType: p.type == 'integer' || p.type == 'number'
          ? TextInputType.number
          : TextInputType.text,
      decoration: decoration,
      onSubmitted: (_) => _run(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace');
    return ListenableBuilder(
      listenable: widget.history,
      builder: (context, _) {
        final running = widget.history.isRunning(_command.id);
        final results = widget.history.resultsOf(_command.id);
        final requiresInput = _command.parameters.any(
          (p) =>
              p.stdinFlag != null && (_values[p.name] ?? '').trim().isNotEmpty,
        );
        final canRun =
            _args() != null &&
            !running &&
            (!requiresInput || widget.runner is CliInputRunner);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(_command.title, style: theme.textTheme.headlineSmall),
            if (_command.description != null) ...[
              const SizedBox(height: 4),
              Text(
                _command.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            // The command line follows the description and updates as the
            // form is filled in. Results repeat the executed line.
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '\$ ',
                          style: TextStyle(color: theme.colorScheme.primary),
                        ),
                        TextSpan(
                          text: _command.preview(
                            _values,
                            program: widget.programName,
                          ),
                        ),
                      ],
                    ),
                    key: const ValueKey('command-line'),
                    style: mono,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy command',
                  icon: const Icon(Icons.content_copy_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Clipboard.setData(
                    ClipboardData(
                      text: _command.preview(
                        _values,
                        program: widget.programName,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_command.interactive) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.keyboard_outlined),
                  title: const Text('This command may ask for input'),
                  subtitle: Text(
                    'Run it in a terminal if it waits for a prompt: '
                    '${widget.programName} ${_command.argv.join(' ')}',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            for (final p in _command.parameters) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: _field(p),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                FilledButton.icon(
                  style: _command.destructive
                      ? FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        )
                      : null,
                  onPressed: canRun ? _run : null,
                  icon: running
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(running ? 'Running…' : 'Run'),
                ),
                if (running) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => widget.history.cancel(_command.id),
                    child: const Text('Cancel'),
                  ),
                ],
                const Spacer(),
                if (results.isNotEmpty)
                  TextButton(
                    onPressed: () => widget.history.clear(_command.id),
                    child: const Text('Clear results'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            for (final result in results)
              ResultCard(
                key: ObjectKey(result),
                command: _command,
                result: result,
                program: widget.programName,
              ),
          ],
        );
      },
    );
  }
}

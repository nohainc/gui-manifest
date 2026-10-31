import 'package:flutter/material.dart';

import 'cli_runner.dart';
import 'manifest.dart';
import 'output_view.dart';

/// Generated page for one command: description, parameter form, command line
/// preview, run/cancel and the result.
class CommandPage extends StatefulWidget {
  const CommandPage({
    super.key,
    required this.command,
    required this.runner,
    this.autoRun = false,
  });

  final CommandSpec command;
  final CliRunner runner;

  /// Runs immediately when the command needs no input and is safe.
  final bool autoRun;

  @override
  State<CommandPage> createState() => _CommandPageState();
}

class _CommandPageState extends State<CommandPage> {
  final _values = <String, String>{};
  final _controllers = <String, TextEditingController>{};
  CliRun? _running;
  CliResult? _result;
  String? _error;

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
    if (widget.autoRun && safe) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _running?.cancel();
    super.dispose();
  }

  List<String>? _args() {
    try {
      return _command.buildArgs(_values);
    } on ArgumentError {
      return null;
    }
  }

  /// Preview with secrets masked.
  String _preview() {
    final masked = {
      for (final p in _command.parameters)
        p.name: p.isSecret && (_values[p.name] ?? '').isNotEmpty
            ? '••••'
            : _values[p.name] ?? '',
    };
    try {
      return [
        widget.runner.executable,
        ..._command.buildArgs(masked),
      ].join(' ');
    } on ArgumentError catch (e) {
      return '${[widget.runner.executable, ..._command.argv].join(' ')} '
          '… (${e.message})';
    }
  }

  Future<void> _run() async {
    final args = _args();
    if (args == null || _running != null) return;
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
    final run = widget.runner.start(args);
    setState(() {
      _running = run;
      _error = null;
    });
    final result = await run.result;
    if (!mounted) return;
    setState(() {
      _running = null;
      _result = result;
    });
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
    final running = _running != null;
    final canRun = _args() != null && !running;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          if (_command.interactive) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.keyboard_outlined),
                title: const Text('This command may ask for input'),
                subtitle: Text(
                  'Run it in a terminal if it waits for a '
                  'prompt: ${_command.argv.join(' ')}',
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
                  onPressed: () => _running?.cancel(),
                  child: const Text('Cancel'),
                ),
              ],
              const SizedBox(width: 16),
              Expanded(
                child: SelectableText(
                  _preview(),
                  maxLines: 1,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          if (_error != null)
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 16),
          Expanded(
            child: _result == null
                ? const SizedBox.shrink()
                : OutputView(
                    key: ObjectKey(_result),
                    command: _command,
                    result: _result!,
                    executable: widget.runner.executable,
                  ),
          ),
        ],
      ),
    );
  }
}

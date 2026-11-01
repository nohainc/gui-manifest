import 'package:flutter/material.dart';

import 'cli_runner.dart';
import 'formatted_view.dart';
import 'manifest.dart';
import 'output_format.dart';

/// One command result: the executed command line (`$ syntila status --json`),
/// the outcome, and the output.
///
/// Structured output is shown first as text in the chosen
/// [OutputFormatOption] (Nano by default) and, for commands with a table,
/// key/value or log view, also as a formatted view. The verbatim stdout stays
/// one tap away. Plain-text output is shown as it was printed.
class ResultCard extends StatefulWidget {
  const ResultCard({
    super.key,
    required this.command,
    required this.result,
    required this.program,
    required this.format,
  });

  final CommandSpec command;
  final CliResult result;

  /// The CLI's name, shown in the command line instead of its install path.
  final String program;
  final OutputFormatOption format;

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> {
  bool _formatted = false;
  bool _original = false;

  static const _maxBodyHeight = 360.0;

  String _clock(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final data = parseOutput(result.stdout, widget.command.format);
    final canFormat = data != null && widget.command.view != 'raw';
    final showFormatted = canFormat && _formatted;
    final status = result.cancelled
        ? 'Cancelled'
        : result.ok
        ? 'Succeeded'
        : 'Failed (exit ${result.exitCode})';
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');

    final String text;
    if (data == null || _original) {
      text = result.stdout.isEmpty ? '(no output)' : result.stdout.trimRight();
    } else {
      text = renderData(data, widget.format);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  result.ok ? Icons.check_circle_outline : Icons.error_outline,
                  color: result.ok
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$status · ${result.duration.inMilliseconds} ms · '
                    '${_clock(result.finishedAt)}',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                if (canFormat)
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(widget.format.label),
                      ),
                      const ButtonSegment(value: true, label: Text('Table')),
                    ],
                    selected: {_formatted},
                    onSelectionChanged: (s) =>
                        setState(() => _formatted = s.first),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              '\$ ${[widget.program, ...result.args].join(' ')}',
              style: mono,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _maxBodyHeight),
              child: showFormatted
                  ? SingleChildScrollView(
                      child: FormattedView(
                        value: data,
                        view: widget.command.view,
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        child: SelectableText(text, style: mono),
                      ),
                    ),
            ),
            if (result.stderr.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                result.stderr.trimRight(),
                style: mono?.copyWith(color: theme.colorScheme.error),
              ),
            ],
            if (data != null && !showFormatted)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _original = !_original),
                  child: Text(
                    _original
                        ? 'Show as ${widget.format.label}'
                        : 'Show original output',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

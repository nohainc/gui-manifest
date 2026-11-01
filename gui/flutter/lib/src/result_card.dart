import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cli_runner.dart';
import 'manifest.dart';

// Expand terminal tab stops for display; copying retains the original output.
String expandOutputTabs(String text) {
  final result = StringBuffer();
  var column = 0;
  for (final rune in text.runes) {
    if (rune == 9) {
      final spaces = 8 - column % 8;
      result.write(' ' * spaces);
      column += spaces;
    } else {
      result.writeCharCode(rune);
      column = rune == 10 || rune == 13 ? 0 : column + 1;
    }
  }
  return result.toString();
}

/// Shows the executed command and its unmodified output.
class ResultCard extends StatefulWidget {
  const ResultCard({
    super.key,
    required this.command,
    required this.result,
    required this.program,
  });

  final CommandSpec command;
  final CliResult result;

  /// The CLI's name, shown in the command line instead of its install path.
  final String program;

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> {
  static const _maxBodyHeight = 360.0;

  String _clock(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = widget.result;
    final status = result.cancelled
        ? 'Cancelled'
        : result.ok
        ? 'Succeeded'
        : 'Failed (exit ${result.exitCode})';
    final fontFamily = switch (theme.platform) {
      TargetPlatform.macOS || TargetPlatform.iOS => 'Menlo',
      TargetPlatform.windows => 'Consolas',
      TargetPlatform.linux => 'DejaVu Sans Mono',
      TargetPlatform.android || TargetPlatform.fuchsia => 'monospace',
    };
    final mono = (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
      fontFamily: fontFamily,
      fontFamilyFallback: const ['monospace'],
    );

    final text = result.stdout.isEmpty ? '(no output)' : result.stdout;

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
                IconButton(
                  tooltip: 'Copy output',
                  icon: const Icon(Icons.content_copy_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: result.stdout.isEmpty && result.stderr.isEmpty
                      ? null
                      : () => Clipboard.setData(
                          ClipboardData(text: result.stdout + result.stderr),
                        ),
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
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: SelectableText(expandOutputTabs(text), style: mono),
                ),
              ),
            ),
            if (result.stderr.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectableText(
                expandOutputTabs(result.stderr),
                style: mono?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

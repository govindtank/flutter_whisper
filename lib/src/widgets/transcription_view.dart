part of 'package:flutter_whisper/flutter_whisper.dart';

/// A Material 3 viewer widget for displaying transcriptions, timestamps, and export actions.
class TranscriptionView extends StatelessWidget {
  /// The transcription result to display.
  final TranscriptionResult result;

  /// Optional callback when a segment timestamp chip is tapped.
  final void Function(TranscriptionSegment)? onSegmentTap;

  /// Whether to show the header containing language, duration, and action buttons.
  final bool showHeader;

  /// Whether to render word-level timestamp pills under each segment.
  final bool showWordTimestamps;

  /// Optional background card color.
  final Color? cardColor;

  const TranscriptionView({
    super.key,
    required this.result,
    this.onSegmentTap,
    this.showHeader = true,
    this.showWordTimestamps = true,
    this.cardColor,
  });

  String _formatTime(double seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds.toInt() % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor ??
                  theme.colorScheme.surfaceContainerHighest.withAlpha(128),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Chip(
                  label: Text('Lang: ${result.language.toUpperCase()}'),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                if (result.duration > 0)
                  Chip(
                    label: Text('${result.duration.toStringAsFixed(1)}s'),
                    visualDensity: VisualDensity.compact,
                  ),
                const SizedBox(width: 8),
                Chip(
                  label: Text('${result.wordCount} words'),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy text',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: result.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Copied transcript to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (result.segments.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              result.text.isNotEmpty
                  ? result.text
                  : 'No transcription available.',
              style: theme.textTheme.bodyLarge,
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: result.segments.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final segment = result.segments[index];
              return Card(
                elevation: 0,
                color: cardColor ??
                    theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () => onSegmentTap?.call(segment),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_formatTime(segment.start)} - ${_formatTime(segment.end)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 14),
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Copy segment',
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: segment.text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Segment copied')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        segment.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      if (showWordTimestamps &&
                          segment.words != null &&
                          segment.words!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: segment.words!.map((w) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color:
                                      theme.colorScheme.outline.withAlpha(50),
                                ),
                              ),
                              child: Text(
                                '${w.word} (${w.start.toStringAsFixed(1)}s)',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

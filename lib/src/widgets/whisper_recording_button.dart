part of 'package:flutter_whisper/flutter_whisper.dart';

/// A drop-in animated recording button with pulsing ripples and duration counter.
class WhisperRecordingButton extends StatefulWidget {
  /// Whether recording is actively in progress.
  final bool isRecording;

  /// Triggered when the user taps to start recording.
  final VoidCallback? onStart;

  /// Triggered when the user taps to stop recording.
  final VoidCallback? onStop;

  /// Active recording duration in seconds.
  final int recordSeconds;

  /// Primary color for the recording button and glowing ripples.
  final Color activeColor;

  /// Inactive background color.
  final Color idleColor;

  /// Button radius in logical pixels.
  final double size;

  const WhisperRecordingButton({
    super.key,
    required this.isRecording,
    this.onStart,
    this.onStop,
    this.recordSeconds = 0,
    this.activeColor = Colors.redAccent,
    this.idleColor = const Color(0xFF2196F3),
    this.size = 64.0,
  });

  @override
  State<WhisperRecordingButton> createState() => _WhisperRecordingButtonState();
}

class _WhisperRecordingButtonState extends State<WhisperRecordingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    if (widget.isRecording) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant WhisperRecordingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _animController.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _animController.stop();
      _animController.reset();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            if (widget.isRecording) {
              widget.onStop?.call();
            } else {
              widget.onStart?.call();
            }
          },
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.isRecording)
                    Container(
                      width: widget.size * _pulseAnimation.value,
                      height: widget.size * _pulseAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.activeColor.withAlpha(60),
                      ),
                    ),
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isRecording
                          ? widget.activeColor
                          : widget.idleColor,
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isRecording
                                  ? widget.activeColor
                                  : widget.idleColor)
                              .withAlpha(100),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.isRecording ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: widget.size * 0.45,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (widget.isRecording) ...[
          const SizedBox(height: 8),
          Text(
            _formatDuration(widget.recordSeconds),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.activeColor,
            ),
          ),
        ],
      ],
    );
  }
}

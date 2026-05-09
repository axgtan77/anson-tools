import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RestTimerBar extends StatefulWidget {
  /// When non-null, the timer counts down to this moment.
  final DateTime? endsAt;
  final String exerciseName;
  final VoidCallback onSkip;
  final VoidCallback onAddTime;

  const RestTimerBar({
    super.key,
    required this.endsAt,
    required this.exerciseName,
    required this.onSkip,
    required this.onAddTime,
  });

  @override
  State<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends State<RestTimerBar> {
  Timer? _ticker;
  bool _firedHaptic = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant RestTimerBar old) {
    super.didUpdateWidget(old);
    if (old.endsAt != widget.endsAt) {
      _firedHaptic = false;
      _start();
    }
  }

  void _start() {
    _ticker?.cancel();
    if (widget.endsAt == null) return;
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final remaining =
          widget.endsAt!.difference(DateTime.now()).inMilliseconds;
      if (remaining <= 0 && !_firedHaptic) {
        _firedHaptic = true;
        HapticFeedback.heavyImpact();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final secs = d.inSeconds;
    final m = secs ~/ 60;
    final s = secs % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.endsAt == null) return const SizedBox.shrink();
    final remaining = widget.endsAt!.difference(DateTime.now());
    final overdue = remaining.isNegative;
    final shown = overdue ? -remaining : remaining;
    final label = overdue ? '+${_format(shown)}' : _format(shown);

    return Material(
      color: overdue ? Colors.red.shade800 : Colors.red,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.timer, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      overdue ? 'Rest over — go!' : 'Resting',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11),
                    ),
                    Text(
                      '$label   ${widget.exerciseName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: widget.onAddTime,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('+30s'),
              ),
              TextButton(
                onPressed: widget.onSkip,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Skip'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

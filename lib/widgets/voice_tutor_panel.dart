import 'package:flutter/material.dart';
import '../controller/voice_tutor_controller.dart';

/// Drop-in voice tutor UI panel.
///
/// Usage in question_screen.dart:
///
///   VoiceTutorPanel(controller: _voiceTutorController)
///
/// The controller should be created in the parent State and disposed there.
class VoiceTutorPanel extends StatelessWidget {
  final VoiceTutorController controller;

  const VoiceTutorPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          _buildHeader(),

          // ── Body ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildMicButton(context),
                const SizedBox(height: 16),
                if (controller.transcript.isNotEmpty) _buildTranscript(),
                if (controller.replyText.isNotEmpty)   _buildReply(),
                if (controller.hasError)                _buildError(),
                if (controller.isPlaying)               _buildPlayingIndicator(),
                if (controller.history.isNotEmpty)      _buildClearButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology, color: Colors.purple.shade700),
          const SizedBox(width: 8),
          const Text(
            'Voice AI Tutor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          if (controller.history.isNotEmpty)
            Tooltip(
              message: '${controller.history.length} turns in memory',
              child: Chip(
                label: Text('${controller.history.length}', style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.purple.shade100,
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMicButton(BuildContext context) {
    final state = controller.state;
    final bool busy = state == VoiceTutorState.processing;

    Color buttonColor;
    Color shadowColor;
    IconData icon;
    String label;

    switch (state) {
      case VoiceTutorState.recording:
        buttonColor = Colors.red;
        shadowColor = Colors.red.withOpacity(0.45);
        icon  = Icons.stop_circle_outlined;
        label = 'Tap to stop';
        break;
      case VoiceTutorState.processing:
        buttonColor = Colors.orange;
        shadowColor = Colors.orange.withOpacity(0.35);
        icon  = Icons.hourglass_top_rounded;
        label = 'Processing…';
        break;
      case VoiceTutorState.playing:
        buttonColor = Colors.green;
        shadowColor = Colors.green.withOpacity(0.35);
        icon  = Icons.volume_up;
        label = 'Tap to stop';
        break;
      case VoiceTutorState.error:
      case VoiceTutorState.idle:
        buttonColor = Colors.purple;
        shadowColor = Colors.purple.withOpacity(0.35);
        icon  = Icons.mic_none;
        label = 'Tap to speak';
        break;
    }

    return GestureDetector(
      onTap: busy
          ? null
          : () {
              if (state == VoiceTutorState.playing) {
                controller.stopPlayback();
              } else {
                controller.toggleRecording();
              }
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: buttonColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: buttonColor.withOpacity(0.6), width: 2),
        ),
        child: Column(
          children: [
            // Mic icon with animated pulse ring when recording
            Stack(
              alignment: Alignment.center,
              children: [
                if (state == VoiceTutorState.recording)
                  _PulseRing(color: buttonColor),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: buttonColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: shadowColor, blurRadius: 20, spreadRadius: 4),
                    ],
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        )
                      : Icon(icon, size: 36, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: buttonColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscript() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You said:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            controller.transcript,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildReply() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_outlined, size: 14, color: Colors.purple.shade700),
              const SizedBox(width: 4),
              Text(
                'Tutor:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            controller.replyText,
            style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              color: Colors.green.shade600,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Playing audio response…',
            style: TextStyle(color: Colors.green.shade700, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              controller.errorMessage,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClearButton(BuildContext context) {
    return TextButton.icon(
      onPressed: controller.isIdle || controller.hasError
          ? controller.clearHistory
          : null,
      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
      label: const Text('Clear conversation'),
      style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
    );
  }
}

/// Simple CSS-style pulse ring animation.
class _PulseRing extends StatefulWidget {
  final Color color;
  const _PulseRing({required this.color});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
    _scale   = Tween<double>(begin: 1.0, end: 2.2).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(begin: 0.5, end: 0.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: widget.color.withOpacity(_opacity.value), width: 3),
          ),
        ),
      ),
    );
  }
}
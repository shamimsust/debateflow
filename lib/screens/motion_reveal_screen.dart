import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class MotionRevealScreen extends StatelessWidget {
  final String tournamentId;
  final String round;

  const MotionRevealScreen({super.key, required this.tournamentId, required this.round});

  @override
  Widget build(BuildContext context) {
    // Standardize path: remove existing 'round_' if present, then add it back
    final String cleanId = round.toLowerCase().replaceAll('round_', '').replaceAll(' ', '_');
    final String dbPath = 'motions/$tournamentId/round_$cleanId';
    final String displayTitle = "ROUND ${cleanId.replaceAll('_', ' ').toUpperCase()}";

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(displayTitle, style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.w300)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(colors: [Color(0xFF1E293B), Color(0xFF0F172A)], radius: 1.2),
        ),
        child: StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref(dbPath).onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF46C3D7)));
            }

            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return _buildStateGui(Icons.search_off, "MOTION NOT FOUND", "Check Tournament ID or Round Selection");
            }

            final data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
            bool isReleased = data['is_released'] ?? false;
            
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              child: isReleased 
                ? _MotionContent(
                    key: ValueKey('active_$cleanId'),
                    motionText: data['text'] ?? "",
                    infoSlide: data['info_slide'],
                  ) 
                : _buildStateGui(Icons.lock_outline_rounded, "ENCRYPTED DATA", "AWAITING DECRYPTION..."),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStateGui(IconData icon, String title, String sub) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: const Color(0xFF46C3D7)),
          const SizedBox(height: 30),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 8, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 2)),
        ],
      ),
    );
  }
}

class _MotionContent extends StatefulWidget {
  final String motionText;
  final String? infoSlide;
  const _MotionContent({super.key, required this.motionText, this.infoSlide});

  @override
  State<_MotionContent> createState() => _MotionContentState();
}

class _MotionContentState extends State<_MotionContent> {
  String _typewriterText = "";
  int _charIndex = 0;
  Timer? _timer;
  int _seconds = 1800; 
  bool _running = false;

  @override
  void initState() {
    super.initState();
    final fullText = widget.motionText.toUpperCase();
    Timer.periodic(const Duration(milliseconds: 40), (t) {
      if (_charIndex < fullText.length && mounted) {
        setState(() => _typewriterText += fullText[_charIndex++]);
      } else { t.cancel(); }
    });
  }

  void _toggle() {
    setState(() => _running = !_running);
    if (_running) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_seconds > 0 && mounted) setState(() => _seconds--); else t.cancel();
      });
    } else { _timer?.cancel(); }
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggle,
        backgroundColor: _running ? Colors.redAccent : const Color(0xFF46C3D7),
        label: Text(_running ? "PAUSE PREP" : "START PREP", style: const TextStyle(color: Colors.white)),
        icon: Icon(_running ? Icons.pause : Icons.play_arrow, color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              if (widget.infoSlide?.isNotEmpty ?? false) ...[
                const Text("INFO SLIDE", style: TextStyle(color: Color(0xFF46C3D7), letterSpacing: 5, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Text(widget.infoSlide!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic)),
                const SizedBox(height: 50),
              ],
              Text(_typewriterText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, shadows: [Shadow(color: Color(0xFF46C3D7), blurRadius: 20)])),
              const SizedBox(height: 80),
              _buildClock(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClock() {
    String time = "${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(50), border: Border.all(color: const Color(0xFF46C3D7).withOpacity(0.5))),
      child: Text(time, style: const TextStyle(color: Colors.white, fontSize: 40, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
    );
  }
}
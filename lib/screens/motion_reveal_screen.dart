import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class MotionRevealScreen extends StatelessWidget {
  final String tournamentId;
  final String round;

  const MotionRevealScreen({super.key, required this.tournamentId, required this.round});

  @override
  Widget build(BuildContext context) {
    String displayRound = round.replaceAll('_', ' ').toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(displayRound, style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.w300)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            center: Alignment.center,
            radius: 1.2,
          ),
        ),
        child: StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance.ref('motions/$tournamentId/$round').onValue,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF46C3D7)));
            }

            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return _buildWaitingState("MOTION NOT FOUND");
            }

            final data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
            bool isReleased = data['is_released'] ?? false;
            String motionText = data['text'] ?? "";
            String? infoSlide = data['info_slide'];

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              child: isReleased 
                ? _MotionContent(motionText: motionText, infoSlide: infoSlide) 
                : _buildWaitingState("AWAITING DECRYPTION..."),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWaitingState(String subtext) {
    return Center(
      key: const ValueKey('waiting'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 80, color: Color(0xFF46C3D7)),
          const SizedBox(height: 30),
          const Text("ENCRYPTED DATA", style: TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 10, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(subtext, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 2)),
        ],
      ),
    );
  }
}

class _MotionContent extends StatefulWidget {
  final String motionText;
  final String? infoSlide;
  const _MotionContent({required this.motionText, this.infoSlide});

  @override
  State<_MotionContent> createState() => _MotionContentState();
}

class _MotionContentState extends State<_MotionContent> {
  String _displayPath = "";
  int _charIndex = 0;
  Timer? _typewriterTimer;

  Timer? _countdownTimer;
  int _secondsRemaining = 1800; // 30 minutes
  bool _isClockRunning = false;

  @override
  void initState() {
    super.initState();
    _startTypewriter();
  }

  void _startTypewriter() {
    final fullText = widget.motionText.toUpperCase();
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (_charIndex < fullText.length) {
        setState(() {
          _displayPath += fullText[_charIndex];
          _charIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _toggleClock() {
    if (_isClockRunning) {
      _countdownTimer?.cancel();
    } else {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsRemaining > 0) {
          setState(() => _secondsRemaining--);
        } else {
          timer.cancel();
        }
      });
    }
    setState(() => _isClockRunning = !_isClockRunning);
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return "${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleClock,
        backgroundColor: _isClockRunning ? Colors.redAccent : const Color(0xFF46C3D7),
        icon: Icon(_isClockRunning ? Icons.pause : Icons.play_arrow, color: Colors.white),
        label: Text(_isClockRunning ? "PAUSE PREP" : "START PREP", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.infoSlide != null && widget.infoSlide!.isNotEmpty) ...[
                  const Text("INFO SLIDE", style: TextStyle(color: Color(0xFF46C3D7), letterSpacing: 5, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Text(widget.infoSlide!, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 50),
                ],
                // 🛠️ THBT REMOVED: Motion text now stands alone
                Text(
                  _displayPath,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 34, 
                    fontWeight: FontWeight.w900, 
                    height: 1.3, 
                    shadows: [Shadow(color: Color(0xFF46C3D7), blurRadius: 15)]
                  ),
                ),
                const SizedBox(height: 80),
                _buildClockBadge(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClockBadge() {
    bool isFinished = _secondsRemaining == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: isFinished ? Colors.red.withOpacity(0.1) : const Color(0xFF46C3D7).withOpacity(0.1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: isFinished ? Colors.red : const Color(0xFF46C3D7).withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_sharp, color: isFinished ? Colors.red : const Color(0xFF46C3D7), size: 30),
              const SizedBox(width: 15),
              Text(
                _formatTime(_secondsRemaining),
                style: TextStyle(
                  color: isFinished ? Colors.red : Colors.white, 
                  fontWeight: FontWeight.w900, 
                  fontSize: 40,
                  fontFamily: 'Courier',
                  letterSpacing: 4
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(isFinished ? "TIME UP!" : "PREPARATION TIME", 
            style: TextStyle(color: isFinished ? Colors.red : const Color(0xFF46C3D7), fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
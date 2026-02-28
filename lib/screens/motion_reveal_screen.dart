import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/motion_service.dart';

class MotionRevealScreen extends StatelessWidget {
  final String tournamentId;
  final String round;

  const MotionRevealScreen({
    super.key, 
    required this.tournamentId, 
    required this.round
  });

  @override
  Widget build(BuildContext context) {
    final motionService = context.read<MotionService>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), 
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("ROUND $round", style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.w300)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // ✅ FIXED: Using 'gradient' instead of 'radialGradient'
          gradient: RadialGradient(
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
            center: Alignment.center,
            radius: 1.2,
          ),
        ),
        child: StreamBuilder<DatabaseEvent>(
          stream: motionService.watchMotion(tournamentId, round),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF46C3D7)));
            }

            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return _buildWaitingState("MOTION ENCRYPTED");
            }

            final data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);
            bool isReleased = data['is_released'] ?? false;
            String motionText = data['text'] ?? "";
            String? infoSlide = data['info_slide'];

            return AnimatedSwitcher(
              duration: const Duration(seconds: 1),
              switchInCurve: Curves.easeInOutSine,
              child: isReleased 
                ? _buildMotionDisplay(motionText, infoSlide) 
                : _buildWaitingState("AWAITING RELEASE..."),
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
          const Text(
            "ENCRYPTED DATA",
            style: TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 10, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            subtext,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildMotionDisplay(String motion, String? info) {
    return Padding(
      key: const ValueKey('released'),
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (info != null && info.trim().isNotEmpty) ...[
                const Text("INFO SLIDE", style: TextStyle(color: Color(0xFF46C3D7), letterSpacing: 5, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Text(info, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, height: 1.6, fontStyle: FontStyle.italic)),
                const SizedBox(height: 50),
              ],
              const Text(
                "THIS HOUSE BELIEVES THAT",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF46C3D7), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 6),
              ),
              const SizedBox(height: 40),
              Text(
                motion.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, height: 1.2),
              ),
              const SizedBox(height: 80),
              _buildTimerBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF46C3D7).withOpacity(0.1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFF46C3D7).withOpacity(0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_sharp, color: Color(0xFF46C3D7)),
          SizedBox(width: 10),
          Text("30 MINS PREP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ],
      ),
    );
  }
}
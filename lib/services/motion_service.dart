import 'package:firebase_database/firebase_database.dart';

class MotionService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // Helper to ensure "1" becomes "round_1" and "Grand Final" becomes "round_grand_final"
  String _getSanitizedPath(String tId, String round) {
    final cleanRound = round.toLowerCase().replaceAll(' ', '_').replaceAll('round_', '');
    return 'motions/$tId/round_$cleanRound';
  }

  Future<void> setMotion({
    required String tId,
    required String round,
    required String motionText,
    String? infoSlide,
  }) async {
    await _db.ref(_getSanitizedPath(tId, round)).set({
      'text': motionText,
      'info_slide': infoSlide ?? "",
      'is_released': false,
      'release_time': null,
    });
  }

  Future<void> releaseMotion(String tId, String round) async {
    await _db.ref(_getSanitizedPath(tId, round)).update({
      'is_released': true,
      'release_time': ServerValue.timestamp,
    });
  }
}
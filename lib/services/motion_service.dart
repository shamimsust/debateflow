import 'package:firebase_database/firebase_database.dart';

class MotionService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Sets the motion for a round but keeps it hidden (_isReleased: false).
  Future<void> setMotion({
    required String tId,
    required String round,
    required String motionText,
    String? infoSlide,
  }) async {
    await _db.ref('motions/$tId/round_$round').set({
      'text': motionText,
      'info_slide': infoSlide,
      'is_released': false,
      'release_time': null,
    });
  }

  /// The "Big Red Button" - Triggers real-time release for all users.
  Future<void> releaseMotion(String tId, String round) async {
    await _db.ref('motions/$tId/round_$round').update({
      'is_released': true,
      'release_time': ServerValue.timestamp,
    });
  }

  /// Stream for the "Motion Release Screen" (The Big Screen in the Hall).
  Stream<DatabaseEvent> watchMotion(String tId, String round) {
    return _db.ref('motions/$tId/round_$round').onValue;
  }
}
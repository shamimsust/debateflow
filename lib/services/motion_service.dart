import 'package:firebase_database/firebase_database.dart';

class MotionService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// 📝 Create or Update a Motion (Admin Only)
  /// Keeps it hidden by default until the Big Reveal.
  Future<void> setMotion({
    required String tId,
    required String round,
    required String motionText,
    String? infoSlide,
  }) async {
    try {
      await _db.ref('motions/$tId/round_$round').set({
        'text': motionText,
        'info_slide': infoSlide ?? "",
        'is_released': false,
        'release_time': null,
        'updated_at': ServerValue.timestamp,
      });
    } catch (e) {
      throw Exception("Failed to save motion: $e");
    }
  }

  /// 🔴 THE BIG RED BUTTON (Admin Only)
  /// Flips 'is_released' to true, triggering the typewriter reveal for all users.
  Future<void> releaseMotion(String tId, String round) async {
    try {
      await _db.ref('motions/$tId/round_$round').update({
        'is_released': true,
        'release_time': ServerValue.timestamp,
      });
    } catch (e) {
      throw Exception("Failed to release motion: $e");
    }
  }

  /// 🔄 Reset Motion (Admin Only)
  /// Use this if you need to pull a motion back or reset the reveal for testing.
  Future<void> hideMotion(String tId, String round) async {
    await _db.ref('motions/$tId/round_$round').update({
      'is_released': false,
      'release_time': null,
    });
  }

  /// 🗑️ Delete Motion
  Future<void> deleteMotion(String tId, String round) async {
    await _db.ref('motions/$tId/round_$round').remove();
  }

  /// 📺 Public Stream
  /// Connects to the 'MotionRevealScreen' built earlier.
  Stream<DatabaseEvent> watchMotion(String tId, String round) {
    return _db.ref('motions/$tId/round_$round').onValue;
  }
}
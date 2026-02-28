import 'package:firebase_database/firebase_database.dart';

class RoundService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Updates the status of a round. 
  /// 'Draft' -> Only admins see it.
  /// 'Released' -> Visible to speakers/judges.
  Future<void> updateRoundStatus(String tId, String roundNum, String status) async {
    await _db.ref('tournaments/$tId/rounds/round_$roundNum').update({
      'status': status,
      'status_timestamp': ServerValue.timestamp,
    });
  }

  /// Fetches the current active round number for a tournament.
  Future<int> getCurrentRound(String tId) async {
    final snap = await _db.ref('tournaments/$tId/current_round').get();
    return (snap.value as int?) ?? 1;
  }

  /// Logic for "Advancing" the tournament.
  /// This increments the round and resets match statuses for the next set.
  Future<void> advanceToNextRound(String tId) async {
    final current = await getCurrentRound(tId);
    await _db.ref('tournaments/$tId').update({
      'current_round': current + 1,
    });
  }
}
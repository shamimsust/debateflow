import 'package:firebase_database/firebase_database.dart';
import '../models/debate_models.dart';

class DatabaseService {
  // ✅ MUCH BETTER: Since your new DB is in the US, 
  // the default instance now works automatically!
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // ==========================================
  // 1. MATCH DATA FETCHING
  // ==========================================

  /// Streams a specific match for real-time UI updates
  Stream<DatabaseEvent> watchMatch(String tId, String round, String mId) {
    return _db.ref('matches/$tId/round_$round/$mId').onValue;
  }

  /// Fetches all matches for a specific round
  Future<Map?> fetchRoundMatches(String tId, String round) async {
    final snap = await _db.ref('matches/$tId/round_$round').get();
    return snap.value as Map?;
  }

  // ==========================================
  // 2. BALLOT SUBMISSION
  // ==========================================

  /// Saves a ballot and updates the match pointer
  Future<void> submitBallot({
    required String tournamentId,
    required String matchId,
    required String round,
    required BallotSubmission ballot,
  }) async {
    try {
      final ballotRef = _db.ref('ballots/$tournamentId/$matchId');
      final currentBallots = await ballotRef.get();
      
      int nextVersionNumber = currentBallots.exists ? currentBallots.children.length + 1 : 1;
      String versionKey = 'v$nextVersionNumber';

      await ballotRef.child(versionKey).set(ballot.toMap());

      await _db.ref('matches/$tournamentId/round_$round/$matchId').update({
        'status': 'Completed',
        'current_ballot': versionKey,
        'last_updated': ServerValue.timestamp,
      });

      await _db.ref('tournaments/$tournamentId').update({
        'lastChange': ServerValue.timestamp,
      });
      
    } catch (e) {
      throw Exception("Failed to submit ballot: $e");
    }
  }

  // ==========================================
  // 3. TOURNAMENT METADATA
  // ==========================================

  Future<Map<String, dynamic>> getTournamentSettings(String tId) async {
    final snap = await _db.ref('tournaments/$tId/settings').get();
    if (!snap.exists) return {'rule': 'WSDC', 'isLocked': false};
    return Map<String, dynamic>.from(snap.value as Map);
  }

  Future<BallotSubmission?> fetchBallot(String tId, String mId, String version) async {
    final snap = await _db.ref('ballots/$tId/$mId/$version').get();
    if (!snap.exists) return null;
    return BallotSubmission.fromMap(snap.value as Map);
  }
}
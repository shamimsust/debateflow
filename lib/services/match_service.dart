import 'package:firebase_database/firebase_database.dart';

class MatchService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<void> generateMatches({
    required String tournamentId,
    required int roundNumber,
    required String rule,
    List? teams, 
  }) async {
    // 1. Fetch Tournament Settings to see pairing choice
    final tournamentSnap = await _db.child('tournaments/$tournamentId').get();
    if (!tournamentSnap.exists) return;

    final dynamic tData = tournamentSnap.value;
    String pairingType = "Random";

    try {
      if (tData != null && tData['settings'] != null) {
        var pRules = tData['settings']['pairingRules'];
        if (pRules != null) {
          pairingType = pRules[roundNumber.toString()]?.toString() ?? "Random";
        }
      }
    } catch (_) {
      pairingType = "Random";
    }

    // 2. Resolve Team List
    List teamList = [];
    if (teams != null) {
      teamList = List.from(teams);
    } else {
      final teamsSnap = await _db.child('teams/$tournamentId').get();
      if (!teamsSnap.exists) return;
      
      for (var child in teamsSnap.children) {
        final dynamic t = child.value;
        if (t != null) {
          teamList.add({
            'id': child.key, 
            'name': t['name'] ?? "Unknown",
            'wins': (t['wins'] ?? 0).toDouble(),
            'totalMarks': (t['totalMarks'] ?? 0.0).toDouble(),
          });
        }
      }
    }

    // ✅ FIXED: Sort/Shuffle moved HERE so it applies to passed-in team lists too!
    if (pairingType == "Power Paired") {
      teamList.sort((a, b) {
        // First sort by Wins (descending)
        if (b['wins'] != a['wins']) return (b['wins']).compareTo(a['wins']);
        // Then sort by Total Marks/Points (descending)
        return (b['totalMarks']).compareTo(a['totalMarks']);
      });
    } else {
      teamList.shuffle();
    }

    if (teamList.isEmpty) return;

    // 3. Clear existing matches for this round
    await _db.child('matches/$tournamentId/round_$roundNumber').remove();

    // 4. Fetch Logistics (Judges & Rooms)
    final judgesSnap = await _db.child('adjudicators/$tournamentId').get();
    List<Map<String, dynamic>> availableJudges = [];
    for (var child in judgesSnap.children) {
      final dynamic j = child.value;
      if (j != null) availableJudges.add({'id': child.key, 'name': j['name'] ?? "TBD"});
    }
    availableJudges.shuffle();

    final roomsSnap = await _db.child('rooms/$tournamentId').get();
    List<String> availableRooms = [];
    for (var child in roomsSnap.children) {
      final dynamic r = child.value;
      if (r != null && r['name'] != null) availableRooms.add(r['name'].toString());
    }

    int teamsPerMatch = (rule == "BP") ? 4 : 2;
    final matchRef = _db.child('matches/$tournamentId/round_$roundNumber');

    // 5. Generate Pairings
    for (int i = 0; i < teamList.length; i += teamsPerMatch) {
      if (i + teamsPerMatch <= teamList.length) {
        Map<String, dynamic> matchData = {
          'status': 'Pending',
          'rule': rule,
          'type': 'Prelim',
          'round': roundNumber,
          'pairingMethod': pairingType,
        };

        if (rule == "BP") {
          matchData.addAll({
            'sideOG': teamList[i]['name'], 'sideOGId': teamList[i]['id'],
            'sideOO': teamList[i+1]['name'], 'sideOOId': teamList[i+1]['id'],
            'sideCG': teamList[i+2]['name'], 'sideCGId': teamList[i+2]['id'],
            'sideCO': teamList[i+3]['name'], 'sideCOId': teamList[i+3]['id'],
          });
        } else {
          matchData.addAll({
            'sideA': teamList[i]['name'], 'sideAId': teamList[i]['id'],
            'sideB': teamList[i+1]['name'], 'sideBId': teamList[i+1]['id'],
          });
        }

        int matchIdx = (i ~/ teamsPerMatch);
        if (availableJudges.isNotEmpty) {
          var j = availableJudges[matchIdx % availableJudges.length];
          matchData['judge'] = j['name'];
          matchData['judgeId'] = j['id'];
        }
        
        if (availableRooms.isNotEmpty) {
          matchData['room'] = availableRooms[matchIdx % availableRooms.length];
        }

        await matchRef.push().set(matchData);
      } else {
        // Create BYEs for remainders (1-3 teams in BP, 1 team in WSDC)
        for (int k = i; k < teamList.length; k++) {
          await _createBye(tournamentId, teamList[k], roundNumber, rule);
        }
      }
    }
  }

  Future<void> _createBye(String tId, dynamic team, int round, String rule) async {
    final byeRef = _db.child('matches/$tId/round_$round').push();
    double points = (rule == "BP") ? 3.0 : 1.0; 
    double marks = (rule == "BP") ? 0.0 : 210.0; // Standard WSDC average for BYE

    await byeRef.set({
      'sideA': team['name'],
      'sideAId': team['id'],
      'sideB': 'BYE',
      'status': 'Completed',
      'winner': team['name'],
      'round': round,
      'is_bye': true,
    });

    final teamRef = _db.child('teams/$tId/${team['id']}');
    await teamRef.runTransaction((Object? teamData) {
      if (teamData == null) return Transaction.abort();
      Map<String, dynamic> updated = Map<String, dynamic>.from(teamData as Map);
      updated['wins'] = (updated['wins'] ?? 0).toDouble() + points;
      updated['totalMarks'] = (updated['totalMarks'] ?? 0).toDouble() + marks;
      return Transaction.success(updated);
    });
  }
}
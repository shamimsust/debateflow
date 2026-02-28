import 'package:firebase_database/firebase_database.dart';
import '../models/debate_models.dart';
import '../models/standing_models.dart';

class StandingsService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<Map<String, dynamic>> calculateAllStandings(String tournamentId) async {
    final matchesSnap = await _db.child('matches/$tournamentId').get();
    if (!matchesSnap.exists) return {'teams': <TeamStanding>[], 'speakers': <SpeakerStanding>[]};

    Map<String, TeamStanding> teamStats = {};
    Map<String, SpeakerStanding> speakerStats = {};

    Map roundsData = matchesSnap.value as Map;

    for (var roundKey in roundsData.keys) {
      Map matchesInRound = roundsData[roundKey] as Map;

      for (var matchKey in matchesInRound.keys) {
        Map matchData = matchesInRound[matchKey] as Map;
        
        // Only count completed matches with a submitted ballot
        if (matchData['status'] == 'Completed' && matchData['current_ballot'] != null) {
          String ballotId = matchData['current_ballot'];
          
          // Ballot path matches your structure: ballots/tournamentId/matchId/ballotId
          final ballotSnap = await _db.child('ballots/$tournamentId/$matchKey/$ballotId').get();
          
          if (ballotSnap.exists) {
            final ballot = BallotSubmission.fromMap(ballotSnap.value as Map);
            _processBallot(teamStats, speakerStats, ballot, matchData);
          }
        }
      }
    }

    // Wrap in our container to use the internal sorting logic
    final standings = TournamentStandings(
      tournamentId: tournamentId,
      teams: teamStats.values.toList(),
      speakers: speakerStats.values.toList(),
      lastUpdated: DateTime.now(),
    );

    standings.sortTeams();
    standings.sortSpeakers();

    return {
      'teams': standings.teams,
      'speakers': standings.speakers,
    };
  }

  void _processBallot(
    Map<String, TeamStanding> teamMap, 
    Map<String, SpeakerStanding> speakerMap, 
    BallotSubmission ballot, 
    Map matchData
  ) {
    // Determine format to assign points correctly
    String rule = matchData['rule'] ?? "WSDC";
    
    // In your schema, 'teams' is often a list of maps: [{teamId, teamName, side}, ...]
    List teamsList = matchData['teams'] as List;

    ballot.teamScores.forEach((side, scores) {
      final teamInfo = teamsList.firstWhere(
        (t) => t['side'] == side || t['role'] == side, 
        orElse: () => {}
      );
      
      String teamId = teamInfo['teamId'] ?? side;
      String teamName = teamInfo['teamName'] ?? "Team $side";

      // 1. Team Stats
      teamMap.putIfAbsent(teamId, () => TeamStanding(teamId: teamId, teamName: teamName));
      var team = teamMap[teamId]!;
      
      int rank = ballot.rankings[side] ?? 0;
      
      if (rule == "BP") {
        // BP Points: 1st=3, 2nd=2, 3rd=1, 4th=0
        team.wins += (4 - rank).clamp(0, 3);
      } else {
        // WSDC/3on3 Points: Win=1, Loss=0
        if (rank == 1) team.wins += 1;
      }
      
      team.totalSpeakerMarks += ballot.getTotalScore(side);
      team.ballotsCounted++;

      // 2. Speaker Stats (Ironman Aware)
      for (var sScore in scores) {
        if (sScore.speakerId == null || sScore.isGhost == true) continue;

        speakerMap.putIfAbsent(sScore.speakerId!, () => SpeakerStanding(
          speakerId: sScore.speakerId!,
          speakerName: sScore.speakerName ?? "Unknown",
          teamName: teamName,
        ));

        // In Ironman situations, a speaker speaks twice. 
        // We add both scores. The SpeakerStanding 'average' getter 
        // divides by scores.length, correctly averaging the Ironman's performance.
        speakerMap[sScore.speakerId!]!.scores.add(sScore.score);
      }
    });
  }
}
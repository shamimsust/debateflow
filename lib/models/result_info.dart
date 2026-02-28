import 'debate_models.dart';

/// Represents an individual speech performance for UI display.
class SpeechInfo {
  final String speakerName;
  final int position;
  final double score;
  final bool isGhost;

  SpeechInfo({
    required this.speakerName,
    required this.position,
    required this.score,
    required this.isGhost,
  });
}

/// Represents a team's total performance in a single ballot.
class TeamSheetInfo {
  final String teamName;
  final String side;
  final double totalScore;
  final int rank;
  final bool isWinner;
  final List<SpeechInfo> speeches;

  TeamSheetInfo({
    required this.teamName,
    required this.side,
    required this.totalScore,
    required this.rank,
    required this.isWinner,
    required this.speeches,
  });
}

/// A "Sheet" represents one judge's record or the final consensus.
class SheetInfo {
  final String? adjudicatorName;
  final List<TeamSheetInfo> teams;

  SheetInfo({
    this.adjudicatorName,
    required this.teams,
  });

  /// The "Magic" Factory: Converts a database Ballot into a UI Sheet.
  /// Requires [matchData] to map Side IDs to real Team Names.
  factory SheetInfo.fromBallot(BallotSubmission ballot, Map matchData) {
    List<TeamSheetInfo> teamInfos = [];

    ballot.teamScores.forEach((side, speakerScores) {
      // 1. Resolve Team Name from match data
      final teamsList = matchData['teams'] as List? ?? [];
      final teamEntry = teamsList.firstWhere(
        (t) => t['side'] == side, 
        orElse: () => {'teamName': side}
      );

      // 2. Map SpeakerScores to SpeechInfo
      final speeches = speakerScores.map((ss) => SpeechInfo(
        speakerName: ss.speakerName ?? "Speaker ${ss.position}",
        position: ss.position,
        score: ss.score,
        isGhost: ss.isGhost,
      )).toList();

      // 3. Create TeamSheetInfo
      teamInfos.add(TeamSheetInfo(
        teamName: teamEntry['teamName'],
        side: side,
        totalScore: ballot.getTotalScore(side),
        rank: ballot.rankings[side] ?? 0,
        isWinner: ballot.rankings[side] == 1,
        speeches: speeches,
      ));
    });

    // Sort teams by rank (1st, 2nd...) for the UI
    teamInfos.sort((a, b) => a.rank.compareTo(b.rank));

    return SheetInfo(
      adjudicatorName: ballot.submitterType == 'TABROOM' ? "Official Result" : "Judge Ballot",
      teams: teamInfos,
    );
  }
}
/// 1. Data for a single team's overall rank in the tournament.
class TeamStanding {
  final String teamId;
  final String teamName;
  
  int wins;               
  double totalSpeakerMarks;
  int ballotsCounted;
  double totalMargin; 

  TeamStanding({
    required this.teamId, 
    required this.teamName,
    this.wins = 0,
    this.totalSpeakerMarks = 0.0,
    this.ballotsCounted = 0,
    this.totalMargin = 0.0,
  });

  // ✅ Added for StandingsService to handle Firebase data easily
  factory TeamStanding.fromMap(String id, Map data) {
    return TeamStanding(
      teamId: id,
      teamName: data['name'] ?? 'Unknown Team',
      wins: data['wins'] ?? 0,
      totalSpeakerMarks: (data['totalMarks'] ?? 0.0).toDouble(),
      ballotsCounted: data['ballotsCounted'] ?? 0,
      totalMargin: (data['totalMargin'] ?? 0.0).toDouble(),
    );
  }

  double get totalMarks => totalSpeakerMarks;
  set totalMarks(double value) => totalSpeakerMarks = value;

  double get averageScore => ballotsCounted > 0 ? totalSpeakerMarks / ballotsCounted : 0.0;

  Map<String, dynamic> toSummaryMap() => {
    'team': teamName,
    'wins': wins,
    'total_marks': totalSpeakerMarks.toStringAsFixed(2),
    'avg': averageScore.toStringAsFixed(2),
  };
}

/// 2. Data for individual speaker rankings.
class SpeakerStanding {
  final String speakerId;
  final String speakerName;
  final String teamName;
  List<double> scores;

  SpeakerStanding({
    required this.speakerId,
    required this.speakerName,
    required this.teamName,
    List<double>? scores,
  }) : scores = scores ?? [];

  double get average => scores.isEmpty 
      ? 0.0 
      : scores.reduce((a, b) => a + b) / scores.length;

  double get averageScore => average;
  int get totalSpeeches => scores.length;
}

/// 3. The container for the entire tournament's current state.
class TournamentStandings {
  final String tournamentId;
  final List<TeamStanding> teams;
  final List<SpeakerStanding> speakers;
  final DateTime lastUpdated;

  TournamentStandings({
    required this.tournamentId,
    required this.teams,
    required this.speakers,
    required this.lastUpdated,
  });

  void sortTeams() {
    teams.sort((a, b) {
      if (b.wins != a.wins) return b.wins.compareTo(a.wins);
      // Secondary tie-break: Speaker Marks
      int markComp = b.totalSpeakerMarks.compareTo(a.totalSpeakerMarks);
      if (markComp != 0) return markComp;
      // Tertiary tie-break: Margin
      return b.totalMargin.compareTo(a.totalMargin);
    });
  }

  void sortSpeakers() {
    speakers.sort((a, b) => b.averageScore.compareTo(a.averageScore));
  }
}
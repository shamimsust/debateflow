/// Base class for debate validation logic
abstract class DebateScoresheet {
  final Map<String, List<double>> scores;
  DebateScoresheet(this.scores);
  bool isValid();
}

/// WSDC (3-on-3) Logic
class TwoTeamScoresheet extends DebateScoresheet {
  TwoTeamScoresheet(super.scores);

  @override
  bool isValid() {
    if (scores.length != 2) return false;
    
    // 1. Check for ties (Illegal in WSDC)
    double totalA = scores.values.first.fold(0, (a, b) => a + b);
    double totalB = scores.values.last.fold(0, (a, b) => a + b);
    if (totalA == totalB) return false;

    // 2. Range Validation (Substantive 60-80, Reply 30-40)
    for (var teamScores in scores.values) {
      if (teamScores.length != 4) return false;
      for (int i = 0; i < 3; i++) {
        if (teamScores[i] < 60 || teamScores[i] > 80) return false;
      }
      if (teamScores[3] < 30 || teamScores[3] > 40) return false;
    }
    return true;
  }
}

/// British Parliamentary (BP) Logic
class BPScoresheet extends DebateScoresheet {
  final Map<String, int> ranks;
  BPScoresheet(super.scores, this.ranks);

  @override
  bool isValid() {
    if (ranks.length != 4) return false;

    // 1. Check for duplicate ranks
    var uniqueRanks = ranks.values.toSet();
    if (uniqueRanks.length != 4) return false;

    // 2. Ensure ranks are within 1-4
    if (uniqueRanks.any((r) => r < 1 || r > 4)) return false;

    return true;
  }
}
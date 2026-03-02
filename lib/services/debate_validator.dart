/// debate_validator.dart

abstract class DebateValidator {
  String? validate(Map<String, List<double>> scores, Map<String, int> ranks, Map<String, dynamic> settings);
}

class WSDCValidator extends DebateValidator {
  @override
  String? validate(Map<String, List<double>> scores, Map<String, int> ranks, Map<String, dynamic> settings) {
    if (scores.length != 2) return "Missing team data.";
    
    double minSub = settings['minSub'] ?? 60.0;
    double maxSub = settings['maxSub'] ?? 80.0;
    double minRep = settings['minReply'] ?? 30.0;
    double maxRep = settings['maxReply'] ?? 40.0;

    for (var teamName in scores.keys) {
      List<double> s = scores[teamName]!;
      if (s.length != 4) return "Team $teamName is missing scores.";
      
      // Check Substantive
      for (int i = 0; i < 3; i++) {
        if (s[i] < minSub || s[i] > maxSub) return "$teamName: Speaker ${i+1} must be $minSub-$maxSub";
      }
      // Check Reply
      if (s[3] < minRep || s[3] > maxRep) return "$teamName: Reply must be $minRep-$maxRep";
    }

    // Check for Ties
    double totalA = scores.values.first.reduce((a, b) => a + b);
    double totalB = scores.values.last.reduce((a, b) => a + b);
    if (totalA == totalB) return "Ties are not allowed. Adjust scores by at least 0.5.";

    return null;
  }
}

class BPValidator extends DebateValidator {
  @override
  String? validate(Map<String, List<double>> scores, Map<String, int> ranks, Map<String, dynamic> settings) {
    if (ranks.length != 4) return "All 4 teams must have a rank.";
    
    // Check for duplicate ranks
    if (ranks.values.toSet().length != 4) return "Duplicate ranks detected. Each team must have a unique rank (1-4).";

    // "Iron Maiden" Rule: Ranks must mathematically follow total points
    List<MapEntry<String, double>> totals = scores.entries
        .map((e) => MapEntry(e.key, e.value.reduce((a, b) => a + b)))
        .toList();
    
    // Sort by points descending
    totals.sort((a, b) => b.value.compareTo(a.value));
    
    // This is a soft-check; usually BP requires ranks to follow points.
    // We will warn if Rank 1 has fewer points than Rank 2.
    for (int i = 0; i < totals.length - 1; i++) {
      String teamA = totals[i].key;
      String teamB = totals[i+1].key;
      if (ranks[teamA]! > ranks[teamB]!) {
        return "Point-Rank Conflict: ${totals[i].key} has more points but a lower rank.";
      }
    }

    return null;
  }
}
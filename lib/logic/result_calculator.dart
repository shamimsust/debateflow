import '../models/debate_models.dart';

/// The central "Brain" for all debate math and winner determination.
class ResultCalculator {
  
  // ==========================================
  // 1. INDIVIDUAL MATCH LOGIC
  // ==========================================

  /// Determines WSDC ranks based on Total Speaker Marks.
  /// Throws an exception if scores are tied (Ties are illegal in WSDC).
  static Map<String, int> calculateWSDCRanks(Map<String, List<SpeakerScore>> teamScores) {
    Map<String, double> totals = {};
    
    teamScores.forEach((side, scores) {
      // ✅ Using precision summing to avoid floating point issues
      totals[side] = double.parse(
        scores.fold(0.0, (sum, s) => sum + s.score).toStringAsFixed(2)
      );
    });

    var sortedSides = totals.keys.toList()
      ..sort((a, b) => totals[b]!.compareTo(totals[a]!));

    // ✅ FIXED: Better tie detection. In WSDC, if totals are equal, 
    // the judge MUST adjust speaker scores to create a winner.
    if (totals.length > 1 && totals[sortedSides[0]] == totals[sortedSides[1]]) {
      throw Exception("Tied scores are not allowed. Please adjust scores to determine a winner.");
    }

    return {
      sortedSides[0]: 1, // Winner (Rank 1)
      sortedSides[1]: 2, // Loser (Rank 2)
    };
  }

  // ==========================================
  // 2. PANEL & MAJORITY LOGIC
  // ==========================================

  /// Calculates the winner based on a panel of judges (Majority Vote).
  static String calculateMajorityWinner({
    required Map<String, String> adjVotes, // Map of Adjudicator ID -> Side Name
    required String chairId,
  }) {
    if (adjVotes.isEmpty) return "No Votes Recorded";

    Map<String, int> counts = {};
    for (var winnerSide in adjVotes.values) {
      counts[winnerSide] = (counts[winnerSide] ?? 0) + 1;
    }

    // Find the side with the most votes
    int maxVotes = 0;
    counts.forEach((_, v) { if (v > maxVotes) maxVotes = v; });

    List<String> leaders = counts.entries
        .where((e) => e.value == maxVotes)
        .map((e) => e.key)
        .toList();

    // ✅ Logic: 1 leader = Majority. 2+ leaders = Chair breaks the tie.
    if (leaders.length == 1) {
      return leaders.first; 
    } else {
      // Tie-break: Look at what the Chair voted for.
      return adjVotes[chairId] ?? leaders.first;
    }
  }

  /// Calculates average speaker scores across a panel for ranking purposes.
  static Map<String, List<double>> calculateAverageScores(List<BallotSubmission> ballots) {
    if (ballots.isEmpty) return {};

    Map<String, List<double>> aggregate = {};
    final firstBallot = ballots.first;
    
    for (String side in firstBallot.teamScores.keys) {
      int speechCount = firstBallot.teamScores[side]!.length;
      
      List<double> averagedSpeeches = List.generate(speechCount, (speechIdx) {
        double sum = 0;
        int validBallots = 0;
        
        for (var ballot in ballots) {
          if (ballot.teamScores.containsKey(side)) {
            sum += ballot.teamScores[side]![speechIdx].score;
            validBallots++;
          }
        }
        // ✅ Standard debate rounding to 2 decimal places
        return validBallots > 0 
            ? double.parse((sum / validBallots).toStringAsFixed(2)) 
            : 0.0;
      });
      aggregate[side] = averagedSpeeches;
    }
    return aggregate;
  }

  // ==========================================
  // 3. TOURNAMENT POINTS LOGIC
  // ==========================================

  /// Maps Rank to Tournament Points (Wins/Points).
  static int getPointsForRank(int rank, String rule) {
    if (rule == "WSDC") {
      return rank == 1 ? 1 : 0; 
    } else if (rule == "BP") {
      // ✅ FIXED: Clamp values to ensure points are always between 0 and 3.
      switch (rank) {
        case 1: return 3;
        case 2: return 2;
        case 3: return 1;
        case 4: return 0;
        default: return 0;
      }
    }
    return 0;
  }
}
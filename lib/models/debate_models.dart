
class DebateTeam {
  final String teamId;
  final String side;      
  final String teamName;
  final List<String> registeredSpeakerIds;

  DebateTeam({
    required this.teamId,
    required this.side,
    required this.teamName,
    required this.registeredSpeakerIds,
  });

  factory DebateTeam.fromMap(Map<dynamic, dynamic> data) {
    return DebateTeam(
      teamId: data['teamId']?.toString() ?? '',
      side: data['side']?.toString() ?? '',
      teamName: data['teamName']?.toString() ?? 'TBA',
      registeredSpeakerIds: List<String>.from(data['registeredSpeakerIds'] ?? []),
    );
  }
}

class SpeakerScore {
  final String? speakerId;
  final String? speakerName; 
  final int position;        
  final double score;
  final bool isGhost;        

  SpeakerScore({
    this.speakerId,
    this.speakerName,
    required this.position,
    required this.score,
    this.isGhost = false,
  });

  Map<String, dynamic> toMap() => {
    'speakerId': speakerId,
    'speakerName': speakerName,
    'position': position,
    'score': score,
    'isGhost': isGhost,
  };

  factory SpeakerScore.fromMap(Map<dynamic, dynamic> data) {
    return SpeakerScore(
      speakerId: data['speakerId']?.toString(),
      speakerName: data['speakerName']?.toString() ?? "TBA",
      position: (data['position'] ?? 1) as int,
      score: (data['score'] ?? 0.0).toDouble(),
      isGhost: data['isGhost'] ?? false,
    );
  }
}

class BallotSubmission {
  final int version;
  final bool confirmed;
  final String submitterId;
  final String submitterType; 
  final String? ipAddress;
  final int timestamp;
  final Map<String, List<SpeakerScore>> teamScores; 
  final Map<String, int> rankings; 

  BallotSubmission({
    required this.version,
    required this.confirmed,
    required this.submitterId,
    required this.submitterType,
    this.ipAddress,
    required this.timestamp,
    required this.teamScores,
    required this.rankings,
  });

  double getTotalScore(String side) {
    if (!teamScores.containsKey(side)) return 0.0;
    return teamScores[side]!.fold(0.0, (sum, speech) => sum + speech.score);
  }

  Map<String, dynamic> toMap() => {
    'version': version,
    'confirmed': confirmed,
    'submitterId': submitterId,
    'submitterType': submitterType,
    'ipAddress': ipAddress,
    'timestamp': timestamp,
    'rankings': rankings,
    'teamScores': teamScores.map((side, scores) => 
        MapEntry(side, scores.map((s) => s.toMap()).toList())),
  };

  factory BallotSubmission.fromMap(Map<dynamic, dynamic> data) {
    // 1. Safe reconstruct nested SpeakerScore objects
    Map<String, List<SpeakerScore>> scores = {};
    if (data['teamScores'] != null) {
      (data['teamScores'] as Map).forEach((side, list) {
        scores[side.toString()] = (list as List)
            .map((s) => SpeakerScore.fromMap(s as Map))
            .toList();
      });
    }

    // 2. Safe reconstruct rankings map (Handles dynamic types from Firebase)
    Map<String, int> ranks = {};
    if (data['rankings'] != null) {
      (data['rankings'] as Map).forEach((key, value) {
        ranks[key.toString()] = (value as num).toInt();
      });
    }

    return BallotSubmission(
      version: (data['version'] ?? 1) as int,
      confirmed: data['confirmed'] ?? false,
      submitterId: data['submitterId']?.toString() ?? 'unknown',
      submitterType: data['submitterType']?.toString() ?? 'PUBLIC',
      ipAddress: data['ipAddress']?.toString(),
      timestamp: (data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch) as int,
      rankings: ranks,
      teamScores: scores,
    );
  }
}
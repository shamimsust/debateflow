import 'package:flutter/material.dart';
import '../../models/debate_models.dart'; // Standardized import

class MatchOverviewCard extends StatelessWidget {
  final String roundName;
  final BallotSubmission ballot;

  const MatchOverviewCard({
    super.key, 
    required this.roundName, 
    required this.ballot
  });

  @override
  Widget build(BuildContext context) {
    // Determine winner by finding who has Rank 1
    final winnerSide = ballot.rankings.entries
        .firstWhere((e) => e.value == 1, orElse: () => ballot.rankings.entries.first)
        .key;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE0E7FF),
          child: Icon(Icons.analytics_outlined, color: Color(0xFF2264D7), size: 20),
        ),
        title: Text(
          roundName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text("Winner: $winnerSide", 
          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
        children: [
          const Divider(height: 1),
          // Loop through the sides (Prop/Opp or BP roles)
          ...ballot.teamScores.keys.map((side) => _buildSideDetail(side)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildSideDetail(String side) {
    final scores = ballot.teamScores[side]!;
    final total = scores.fold(0.0, (sum, s) => sum + s.score);
    final rank = ballot.rankings[side] ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: rank == 1 ? Colors.blue.withOpacity(0.02) : null,
        border: Border(bottom: BorderSide(color: Colors.grey.shade50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(side, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text("Total: ${total.toStringAsFixed(1)}", 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2264D7))),
            ],
          ),
          const SizedBox(height: 8),
          // Sub-list of speaker scores
          ...scores.map((s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text("Speaker ${s.position}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                const Spacer(),
                if (s.isGhost) 
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Text("IRONMAN", style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                  ),
                Text(s.score.toString(), style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
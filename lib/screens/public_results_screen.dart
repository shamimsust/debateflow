// lib/screens/public_results_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/debate_models.dart';
import '../widgets/match_overview_card.dart'; // Using the card we fixed

class PublicResultsScreen extends StatelessWidget {
  final String tournamentId;

  const PublicResultsScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    // Reference to all matches in the tournament
    final matchesRef = FirebaseDatabase.instance.ref('matches/$tournamentId');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Public Results"),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder(
        stream: matchesRef.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return _buildEmptyState();
          }

          // 1. Flatten the nested round structure into a single list of results
          List<Widget> resultCards = [];
          Map rounds = snapshot.data!.snapshot.value as Map;

          // Iterate through round_1, round_2, etc.
          rounds.forEach((roundKey, matches) {
            if (matches is Map) {
              matches.forEach((matchId, matchData) {
                // 2. Only show matches that have a ballot submitted
                if (matchData['status'] == 'Completed' && matchData['current_ballot'] != null) {
                  resultCards.add(
                    _buildResultFutureCard(
                      roundKey.replaceAll('_', ' ').toUpperCase(),
                      matchId,
                      matchData['current_ballot'],
                    ),
                  );
                }
              });
            }
          });

          if (resultCards.isEmpty) return _buildEmptyState();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: resultCards,
          );
        },
      ),
    );
  }

  /// Since the ballot is stored in a separate node, we fetch it specifically
  Widget _buildResultFutureCard(String roundTitle, String matchId, String version) {
    return FutureBuilder(
      future: FirebaseDatabase.instance.ref('ballots/$tournamentId/$matchId/$version').get(),
      builder: (context, AsyncSnapshot<DataSnapshot> ballotSnap) {
        if (!ballotSnap.hasData || !ballotSnap.data!.exists) return const SizedBox();

        final ballot = BallotSubmission.fromMap(
          Map<String, dynamic>.from(ballotSnap.data!.value as Map)
        );

        return MatchOverviewCard(
          roundName: roundTitle,
          ballot: ballot,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No results released yet.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
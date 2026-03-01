import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import 'home_screen.dart'; 
import 'create_tournament_screen.dart';

class TournamentListScreen extends StatelessWidget {
  const TournamentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppUser?>(context);
    final uid = user?.uid ?? 'guest_user';
    
    // Listen to the global tournaments node
    final DatabaseReference tourneyRef = FirebaseDatabase.instance.ref().child('tournaments');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('DEBATEFLOW HUB', 
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: tourneyRef.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2264D7)));
          }
          
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return _buildEmptyState(context, uid);
          }

          // Safe data parsing
          final dynamic rawData = snapshot.data!.snapshot.value;
          Map<dynamic, dynamic> data = rawData is Map ? rawData : {};
          
          List<Map<String, dynamic>> tourneyList = [];
          
          data.forEach((key, value) {
            if (value is Map) {
              final tData = Map<String, dynamic>.from(value);
              // Only show tournaments where this user is the Admin
              if (tData['adminUid'] == uid) {
                tourneyList.add({
                  "id": key.toString(), 
                  ...tData
                });
              }
            }
          });

          if (tourneyList.isEmpty) {
            return _buildEmptyState(context, uid);
          }

          // Sort by newest first
          tourneyList.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text("MY EVENTS", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey, letterSpacing: 1.2)),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: tourneyList.length,
                  itemBuilder: (context, index) {
                    return _buildTourneyCard(context, tourneyList[index], uid);
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => CreateTournamentScreen(uid: uid))
        ),
        backgroundColor: const Color(0xFF2264D7),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("CREATE EVENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTourneyCard(BuildContext context, Map<String, dynamic> t, String uid) {
    final String tourneyId = t['id'] ?? "";
    final String tourneyName = t['name'] ?? "Unnamed Tournament";
    final String status = t['status'] ?? 'Setup';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF2264D7).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.gavel_rounded, color: Color(0xFF2264D7)),
        ),
        title: Text(tourneyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text("${t['rule'] ?? 'WSDC'} • ${status.toUpperCase()}", style: const TextStyle(fontSize: 12)), 
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onLongPress: () => _confirmDelete(context, tourneyId, tourneyName),
        onTap: () {
          // 🚀 FIX: Always go to HomeScreen. 
          // We removed the logic switch to SetupScreen because it was causing the crash.
          Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                tournamentId: tourneyId, 
                tournamentName: tourneyName
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String tourneyId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Tournament?"),
        content: Text("Permanently delete '$name'? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final db = FirebaseDatabase.instance.ref();
              // Clean up all related nodes
              await Future.wait([
                db.child('tournaments/$tourneyId').remove(),
                db.child('matches/$tourneyId').remove(),
                db.child('teams/$tourneyId').remove(),
                db.child('settings/$tourneyId').remove(),
                db.child('adjudicators/$tourneyId').remove(),
                db.child('rooms/$tourneyId').remove(),
                db.child('motions/$tourneyId').remove(),
              ]);
              if (context.mounted) Navigator.pop(context);
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("DELETE", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String uid) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No Tournaments Yet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
          const SizedBox(height: 8),
          Text("Tap 'Create Event' to start", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
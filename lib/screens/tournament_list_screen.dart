import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import 'home_screen.dart'; 
import 'create_tournament_screen.dart';
import 'setup_screen.dart'; // Ensure this is imported

class TournamentListScreen extends StatelessWidget {
  const TournamentListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppUser?>(context);
    final uid = user?.uid ?? 'guest_user';
    
    final DatabaseReference tourneyRef = FirebaseDatabase.instance.ref()
        .child('tournaments');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('DEBATEFLOW HUB', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
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

          Map data = snapshot.data!.snapshot.value as Map;
          List tourneyList = [];
          
          data.forEach((key, value) {
            final tData = Map<String, dynamic>.from(value);
            if (tData['adminUid'] == uid) {
              tourneyList.add({"id": key, ...tData});
            }
          });

          if (tourneyList.isEmpty) {
            return _buildEmptyState(context, uid);
          }

          tourneyList.sort((a, b) => (b['createdAt'] ?? 0).compareTo(a['createdAt'] ?? 0));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text("MY EVENTS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1.2)),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tourneyList.length,
                  itemBuilder: (context, index) {
                    final t = tourneyList[index];
                    return _buildTourneyCard(context, t, uid);
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

  Widget _buildTourneyCard(BuildContext context, Map t, String uid) {
    final String tourneyId = t['id'];
    // 🛠️ FIX: Check status to determine where to go
    final String status = t['status'] ?? 'Setup';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFF2264D7).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.gavel_rounded, color: Color(0xFF2264D7)),
        ),
        title: Text(t['name'] ?? "New Tournament", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text("${t['rule'] ?? 'WSDC'} • ${status.toUpperCase()}"), 
        trailing: const Icon(Icons.chevron_right_rounded),
        onLongPress: () => _confirmDelete(context, uid, tourneyId, t['name']),
        onTap: () {
          // 🛠️ LOGIC SWITCH: 
          if (status == 'Active') {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => HomeScreen(tournamentId: tourneyId, tournamentName: t['name']))
            );
          } else {
            // If it's 'Setup', take them to complete the Wizard
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => SetupScreen(tournamentId: tourneyId))
            );
          }
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String uid, String tourneyId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Tournament?"),
        content: Text("Are you sure you want to delete '$name'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final db = FirebaseDatabase.instance.ref();
              await db.child('tournaments/$tourneyId').remove();
              await db.child('matches/$tourneyId').remove();
              await db.child('teams/$tourneyId').remove();
              await db.child('settings/$tourneyId').remove();
              await db.child('adjudicators/$tourneyId').remove();
              await db.child('rooms/$tourneyId').remove();
              
              if (context.mounted) Navigator.pop(context);
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white))
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
          Icon(Icons.auto_awesome, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 20),
          const Text("No Tournaments Found", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text("UID: $uid", style: const TextStyle(fontSize: 10, color: Colors.grey)), 
        ],
      ),
    );
  }
}
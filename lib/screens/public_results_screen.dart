import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class PublicResultsScreen extends StatefulWidget {
  final String tournamentId;

  const PublicResultsScreen({super.key, required this.tournamentId});

  @override
  State<PublicResultsScreen> createState() => _PublicResultsScreenState();
}

class _PublicResultsScreenState extends State<PublicResultsScreen> {
  final ScreenshotController screenshotController = ScreenshotController();

  // 🛠️ Share logic specific to this results page
  void _sharePublicLink() {
    final String baseUrl = kIsWeb ? Uri.base.origin : "https://debateflow-2026.web.app";
    final String shareUrl = "$baseUrl/#/results?tid=${widget.tournamentId}";
    
    Clipboard.setData(ClipboardData(text: shareUrl));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Results link copied to clipboard!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _exportAndShareImage() async {
    try {
      final Uint8List? imageBytes = await screenshotController.capture();
      if (imageBytes != null) {
        if (kIsWeb) {
          _sharePublicLink();
        } else {
          final directory = await getTemporaryDirectory();
          final file = await File('${directory.path}/official_results.png').create();
          await file.writeAsBytes(imageBytes);
          await Share.shareXFiles([XFile(file.path)], text: 'Tournament Official Results');
        }
      }
    } catch (e) {
      debugPrint("Export Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final ballotsRef = FirebaseDatabase.instance.ref('ballots/${widget.tournamentId}');

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text("OFFICIAL RESULTS", 
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
        backgroundColor: const Color(0xFF2264D7),
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Copy Link",
            icon: const Icon(Icons.link_rounded),
            onPressed: _sharePublicLink,
          ),
          IconButton(
            tooltip: "Share Image",
            icon: const Icon(Icons.image_rounded),
            onPressed: _exportAndShareImage,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Screenshot(
        controller: screenshotController,
        child: Container(
          color: const Color(0xFFF1F5F9), // Ensure background is solid for screenshots
          child: StreamBuilder(
            stream: ballotsRef.onValue,
            builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                return _buildEmptyState();
              }

              Map data = snapshot.data!.snapshot.value as Map;
              List<MapEntry> ballotList = data.entries.toList();
              
              // Sort by round (Newest rounds first)
              ballotList.sort((a, b) {
                var roundA = a.value['round'] ?? 0;
                var roundB = b.value['round'] ?? 0;
                return roundB.compareTo(roundA);
              });

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: ballotList.length,
                itemBuilder: (context, index) {
                  final ballotData = ballotList[index].value;
                  return _buildResultCard(ballotData);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(dynamic data) {
    Map results = data['results'] as Map;
    int round = data['round'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("ROUND $round", 
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2264D7), fontSize: 12)),
                const Icon(Icons.verified, color: Colors.blue, size: 16),
              ],
            ),
            const Divider(height: 20),
            ...results.entries.map((e) {
              bool isWinner = e.value['rank'] == 1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(e.value['teamName'], 
                        style: TextStyle(
                          fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                          fontSize: 16,
                          color: isWinner ? Colors.black : Colors.black54
                        )),
                    ),
                    if (isWinner) 
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50, 
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade200)
                        ),
                        child: const Text("WINNER", 
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                      )
                    else
                      Text("${e.value['total']} pts", 
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.query_stats_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("No results have been published yet.", 
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
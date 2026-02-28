import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class HealthCheckService {
  static Future<bool> performCheck() async {
    final db = FirebaseDatabase.instance.ref('.info/connected');
    final testRef = FirebaseDatabase.instance.ref('health_check');

    try {
      debugPrint("📡 Starting Firebase Health Check...");

      // 1. Check if the app is even connected to the Firebase server
      final connectionSnap = await db.get();
      if (connectionSnap.value != true) {
        debugPrint("❌ Error: App is not connected to Firebase servers.");
        return false;
      }

      // 2. Try to write a test value
      final timestamp = DateTime.now().toIso8601String();
      await testRef.set({
        'status': 'Online',
        'last_check': timestamp,
        'platform': defaultTargetPlatform.toString(),
      });
      debugPrint("✅ Write Test: Success");

      // 3. Try to read it back
      final readSnap = await testRef.get();
      if (readSnap.exists) {
        debugPrint("✅ Read Test: Success (${readSnap.value})");
        return true;
      }

      return false;
    } catch (e) {
      debugPrint("🚨 Health Check Failed: $e");
      return false;
    }
  }
}
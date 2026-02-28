import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Convert Firebase User to our AppUser model
  AppUser? _userFromFirebase(User? user) {
    return user != null ? AppUser(uid: user.uid) : null;
  }

  // 2. Stream: Listens for login/logout events in real-time
  Stream<AppUser?> get user {
    return _auth.authStateChanges().map(_userFromFirebase);
  }

  // 3. Register with Email & Password
  Future<AppUser?> registerWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), 
          password: password
      );
      return _userFromFirebase(result.user);
    } on FirebaseAuthException catch (e) {
      // Professional logging for specific Firebase errors
      print("Auth Error (Register): ${e.code}");
      return null;
    } catch (e) {
      print("General Error: $e");
      return null;
    }
  }

  // 4. Login with Email & Password
  Future<AppUser?> loginWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email.trim(), 
          password: password
      );
      return _userFromFirebase(result.user);
    } on FirebaseAuthException catch (e) {
      print("Auth Error (Login): ${e.code}");
      return null;
    } catch (e) {
      print("General Error: $e");
      return null;
    }
  }

  // 5. Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print("Sign Out Error: $e");
    }
  }
}
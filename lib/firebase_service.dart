import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Create User in Auth and Save Profile in Firestore
  Future<User?> signUp(String email, String password, String username) async {
    try {
      // 1. Create the account in Firebase Auth
      UserCredential res = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), 
        password: password,
      );

      // 2. Create the user document in Firestore with starting stats
      if (res.user != null) {
        await _db.collection('users').doc(res.user!.uid).set({
          'username': username.trim().isEmpty ? 'Player' : username.trim(),
          'totalExp': 0,      // Starting EXP for the leaderboard
          'rank': 'Rookie',    // Starting rank
          'level': 1,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return res.user;
    } catch (e) {
      print("Sign up error: $e");
      rethrow; 
    }
  }

  // 2. Login User and ensure their Firestore document exists
  Future<User?> login(String email, String password) async {
    UserCredential res = await _auth.signInWithEmailAndPassword(
      email: email.trim(), 
      password: password,
    );
    
    // Ensure document exists in Firestore even if previous signup failed midway
    if (res.user != null) {
      final docRef = _db.collection('users').doc(res.user!.uid);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        await docRef.set({
          'username': email.trim().split('@').first,
          'totalExp': 0,
          'rank': 'Rookie',
          'level': 1,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
    return res.user;
  }

  // Get user profile data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  // Send password reset email
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // 3. Fetch Real-Time Leaderboard
  Stream<QuerySnapshot> getLeaderboard() {
    return _db.collection('users')
        .orderBy('totalExp', descending: true)
        .limit(10)
        .snapshots();
  }

  // inside your FirebaseService class
  Stream<List<Map<String, dynamic>>> getLeaderboardStream() {
    return _db.collection('users')
        .orderBy('totalExp', descending: true) // Rank by highest EXP
        .limit(20) // Show top 20 players
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => doc.data())
            .toList());
  }

  Future<void> updateUserExp(int newExp) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'totalExp': newExp,
      // Automatically level up every 100 EXP
      'level': (newExp / 100).floor() + 1, 
      'rank': newExp > 500 ? 'Professional' : 'Rookie',
    }, SetOptions(merge: true));
  }
}


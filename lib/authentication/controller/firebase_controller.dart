import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create new user and store additional data in Firestore
  Future<String?> createUser({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // Create user in Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save additional details in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; // No errors
    } catch (e) {
      return e.toString(); // Return error message
    }
  }

  // Login existing user
  Future<String?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      // Attempt to sign in the user with Firebase Authentication
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if user exists in Firestore (optional, depending on your use case)
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();

      if (!userDoc.exists) {
        return 'User does not exist in Firestore'; // Firestore check failed
      }

      return null; // No errors
    } catch (e) {
      return e.toString(); // Return error message
    }
  }

  // Check if the user is currently logged in
  Future<User?> getCurrentUser() async {
    return _auth.currentUser;
  }

  // Log out the current user
  Future<void> logoutUser() async {
    await _auth.signOut();
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Singleton service for Firebase initialization and access
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  bool _initialized = false;

  /// Initialize Firebase ,call once in main()
  Future<void> initialize() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    _initialized = true;
  }

  /// Current authenticated user ID (null if not signed in)
  String? get currentUserId => auth.currentUser?.uid;

  /// Whether a user is currently signed in
  bool get isAuthenticated => auth.currentUser != null;

  /// Sign in anonymously (used for demo / hackathon)
  Future<User?> signInAnonymously() async {
    try {
      // If already signed in, reuse the session
      if (auth.currentUser != null) return auth.currentUser;
      final result = await auth.signInAnonymously();
      return result.user;
    } catch (e) {
      print('Anonymous sign-in error: $e');
      return null;
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    await auth.signOut();
  }
}
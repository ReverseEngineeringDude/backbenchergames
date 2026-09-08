import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_profile.dart';

/// Authentication service supporting Firebase Auth, Google Sign-In, and Guest fallback.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _userController = StreamController<UserProfile?>.broadcast();
  UserProfile? _currentUser;
  bool _isFirebaseAvailable = false;

  UserProfile? get currentUser => _currentUser;
  Stream<UserProfile?> get authStateChanges => _userController.stream;
  bool get isFirebaseAvailable => _isFirebaseAvailable;

  Future<void> initialize() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _isFirebaseAvailable = true;
        final initialUser = FirebaseAuth.instance.currentUser;
        if (initialUser != null) {
          _currentUser = await _fetchOrCreateProfile(initialUser);
          _userController.add(_currentUser);
        }
        FirebaseAuth.instance.authStateChanges().listen(_handleFirebaseAuthChange);
        return;
      }
    } catch (e) {
      debugPrint('Firebase not initialized, running in offline/demo mode: $e');
    }

    _isFirebaseAvailable = false;
    // Auto login as a guest for instant playability in offline demo mode
    await signInAsGuest('Player 1');
  }

  void _handleFirebaseAuthChange(User? user) async {
    if (user == null) {
      _currentUser = null;
      _userController.add(null);
    } else {
      final profile = await _fetchOrCreateProfile(user);
      _currentUser = profile;
      _userController.add(profile);
    }
  }

  Future<UserProfile> _fetchOrCreateProfile(User user) async {
    if (!_isFirebaseAvailable) {
      return UserProfile(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'Player ${user.uid.substring(0, 4)}',
        avatarUrl: user.photoURL ?? '',
        createdAt: DateTime.now(),
        isAnonymous: user.isAnonymous,
      );
    }

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    try {
      final doc = await docRef.get();

      if (doc.exists && doc.data() != null) {
        final existing = UserProfile.fromJson(doc.data()!);
        if (!user.isAnonymous && (user.displayName != null || user.photoURL != null)) {
          final updated = existing.copyWith(
            displayName: user.displayName?.isNotEmpty == true ? user.displayName : existing.displayName,
            avatarUrl: user.photoURL?.isNotEmpty == true ? user.photoURL : existing.avatarUrl,
            isAnonymous: false,
          );
          if (updated.displayName != existing.displayName ||
              updated.avatarUrl != existing.avatarUrl ||
              existing.isAnonymous) {
            await docRef.set(updated.toJson(), SetOptions(merge: true));
            return updated;
          }
        }
        return existing;
      } else {
        final newProfile = UserProfile(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName?.isNotEmpty == true
              ? user.displayName!
              : (user.isAnonymous ? 'Guest_${user.uid.substring(0, 5)}' : 'Player'),
          avatarUrl: user.photoURL ?? '',
          createdAt: DateTime.now(),
          isAnonymous: user.isAnonymous,
        );
        if (!user.isAnonymous) {
          await docRef.set(newProfile.toJson());
        }
        return newProfile;
      }
    } catch (e) {
      debugPrint('Error fetching/creating profile from Firestore: $e');
      return UserProfile(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName?.isNotEmpty == true
            ? user.displayName!
            : (user.isAnonymous ? 'Guest_${user.uid.substring(0, 5)}' : 'Player'),
        avatarUrl: user.photoURL ?? '',
        createdAt: DateTime.now(),
        isAnonymous: user.isAnonymous,
      );
    }
  }

  /// Sign in with Google using a popup window on Web and native account-picker popup on Android.
  Future<UserProfile?> signInWithGoogle() async {
    if (_isFirebaseAvailable) {
      try {
        UserCredential cred;

        if (kIsWeb) {
          // On Web: launch popup window directly from user click gesture.
          // Never use redirect so the web page never navigates away.
          final googleProvider = GoogleAuthProvider();
          googleProvider.addScope('email');
          googleProvider.addScope('profile');
          googleProvider.setCustomParameters({'prompt': 'select_account'});

          cred = await FirebaseAuth.instance.signInWithPopup(googleProvider);
        } else {
          // On Mobile / Android: use GoogleSignIn to show the native Google
          // Account Picker popup dialog, avoiding any redirect to an external web browser.
          final googleSignIn = GoogleSignIn(
            scopes: <String>['email', 'profile'],
          );
          final googleUser = await googleSignIn.signIn();
          if (googleUser == null) {
            // User cancelled the sign-in dialog
            return null;
          }

          final googleAuth = await googleUser.authentication;
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          cred = await FirebaseAuth.instance.signInWithCredential(credential);
        }

        final profile = await _fetchOrCreateProfile(cred.user!);
        _currentUser = profile;
        _userController.add(profile);
        return profile;
      } catch (e) {
        debugPrint('Google Sign-In failed: $e');
        rethrow;
      }
    } else {
      // Offline fallback
      final profile = UserProfile(
        uid: 'demo_google_${DateTime.now().millisecondsSinceEpoch % 1000}',
        email: 'player@google.com',
        displayName: 'Google Player',
        createdAt: DateTime.now(),
        isAnonymous: false,
      );
      _currentUser = profile;
      _userController.add(profile);
      return profile;
    }
  }

  Future<UserProfile> signInWithEmail(String email, String password) async {
    if (_isFirebaseAvailable) {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final profile = await _fetchOrCreateProfile(cred.user!);
      _currentUser = profile;
      _userController.add(profile);
      return profile;
    } else {
      // Local fallback
      final profile = UserProfile(
        uid: 'user_${email.hashCode.abs()}',
        email: email,
        displayName: email.split('@').first,
        createdAt: DateTime.now(),
      );
      _currentUser = profile;
      _userController.add(profile);
      return profile;
    }
  }

  Future<UserProfile> registerWithEmail(
    String email,
    String password,
    String displayName,
  ) async {
    if (_isFirebaseAvailable) {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user?.updateDisplayName(displayName);

      final profile = UserProfile(
        uid: cred.user!.uid,
        email: email,
        displayName: displayName,
        createdAt: DateTime.now(),
        isAnonymous: false,
      );
      await FirebaseFirestore.instance
          .collection('users')
          .doc(profile.uid)
          .set(profile.toJson());

      _currentUser = profile;
      _userController.add(profile);
      return profile;
    } else {
      final profile = UserProfile(
        uid: 'user_${email.hashCode.abs()}',
        email: email,
        displayName: displayName.isNotEmpty ? displayName : email.split('@').first,
        createdAt: DateTime.now(),
      );
      _currentUser = profile;
      _userController.add(profile);
      return profile;
    }
  }

  Future<UserProfile> signInAsGuest([String? customName]) async {
    if (_isFirebaseAvailable) {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      if (customName != null && customName.isNotEmpty) {
        await cred.user?.updateDisplayName(customName);
      }
      final profile = await _fetchOrCreateProfile(cred.user!);
      _currentUser = profile;
      _userController.add(profile);
      return profile;
    } else {
      final guestId = 'guest_${DateTime.now().millisecondsSinceEpoch % 10000}';
      final profile = UserProfile(
        uid: guestId,
        email: '',
        displayName: customName ?? 'Guest ${guestId.split('_').last}',
        createdAt: DateTime.now(),
        isAnonymous: true,
      );
      _currentUser = profile;
      _userController.add(profile);
      return profile;
    }
  }

  Future<void> updateProfile({String? displayName, String? avatarUrl}) async {
    if (_currentUser == null) return;

    final updated = _currentUser!.copyWith(
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
    _currentUser = updated;
    _userController.add(updated);

    if (_isFirebaseAvailable) {
      try {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(displayName);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(updated.uid)
            .update(updated.toJson());
      } catch (e) {
        debugPrint('Failed to sync profile update to Firebase: $e');
      }
    }
  }

  Future<void> recordGameResult({
    required String gameId,
    required bool isWin,
    required bool isLoss,
    required bool isDraw,
  }) async {
    if (_currentUser == null) return;

    final currentStats = _currentUser!.statsForGame(gameId);
    final GameStats updatedStats;
    if (isWin) {
      updatedStats = currentStats.recordWin();
    } else if (isLoss) {
      updatedStats = currentStats.recordLoss();
    } else {
      updatedStats = currentStats.recordDraw();
    }

    final newStatsMap = Map<String, GameStats>.from(_currentUser!.stats);
    newStatsMap[gameId] = updatedStats;

    final updatedProfile = _currentUser!.copyWith(stats: newStatsMap);
    _currentUser = updatedProfile;
    _userController.add(updatedProfile);

    if (_isFirebaseAvailable) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(updatedProfile.uid)
            .update({
          'stats.$gameId': updatedStats.toJson(),
        });
      } catch (e) {
        debugPrint('Failed to update stats on Firestore: $e');
      }
    }
  }

  Future<void> signOut() async {
    if (_isFirebaseAvailable) {
      await FirebaseAuth.instance.signOut();
    }
    _currentUser = null;
    _userController.add(null);
  }
}

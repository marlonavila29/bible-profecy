import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'app_error.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String role; // "user", "admin", "master"

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
  });

  bool get isMaster => role == 'master';
  bool get isAdmin => role == 'admin' || role == 'master';
  bool get isUser => true;

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      role: data['role'] ?? 'user',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role,
    };
  }
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String masterEmail = 'marlonavila29@gmail.com';

  AppUser? currentUser;

  /// Guest mode: user skipped login. Can read the app but cannot sync/admin.
  bool isGuestMode = false;

  /// Simple in‑memory log for debugging (can be displayed in a debug screen later)
  final List<String> _errorLog = [];
  void _log(String msg) {
    final timestamp = DateTime.now().toIso8601String();
    _errorLog.add('[$timestamp] $msg');
    debugPrint('[AUTH LOG] $msg');
  }

  List<String> get errorLog => List.unmodifiable(_errorLog);

  User? get firebaseUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  /// True if user can access the app (logged in or guest mode)
  bool get canUseApp => isLoggedIn || isGuestMode;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Load user profile from Firestore
  Future<AppUser?> loadUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        currentUser = AppUser.fromFirestore(doc.data()!, user.uid);
      }
      return currentUser;
    } catch (e) {
      // Non-blocking: just return null if profile load fails
      return null;
    }
  }

  /// Create or update user document in Firestore
  Future<void> _createOrUpdateUser(User user, {String? name}) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      final role = user.email?.toLowerCase() == masterEmail ? 'master' : 'user';
      final userData = {
        'email': user.email ?? '',
        'displayName': name ?? user.displayName ?? user.email?.split('@')[0] ?? '',
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      };
      await docRef.set(userData);
      currentUser = AppUser.fromFirestore(userData, user.uid);
    } else {
      await docRef.update({'lastLogin': FieldValue.serverTimestamp()});
      currentUser = AppUser.fromFirestore(doc.data()!, user.uid);
    }
  }

  /// Register with email & password
  Future<String?> registerWithEmail(String email, String password, String name) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user != null) {
        await credential.user!.updateDisplayName(name.trim());
        await _createOrUpdateUser(credential.user!, name: name.trim());
      }
      return null; // success
    } on FirebaseAuthException catch (e) {
      _log('Register FirebaseAuthException: code=${e.code}, message=${e.message}');
      return AppErrorHandler.translate(e);
    } catch (e, st) {
      _log('Register unknown error: $e\\n$st');
      return AppErrorHandler.translate(e);
    }
  }

  /// Login with email & password
  Future<String?> loginWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user != null) {
        await _createOrUpdateUser(credential.user!);
      }
      return null; // success
    } on FirebaseAuthException catch (e) {
      _log('Login FirebaseAuthException: code=${e.code}, message=${e.message}');
      return AppErrorHandler.translate(e);
    } catch (e, st) {
      _log('Login unknown error: $e\\n$st');
      return AppErrorHandler.translate(e);
    }
  }

  /// Login with Google
  Future<String?> loginWithGoogle() async {
    try {
      if (kIsWeb) {
        // Firebase native popup for web (more stable)
        final googleProvider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(googleProvider);
        if (userCredential.user != null) {
          await _createOrUpdateUser(userCredential.user!);
        }
        return null;
      } else {
        // Mobile (iOS/Android)
        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: '732137771699-ac4meas0eb134o2ci477c4nnjqjbp924.apps.googleusercontent.com',
        );
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) return null; // User cancelled – not an error

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        if (userCredential.user != null) {
          await _createOrUpdateUser(userCredential.user!);
        }
        return null;
      }
    } on FirebaseAuthException catch (e) {
      _log('Google login FirebaseAuthException: code=${e.code}, message=${e.message}');
      return AppErrorHandler.translate(e);
    } catch (e, st) {
      _log('Google login unknown error: $e\n$st');
      return AppErrorHandler.translate(e);
    }
  }

  /// Login with Apple
  Future<String?> loginWithApple() async {
    try {
      if (kIsWeb) {
        // Web: use Firebase OAuthProvider popup
        final appleProvider = OAuthProvider('apple.com')
          ..addScope('email')
          ..addScope('name');
        final userCredential = await _auth.signInWithPopup(appleProvider);
        if (userCredential.user != null) {
          await _createOrUpdateUser(userCredential.user!);
        }
        return null;
      } else {
        // iOS/macOS: use native Apple Sign In
        final rawNonce = _generateNonce();
        final nonce = _sha256ofString(rawNonce);

        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          nonce: nonce,
        );

        final oauthCredential = OAuthProvider('apple.com').credential(
          idToken: appleCredential.identityToken,
          rawNonce: rawNonce,
        );

        final userCredential = await _auth.signInWithCredential(oauthCredential);
        if (userCredential.user != null) {
          // Apple only sends name on first sign-in
          final name = appleCredential.givenName != null
              ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'.trim()
              : null;
          await _createOrUpdateUser(userCredential.user!, name: name);
        }
        return null;
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null; // user cancelled
      _log('Apple login auth error: ${e.code}, ${e.message}');
      return 'Erro ao fazer login com Apple: ${e.message}';
    } on FirebaseAuthException catch (e) {
      _log('Apple login FirebaseAuthException: code=${e.code}, message=${e.message}');
      return AppErrorHandler.translate(e);
    } catch (e, st) {
      _log('Apple login unknown error: $e\n$st');
      return AppErrorHandler.translate(e);
    }
  }

  /// Generate a random nonce for Apple Sign In
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// SHA256 hash of a string
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Logout
  Future<void> logout() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
    currentUser = null;
  }

  /// Update user role (only master can do this)
  Future<void> updateUserRole(String uid, String newRole) async {
    if (currentUser?.isMaster != true) return;
    try {
      await _firestore.collection('users').doc(uid).update({'role': newRole});
    } catch (_) {}
  }

  /// Get all users (for master admin)
  Future<List<AppUser>> getAllUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => AppUser.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

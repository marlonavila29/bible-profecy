import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  User? get firebaseUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Load user profile from Firestore
  Future<AppUser?> loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      currentUser = AppUser.fromFirestore(doc.data()!, user.uid);
    }
    return currentUser;
  }

  /// Create or update user document in Firestore
  Future<void> _createOrUpdateUser(User user, {String? name}) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      // New user: determine role
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
      // Existing user: update last login
      await docRef.update({'lastLogin': FieldValue.serverTimestamp()});
      currentUser = AppUser.fromFirestore(doc.data()!, user.uid);
    }
  }

  /// Register with email & password
  Future<String?> registerWithEmail(String email, String password, String name) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await credential.user!.updateDisplayName(name);
        await _createOrUpdateUser(credential.user!, name: name);
      }
      return null; // success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          return 'A senha é muito fraca. Use pelo menos 6 caracteres.';
        case 'email-already-in-use':
          return 'Este e-mail já está cadastrado.';
        case 'invalid-email':
          return 'E-mail inválido.';
        default:
          return 'Erro ao cadastrar: ${e.message}';
      }
    } catch (e) {
      return 'Erro inesperado: $e';
    }
  }

  /// Login with email & password
  Future<String?> loginWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _createOrUpdateUser(credential.user!);
      }
      return null; // success
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'Usuário não encontrado.';
        case 'wrong-password':
          return 'Senha incorreta.';
        case 'invalid-email':
          return 'E-mail inválido.';
        case 'invalid-credential':
          return 'Credenciais inválidas. Verifique e-mail e senha.';
        default:
          return 'Erro ao entrar: ${e.message}';
      }
    } catch (e) {
      return 'Erro inesperado: $e';
    }
  }

  /// Login with Google
  Future<String?> loginWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return 'Login cancelado.';

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _createOrUpdateUser(userCredential.user!);
      }
      return null; // success
    } catch (e) {
      return 'Erro ao entrar com Google: $e';
    }
  }

  /// Logout
  Future<void> logout() async {
    try { await GoogleSignIn().signOut(); } catch (_) {}
    await _auth.signOut();
    currentUser = null;
  }

  /// Update user role (only master can do this)
  Future<void> updateUserRole(String uid, String newRole) async {
    if (currentUser?.isMaster != true) return;
    await _firestore.collection('users').doc(uid).update({'role': newRole});
  }

  /// Get all users (for master admin)
  Future<List<AppUser>> getAllUsers() async {
    final snapshot = await _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => AppUser.fromFirestore(doc.data(), doc.id))
        .toList();
  }
}

// lib/core/services/auth_service.dart
// -----------------------------------------------------------------------------

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter/foundation.dart';

/// Minimal representation of the signed-in user that widgets can consume
/// without depending on Firebase types.
class LocalUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? role;

  const LocalUser({
    required this.uid,
    this.email,
    this.displayName,
    this.role,
  });

  LocalUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? role,
  }) {
    return LocalUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'role': role,
  };

  @override
  String toString() => 'LocalUser(uid: $uid, email: $email, role: $role)';
}

/// Centralized authentication service.
class AuthService extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  final _auth = fa.FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  LocalUser? _current;
  String? _role;
  List<String> _orgPathUids = const [];

  LocalUser? get currentUser => _current;
  String? get role => _role;
  bool get isSuper {
    final r = _role?.toLowerCase();
    return r == 'admin' || r == 'manager' || r == 'super' || r == 'super_admin';
  }

  static const String _defaultSyntheticDomain =
      'maizemate.local'; // used when the UI sends a username without '@'


  bool _busy = false;

  StreamSubscription<fa.User?>? _sub;


  /// If you have profile data after login, set this list there.
  void setOrgPathUids(Iterable<dynamic>? values) {
    _orgPathUids = values == null
        ? const []
        : values.map((e) => e.toString()).toList(growable: false);
    notifyListeners();
  }

  String get roleOrUnknown => role?.isNotEmpty == true ? role! : 'unknown';

  String? get currentUserId => _current?.uid;
  String get currentUserIdOrAnon => _current?.uid ?? 'anon';

  /// Read-only view of org path uids.
  List<String> get orgPathUidList => List.unmodifiable(_orgPathUids);

  bool get hasProfile => isSuper || (role?.isNotEmpty ?? false);

  String get createdBy => currentUserIdOrAnon;



  // ---------------------------------------------------------------------------
  // Construction / disposal
  // ---------------------------------------------------------------------------
  AuthService() {
    // keep session alive across restarts
    _auth.authStateChanges().listen((u) async {
      if (u == null) {
        _current = null;
        _role = null;
        _orgPathUids = const [];
        notifyListeners();
        print('AuthState: user is currently signed out');
      } else {
        await _loadProfile(u.uid); // sets role + orgPathUids + _current + notifies
        print('AuthState: signed in UID=${u.uid}, email=${u.email}');
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Public getters
  // ---------------------------------------------------------------------------

  /// Last known authenticated user, or null.


  /// Convenience uid getter.
  String? get uid => _current?.uid;

   /// Whether an auth request is in progress.
  bool get isBusy => _busy;

  /// True when a Firebase user is present.
  bool get isLoggedIn => _auth.currentUser != null;

  /// A stream that emits [LocalUser?] whenever the Firebase user changes.
  Stream<LocalUser?> get userStream =>
      _auth.userChanges().asyncMap(_toLocalUser);



  // ---------------------------------------------------------------------------
  // Core actions
  // ---------------------------------------------------------------------------

  /// Log in using either a plain username (e.g. `fic1`) or a full email.
  ///
  /// If [username] does not contain `@`, a synthetic email will be formed:
  ///   `<username>@maizemate.local` (configurable via [syntheticDomain]).
  ///
  /// When [role] is provided, it is written to the Firestore profile doc.
  // in lib/core/services/auth_service.dart
  Future<void> login({String? email, String? username, required String password}) async {
   /* final emailToUse = (email?.isNotEmpty == true)
        ? email!.trim()
        : (username?.isNotEmpty == true)
        ? '${username!.trim().toLowerCase()}@maizemate.local'
        : null;*/

    final emailToUse = () {
      if (username?.toLowerCase() == 'md1') {
        // Special case for MD/Manager — use the Gmail you set
        return 'osnarayanapersonal@gmail.com';
      } else if (email?.isNotEmpty == true) {
        return email!.trim();
      } else if (username?.isNotEmpty == true) {
        // Default behavior for all other users
        return '${username!.trim().toLowerCase()}@maizemate.local';
      } else {
        return null;
      }
    }();

    debugPrint('Login attempt -> username: $username, emailToUse: $emailToUse, password: $password, role: $_role');


    if (emailToUse == null) {
      throw ArgumentError('Provide either email or username');
    }

    try {

      final cred = await _auth.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );

      await _loadProfile(cred.user!.uid); // <- sets role + notifies

    } on fa.FirebaseAuthException catch (e) {
      // surface an exact message upward
      throw Exception(_friendlyAuthMessage(e));
    } catch (e) {
      throw Exception('Login failed. Please try again.');
    }


  }

  String _friendlyAuthMessage(fa.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'invalid-email':
      case 'wrong-password':
        return 'Invalid username or password';
      case 'user-disabled':
        return 'This user is disabled';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      default:
        return 'Login error: ${e.code}';
    }
  }



  /// Sign out of Firebase.
  Future<void> logout() async {
    await _auth.signOut();
    // authStateChanges listener will clear + notify
  }

  /// Alias kept for older call sites.
  Future<void> signOut() => logout();

  /// Explicitly refresh the Firebase user and cached role/profile.
  Future<void> refreshUser() async {
    final u = _auth.currentUser;
    if (u != null) {
      await u.reload();
      await _loadProfile(u.uid);
      _setCurrent(await _toLocalUser(u));
    } else {
      _setCurrent(null);
    }
  }

  /// Persist a role for the current user in Firestore and notify listeners.
  Future<void> setRole(String role) async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _db.collection('users').doc(u.uid).set(
      {
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
        'email': u.email,
        'displayName': u.displayName,
      },
      SetOptions(merge: true),
    );
    _role = role;
    _setCurrent(_current?.copyWith(role: role));
    notifyListeners();
  }

  /// Read the ID token and return custom claims if available.
  /// Useful when backend sets claims like `{ role: 'fic' }`.
  Future<Map<String, dynamic>?> getIdTokenClaims() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final idToken = await u.getIdTokenResult(true);
    return idToken.claims;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Normalizes a `username` to an email if needed.
  static String _normalizeToEmail(String username, String domain) {
    final trimmed = username.trim();
    if (trimmed.contains('@')) return trimmed;
    return '$trimmed@$domain';
  }

  /// Ensure the Firestore profile doc exists. Optionally set [roleOverride].
  Future<void> _ensureProfileDoc(
      fa.User fbUser, {
        String? roleOverride,
      }) async {
    final ref = _db.collection('users').doc(fbUser.uid);
    final snap = await ref.get();
    final data = <String, dynamic>{
      'email': fbUser.email,
      'displayName': fbUser.displayName ?? fbUser.email,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (roleOverride != null && roleOverride.isNotEmpty) {
      data['role'] = roleOverride;
    }
    if (snap.exists) {
      // Merge to avoid clobbering existing fields.
      await ref.set(data, SetOptions(merge: true));
    } else {
      await ref.set(data);
    }
  }

  /// Loads profile (currently only the `role`) from Firestore.
  Future<void> _loadProfile(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    if (!snap.exists) {
      // choose: create default doc or throw
      throw StateError('No profile for uid $uid');
    }
    final data = snap.data()!;
    _role = (data['role'] as String?)?.trim();
    _orgPathUids = (data['orgPathUids'] as List?)
        ?.map((e) => e.toString())
        .toList(growable: false) ??
        const <String>[];

    _current = LocalUser(
      uid: uid,
      displayName: data['displayName'] as String?,
      // add username/role fields here only if your LocalUser defines them
    );

    notifyListeners();
  }

  /// Convert a Firebase user to our [LocalUser].
  Future<LocalUser?> _toLocalUser(fa.User? u) async {
    if (u == null) return null;
    final roleFromDb = await _getRoleFromDb(u.uid);
    return LocalUser(
      uid: u.uid,
      email: u.email,
      displayName: u.displayName ?? u.email,
      role: roleFromDb,
    );
  }

  Future<String?> _getRoleFromDb(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return (doc.data() ?? const {})['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Handle Firebase user stream updates.
  Future<void> _onFirebaseUserChanged(fa.User? u) async {
    if (u == null) {
      _role = null;
      _setCurrent(null);
      return;
    }
    await _loadProfile(u.uid);
    _setCurrent(await _toLocalUser(u));
  }

  void _setCurrent(LocalUser? u) {
    _current = u;
    notifyListeners();
  }

  void _setBusy(bool v) {
    _busy = v;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Optional helpers – not required by routing, but kept for feature parity.
  // ---------------------------------------------------------------------------

  /// Create a new account with email & password. Rarely used in this app,
  /// but some older parts referenced `register`/`signUp`. Return uid on success.
  Future<String?> register({
    required String email,
    required String password,
    String? displayName,
    String? role,
  }) async {
    _setBusy(true);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (displayName != null && displayName.isNotEmpty) {
        await cred.user?.updateDisplayName(displayName);
      }
      if (cred.user != null) {
        await _ensureProfileDoc(cred.user!, roleOverride: role);
        await _loadProfile(cred.user!.uid);
        _setCurrent(await _toLocalUser(cred.user));
      }
      _setBusy(false);
      return cred.user?.uid;
    } on fa.FirebaseAuthException catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AuthService.register FirebaseAuthException: ${e.code} – ${e.message}\n$st');
      }
      _setBusy(false);
      return null;
    } catch (e) {
      _setBusy(false);
      return null;
    }
  }

  /// Update arbitrary fields in the profile document.
  Future<void> updateProfile(Map<String, dynamic> data) async {
    final u = _auth.currentUser;
    if (u == null) return;
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('users').doc(u.uid).set(data, SetOptions(merge: true));
    if (data.containsKey('role')) {
      final newRole = data['role'] as String?;
      _role = newRole;
      _setCurrent(_current?.copyWith(role: newRole));
    }
  }

  /// Permanently delete the current account (be careful!).
  Future<void> deleteAccount() async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _db.collection('users').doc(u.uid).delete();
    await u.delete();
    _setCurrent(null);
  }
}

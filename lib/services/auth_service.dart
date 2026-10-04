import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

/// Authentication + current-account operations.
class AuthService {
  final SupabaseClient _db = Supabase.instance.client;

  Session? get currentSession => _db.auth.currentSession;
  User? get currentUser => _db.auth.currentUser;
  Stream<AuthState> get onAuthStateChange => _db.auth.onAuthStateChange;

  /// Ensures a profile row exists for the signed-in user (signup safety net).
  Future<Profile?> ensureProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final existing = await _db
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (existing != null) return Profile.fromMap(existing);
    final inserted = await _db
        .from('profiles')
        .insert({
          'id': user.id,
          'email': user.email ?? '',
          'full_name': user.userMetadata?['full_name'] ?? '',
        })
        .select()
        .single();
    return Profile.fromMap(inserted);
  }

  Future<Profile> signIn(String email, String password) async {
    await _db.auth.signInWithPassword(email: email, password: password);
    final profile = await ensureProfile();
    if (profile != null && !profile.isActive) {
      await signOut();
      throw const AuthException(
          'This account has been deactivated. Contact an administrator.');
    }
    return profile!;
  }

  Future<Profile> register({
    required String email,
    required String password,
    required String fullName,
    String? department,
    String? institution,
  }) async {
    final res = await _db.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'department': department,
        'institution': institution,
      },
    );
    if (res.user == null) {
      throw const AuthException('Registration failed.');
    }
    // Profile is normally created by the DB trigger; fall back to manual insert.
    return (await ensureProfile())!;
  }

  Future<void> signOut() => _db.auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _db.auth.resetPasswordForEmail(email);

  Future<void> updatePassword(String newPassword) =>
      _db.auth.updateUser(UserAttributes(password: newPassword));

  Future<void> updateOwnProfile({
    required String fullName,
    String? department,
    String? institution,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await _db.from('profiles').update({
      'full_name': fullName,
      'department': department,
      'institution': institution,
    }).eq('id', uid);
  }
}

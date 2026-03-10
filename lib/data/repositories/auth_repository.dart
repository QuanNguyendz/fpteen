import 'package:fpteen/core/errors/app_exception.dart';
import 'package:fpteen/data/models/user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class AuthRepository {
  AuthRepository(this._supabase);

  final sb.SupabaseClient _supabase;

  Stream<sb.AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  sb.Session? get currentSession => _supabase.auth.currentSession;

  sb.User? get currentAuthUser => _supabase.auth.currentUser;

  Future<UserModel> fetchProfile(String userId) async {
    try {
      final data = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .single();
      return UserModel.fromJson(data);
    } catch (e) {
      throw AppAuthException(parseSupabaseError(e));
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _supabase.auth
          .signInWithPassword(email: email, password: password);
    } catch (e) {
      throw AppAuthException(parseSupabaseError(e));
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
  }) async {
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'phone': phone, 'role': role},
      );
    } catch (e) {
      throw AppAuthException(parseSupabaseError(e));
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}



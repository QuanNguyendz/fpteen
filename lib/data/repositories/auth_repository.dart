import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:fpteen/core/constants/app_constants.dart';
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

  // GOOGLE SIGN-IN (WEB OAUTH - KHÔNG CẦN SHA-1 CỦA TỪNG MÁY)
  Future<void> signInWithGoogle() async {
    try {
      debugPrint('🟡 ===== BẮT ĐẦU ĐĂNG NHẬP GOOGLE (WEB OAUTH) =====');

      final success = await _supabase.auth.signInWithOAuth(
        sb.OAuthProvider.google,
        redirectTo: 'io.supabase.fpteen://login-callback',
        queryParams: {
          'access_type': 'offline',
          'prompt': 'consent',
        },
      );

      if (success) {
        debugPrint('🟢 ĐÃ MỞ TRÌNH DUYỆT ĐĂNG NHẬP GOOGLE THÀNH CÔNG!');
      } else {
        throw 'Không thể mở trình duyệt đăng nhập Google.';
      }

    } on PlatformException catch (e) {
      debugPrint('🔴 ===== LỖI PLATFORM EXCEPTION =====');
      debugPrint('🔴 Code: ${e.code}');
      debugPrint('🔴 Message: ${e.message}');
      throw AppAuthException('Google Sign-In thất bại: ${e.message}');
    } catch (e) {
      debugPrint('🔴 ===== LỖI KHÔNG XÁC ĐỊNH =====');
      debugPrint('🔴 $e');
      throw AppAuthException(e.toString());
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
        data: {
          'full_name': fullName,
          'phone': phone,
          'role': role,
          'created_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      throw AppAuthException(parseSupabaseError(e));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      throw AppAuthException(parseSupabaseError(e));
    }
  }

  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        sb.UserAttributes(
          password: newPassword,
        ),
      );
    } catch (e) {
      throw AppAuthException(parseSupabaseError(e));
    }
  }

  Future<void> signOut() async {
    try {
      debugPrint('🟡 Đang đăng xuất...');

      // Bỏ qua đăng xuất Google vì xử lý qua trình duyệt
      // Chỉ đăng xuất khỏi Supabase
      await _supabase.auth.signOut();
      debugPrint('🟢 Đã đăng xuất Supabase');

    } catch (e) {
      debugPrint('🔴 Lỗi đăng xuất: $e');
      throw AppAuthException('Đăng xuất thất bại: $e');
    }
  }

  String parseSupabaseError(dynamic error) {
    if (error is sb.AuthException) {
      switch (error.message) {
        case 'Invalid login credentials':
          return 'Email hoặc mật khẩu không đúng';
        case 'Email not confirmed':
          return 'Email chưa được xác nhận';
        case 'User already registered':
          return 'Email đã được đăng ký';
        default:
          return error.message;
      }
    }
    return error.toString();
  }
}

import 'package:flutter/services.dart';
import 'package:fpteen/core/constants/app_constants.dart';
import 'package:fpteen/core/errors/app_exception.dart';
import 'package:fpteen/data/models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  // GOOGLE SIGN-IN
  Future<void> signInWithGoogle() async {
    try {
      const webClientId = AppConstants.googleWebClientId;

      print('🟡 ===== BẮT ĐẦU ĐĂNG NHẬP GOOGLE (WEB OAUTH) =====');
      print('🟡 Web Client ID: $webClientId');

      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: webClientId,
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        print('🟡 Người dùng đã hủy đăng nhập');
        return;
      }

      print('🟢 ĐĂNG NHẬP GOOGLE THÀNH CÔNG');

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'Không tìm thấy ID Token từ Google. Vui lòng thử lại.';
      }

      await _supabase.auth.signInWithIdToken(
        provider: sb.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      print('🟢 ĐĂNG NHẬP SUPABASE THÀNH CÔNG!');

    } on PlatformException catch (e) {
      print('🔴 ===== LỖI PLATFORM EXCEPTION =====');
      print('🔴 Code: ${e.code}');
      print('🔴 Message: ${e.message}');
      throw AppAuthException('Google Sign-In thất bại: ${e.message}');
    } catch (e) {
      print('🔴 ===== LỖI KHÔNG XÁC ĐỊNH =====');
      print('🔴 $e');
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
      print('🟡 Đang đăng xuất...');

      // Đăng xuất khỏi Google
      await GoogleSignIn().signOut();
      print('🟢 Đã đăng xuất Google');

      // Đăng xuất khỏi Supabase
      await _supabase.auth.signOut();
      print('🟢 Đã đăng xuất Supabase');

    } catch (e) {
      print('🔴 Lỗi đăng xuất: $e');
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

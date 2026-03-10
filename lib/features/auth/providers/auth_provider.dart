import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpteen/data/models/user_model.dart';
import 'package:fpteen/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Supabase client provider ──────────────────────────────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ── Auth repository provider ──────────────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

// ── Auth state ────────────────────────────────────────────────────────────────
class AuthAppState {
  const AuthAppState({
    this.user,
    this.isLoading = true,
    this.error,
  });

  final UserModel? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthAppState copyWith({
    UserModel? user,
    bool clearUser = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      AuthAppState(
        user: clearUser ? null : user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : error ?? this.error,
      );
}

// ── Auth notifier ─────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthAppState> {
  AuthNotifier(this._repo) : super(const AuthAppState()) {
    _init();
  }

  final AuthRepository _repo;
  StreamSubscription<AuthState>? _authSub;

  void _init() {
    final session = _repo.currentSession;
    if (session != null) {
      _loadProfile(session.user.id);
    } else {
      state = const AuthAppState(isLoading: false);
    }

    _authSub = _repo.authStateChanges.listen((data) async {
      if (data.event == AuthChangeEvent.signedIn) {
        final uid = data.session?.user.id;
        if (uid != null) await _loadProfile(uid);
      } else if (data.event == AuthChangeEvent.signedOut) {
        state = const AuthAppState(isLoading: false);
      }
    });
  }

  Future<void> _loadProfile(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _repo.fetchProfile(userId);
      state = AuthAppState(user: profile, isLoading: false);
    } catch (_) {
      state = const AuthAppState(isLoading: false);
    }
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.signIn(email: email, password: password);
      // Profile loaded via _authSub listener
    } catch (e) {
      state = AuthAppState(isLoading: false, error: e.toString());
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: role,
      );
      // Profile created by trigger, loaded via _authSub listener
    } catch (e) {
      state = AuthAppState(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthAppState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});



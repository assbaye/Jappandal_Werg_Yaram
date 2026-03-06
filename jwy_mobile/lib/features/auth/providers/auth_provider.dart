import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/graphql/client.dart';
import '../../../core/graphql/queries/auth_queries.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class AuthState {
  final String? token;
  final Map<String, dynamic>? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.token,
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => token != null && user != null;

  AuthState copyWith({
    String? token,
    Map<String, dynamic>? user,
    bool? isLoading,
    String? error,
    bool clearToken = false,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      token: clearToken ? null : (token ?? this.token),
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  static const _tokenKey = 'jwy_jwt_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthNotifier() : super(const AuthState());

  /// Appelé au démarrage de l'app pour restaurer la session.
  Future<void> autoLogin() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null) {
        state = state.copyWith(isLoading: false, clearToken: true, clearUser: true);
        return;
      }
      final client = buildGraphQLClient(token);
      final result = await client.query(
        QueryOptions(document: gql(meQuery)),
      );
      if (result.hasException || result.data?['me'] == null) {
        await _storage.delete(key: _tokenKey);
        state = state.copyWith(isLoading: false, clearToken: true, clearUser: true);
        return;
      }
      state = AuthState(
        token: token,
        user: result.data!['me'] as Map<String, dynamic>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, clearToken: true, clearUser: true);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final client = buildGraphQLClient(null);
      final result = await client.mutate(
        MutationOptions(
          document: gql(loginMutation),
          variables: {'email': email, 'password': password},
        ),
      );
      if (result.hasException) {
        final msg = result.exception?.graphqlErrors.firstOrNull?.message
            ?? 'Identifiants incorrects';
        state = state.copyWith(isLoading: false, error: msg);
        return false;
      }
      final data = result.data!['login'] as Map<String, dynamic>;
      final token = data['access_token'] as String;
      await _storage.write(key: _tokenKey, value: token);
      state = AuthState(
        token: token,
        user: data['user'] as Map<String, dynamic>,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur de connexion');
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> input) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final client = buildGraphQLClient(null);
      final result = await client.mutate(
        MutationOptions(
          document: gql(registerMutation),
          variables: {'input': input},
        ),
      );
      if (result.hasException) {
        final msg = result.exception?.graphqlErrors.firstOrNull?.message
            ?? 'Erreur lors de l\'inscription';
        state = state.copyWith(isLoading: false, error: msg);
        return false;
      }
      final data = result.data!['register'] as Map<String, dynamic>;
      final token = data['access_token'] as String;
      await _storage.write(key: _tokenKey, value: token);
      state = AuthState(
        token: token,
        user: data['user'] as Map<String, dynamic>,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur de connexion');
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    state = const AuthState();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Provider du client GraphQL (se met à jour quand le token change).
final graphQLClientProvider = Provider<GraphQLClient>((ref) {
  final token = ref.watch(authProvider).token;
  return buildGraphQLClient(token);
});

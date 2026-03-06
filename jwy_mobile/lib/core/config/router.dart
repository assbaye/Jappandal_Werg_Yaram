import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/patient/screens/dashboard_screen.dart';
import '../../features/patient/screens/consultations_screen.dart';
import '../../features/patient/screens/pharmacies_screen.dart';
import '../../features/consultation/screens/nouvelle_consultation_screen.dart';
import '../../features/consultation/screens/teleconsultation_screen.dart';
import '../../features/paiement/screens/paiement_screen.dart';
import '../../features/paiement/screens/paiement_webview_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: authState.isAuthenticated ? '/' : '/auth/login',
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isAuthRoute) return '/auth/login';
      if (isLoggedIn && isAuthRoute) return '/';
      return null;
    },
    routes: [
      // Auth
      GoRoute(
        path: '/auth/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/auth/register',
        builder: (_, __) => const RegisterScreen(),
      ),

      // Shell patient (avec BottomNavigationBar)
      ShellRoute(
        builder: (context, state, child) => PatientShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const DashboardHomeTab(),
          ),
          GoRoute(
            path: '/consultations',
            builder: (_, __) => const ConsultationsScreen(),
          ),
          GoRoute(
            path: '/pharmacies',
            builder: (_, __) => const PharmaciesScreen(),
          ),
        ],
      ),

      // Hors shell (plein écran)
      GoRoute(
        path: '/consultations/nouvelle',
        builder: (_, __) => const NouvelleConsultationScreen(),
      ),
      GoRoute(
        path: '/consultations/:id/video',
        builder: (_, state) => TeleConsultationScreen(
          consultationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/paiement/:consultationId',
        builder: (_, state) => PaiementScreen(
          consultationId: state.pathParameters['consultationId']!,
        ),
      ),
      GoRoute(
        path: '/paiement/webview',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return PaiementWebviewScreen(
            redirectUrl: extra['redirect_url'] as String,
            transactionId: extra['transaction_id'] as String,
          );
        },
      ),
    ],
  );
});

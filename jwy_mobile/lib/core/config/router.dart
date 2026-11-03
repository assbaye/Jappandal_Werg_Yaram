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
import '../../features/medecin/screens/dashboard_medecin_screen.dart';
import '../../features/consultation/screens/consultation_detail_screen.dart';
import '../../features/medecin/screens/nouvelle_ordonnance_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/rendez_vous/screens/rendez_vous_screen.dart';
import '../../features/rendez_vous/screens/nouveau_rendez_vous_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final role = authState.user?['role'] as String?;

  String homeForRole(String? r) => switch (r) {
        'medecin' => '/medecin',
        'pharmacien' || 'admin' => '/acces-restreint',
        _ => '/',
      };

  return GoRouter(
    initialLocation: authState.isAuthenticated ? homeForRole(role) : '/auth/login',
    redirect: (BuildContext context, GoRouterState state) {
      final isLoggedIn = authState.isAuthenticated;
      final loc = state.matchedLocation;
      final isAuthRoute = loc.startsWith('/auth');

      if (!isLoggedIn && !isAuthRoute) return '/auth/login';
      if (isLoggedIn && isAuthRoute) return homeForRole(role);

      // Cloisonnement par rôle
      if (isLoggedIn && role == 'patient' && loc.startsWith('/medecin')) return '/';
      if (isLoggedIn && role == 'medecin') {
        final isMedecinRoute = loc.startsWith('/medecin') ||
            loc.startsWith('/consultations/') ||
            loc == '/notifications' ||
            loc == '/acces-restreint';
        if (!isMedecinRoute) return '/medecin';
      }

      return null;
    },
    routes: [
      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(path: '/auth/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/auth/register', builder: (_, __) => const RegisterScreen()),

      // ── Accès restreint (admin / pharmacien) ──────────────────────────────
      GoRoute(path: '/acces-restreint', builder: (_, __) => const AccesRestreintScreen()),

      // ── Shell patient ─────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => PatientShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardHomeTab()),
          GoRoute(path: '/consultations', builder: (_, __) => const ConsultationsScreen()),
          GoRoute(path: '/rendez-vous', builder: (_, __) => const RendezVousScreen()),
          GoRoute(path: '/pharmacies', builder: (_, __) => const PharmaciesScreen()),
        ],
      ),

      // ── Shell médecin ─────────────────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => MedecinShell(child: child),
        routes: [
          GoRoute(path: '/medecin', builder: (_, __) => const DashboardMedecinTab()),
          GoRoute(path: '/medecin/consultations', builder: (_, __) => const ConsultationsMedecinScreen()),
          GoRoute(path: '/medecin/rendez-vous', builder: (_, __) => const RendezVousScreen()),
        ],
      ),

      // ── Hors shell (plein écran) ──────────────────────────────────────────
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/rendez-vous/nouveau', builder: (_, __) => const NouveauRendezVousScreen()),
      GoRoute(
        path: '/consultations/nouvelle',
        builder: (_, __) => const NouvelleConsultationScreen(),
      ),
      GoRoute(
        path: '/consultations/:id',
        builder: (_, state) => ConsultationDetailScreen(
          consultationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/consultations/:id/video',
        builder: (_, state) => TeleConsultationScreen(
          consultationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/consultations/:id/ordonnance',
        builder: (_, state) => NouvelleOrdonnanceScreen(
          consultationId: state.pathParameters['id']!,
          patientId: state.uri.queryParameters['patient'] ?? '',
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

// ─── Écran accès restreint (admin / pharmacien) ───────────────────────────────

class AccesRestreintScreen extends ConsumerWidget {
  const AccesRestreintScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).user?['role'] as String? ?? '';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.computer, color: Colors.orange, size: 48),
                ),
                const SizedBox(height: 24),
                Text(
                  role == 'admin' ? 'Interface administrateur' : 'Interface pharmacien',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Cette interface est disponible uniquement sur le portail web.\nVeuillez vous connecter depuis un navigateur.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Se déconnecter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/medecin_queries.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/screens/notifications_screen.dart';

// ─── Shell médecin (BottomNav) ────────────────────────────────────────────────

class MedecinShell extends StatelessWidget {
  final Widget child;
  const MedecinShell({super.key, required this.child});

  static const _routes = ['/medecin', '/medecin/consultations', '/medecin/rendez-vous'];

  @override
  Widget build(BuildContext context) {
    // L'onglet actif suit l'URL (y compris après une navigation depuis une notification)
    final index = _routes.indexOf(GoRouterState.of(context).matchedLocation);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index < 0 ? 0 : index,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: (i) => context.go(_routes[i]),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Accueil'),
          BottomNavigationBarItem(
              icon: Icon(Icons.medical_services_outlined),
              activeIcon: Icon(Icons.medical_services),
              label: 'Consultations'),
          BottomNavigationBarItem(
              icon: Icon(Icons.event_outlined),
              activeIcon: Icon(Icons.event),
              label: 'Rendez-vous'),
        ],
      ),
    );
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final _medecinInfoProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final client = ref.read(graphQLClientProvider);
  final result = await client.query(
    QueryOptions(
        document: gql(medecinInfoQuery), fetchPolicy: FetchPolicy.networkOnly),
  );
  if (result.hasException) throw result.exception!;
  return result.data?['me']?['medecin'] as Map<String, dynamic>?;
});

final _consultationsMedecinProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final client = ref.read(graphQLClientProvider);
  final result = await client.query(
    QueryOptions(
      document: gql(mesConsultationsMedecinQuery),
      variables: const {'first': 20, 'page': 1},
      fetchPolicy: FetchPolicy.networkOnly,
    ),
  );
  if (result.hasException) throw result.exception!;
  return (result.data?['mesConsultations']?['data'] as List<dynamic>?) ?? [];
});

// ─── Dashboard accueil médecin ─────────────────────────────────────────────

class DashboardMedecinTab extends ConsumerWidget {
  const DashboardMedecinTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final medecinAsync = ref.watch(_medecinInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('JWY — Médecin'),
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => _showProfile(context, ref),
          ),
        ],
      ),
      body: medecinAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (medecin) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(_medecinInfoProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MedecinWelcomeCard(medecin: medecin, user: user),
                const SizedBox(height: 20),
                _DisponibiliteCard(medecin: medecin),
                const SizedBox(height: 20),
                const Text('Consultations récentes',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _RecentConsultations(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showProfile(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _MedecinProfileSheet(ref: ref),
    );
  }
}

class _MedecinWelcomeCard extends StatelessWidget {
  final Map<String, dynamic>? medecin;
  final Map<String, dynamic>? user;
  const _MedecinWelcomeCard({required this.medecin, required this.user});

  @override
  Widget build(BuildContext context) {
    final prenom = medecin?['prenom'] ?? user?['email'] ?? 'Médecin';
    final specialite = medecin?['specialite'] as String? ?? '';
    final note = (medecin?['note_moyenne'] as num?)?.toDouble() ?? 0.0;
    final nbConsultations = medecin?['nombre_consultations'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, color: Colors.white, size: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dr. $prenom',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Text(specialite,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatChip(
                  icon: Icons.star,
                  value: note.toStringAsFixed(1),
                  label: 'Note'),
              const SizedBox(width: 12),
              _StatChip(
                  icon: Icons.medical_services,
                  value: '$nbConsultations',
                  label: 'Consultations'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatChip(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white24, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text('$value  $label',
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class _DisponibiliteCard extends ConsumerWidget {
  final Map<String, dynamic>? medecin;
  const _DisponibiliteCard({required this.medecin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disponible = medecin?['disponible_maintenant'] as bool? ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (disponible ? AppTheme.successColor : Colors.grey)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                disponible ? Icons.wifi_tethering : Icons.wifi_tethering_off,
                color: disponible ? AppTheme.successColor : Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    disponible ? 'Disponible maintenant' : 'Non disponible',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          disponible ? AppTheme.successColor : Colors.grey[700],
                    ),
                  ),
                  Text(
                    disponible
                        ? 'Les patients peuvent vous contacter'
                        : 'Vous n\'apparaissez pas dans les recherches',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Switch(
              value: disponible,
              activeThumbColor: AppTheme.successColor,
              onChanged: (_) => _toggle(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    try {
      final client = ref.read(graphQLClientProvider);
      final result = await client.mutate(
        MutationOptions(document: gql(toggleDisponibiliteMutation)),
      );
      if (!result.hasException) {
        ref.invalidate(_medecinInfoProvider);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erreur lors du changement de disponibilité')),
          );
        }
      }
    } catch (_) {}
  }
}

class _RecentConsultations extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consultationsAsync = ref.watch(_consultationsMedecinProvider);

    return consultationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erreur: $e',
          style: const TextStyle(color: AppTheme.errorColor)),
      data: (consultations) {
        if (consultations.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aucune consultation pour le moment',
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }
        final recent = consultations.take(3).toList();
        return Column(
          children: [
            ...recent.map((c) => _ConsultationMedecinCard(
                consultation: c as Map<String, dynamic>)),
            if (consultations.length > 3)
              TextButton(
                onPressed: () => context.go('/medecin/consultations'),
                child: const Text('Voir toutes les consultations'),
              ),
          ],
        );
      },
    );
  }
}

// ─── Écran consultations médecin ──────────────────────────────────────────────

class ConsultationsMedecinScreen extends ConsumerWidget {
  const ConsultationsMedecinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consultationsAsync = ref.watch(_consultationsMedecinProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes consultations')),
      body: consultationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text(e.toString()),
              TextButton(
                onPressed: () => ref.invalidate(_consultationsMedecinProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (consultations) {
          if (consultations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.medical_services_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aucune consultation',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(_consultationsMedecinProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: consultations.length,
              itemBuilder: (_, i) => _ConsultationMedecinCard(
                consultation: consultations[i] as Map<String, dynamic>,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Card consultation (vue médecin) ─────────────────────────────────────────

class _ConsultationMedecinCard extends ConsumerWidget {
  final Map<String, dynamic> consultation;
  const _ConsultationMedecinCard({required this.consultation});

  String _statutLabel(String s) => switch (s) {
        'EN_ATTENTE' => 'À traiter',
        'CONFIRMEE' => 'Acceptée',
        'EN_COURS' => 'En cours',
        'TERMINEE' => 'Terminée',
        'ANNULEE' => 'Annulée',
        _ => s,
      };

  Color _statutColor(String s) => switch (s) {
        'EN_ATTENTE' => AppTheme.warningColor,
        'CONFIRMEE' => AppTheme.secondary,
        'EN_COURS' => AppTheme.primary,
        'TERMINEE' => Colors.grey,
        'ANNULEE' => AppTheme.errorColor,
        _ => Colors.grey,
      };

  IconData _typeIcon(String t) => switch (t) {
        'VIDEO' => Icons.video_call,
        'CHAT' => Icons.chat,
        'PHYSIQUE' => Icons.local_hospital,
        _ => Icons.medical_services,
      };

  String _formatDate(String? d) {
    if (d == null) return '';
    try {
      return DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR')
          .format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patient = consultation['patient'] as Map<String, dynamic>?;
    final statut = consultation['statut'] as String? ?? '';
    final type = consultation['type_consultation'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await context.push('/consultations/${consultation['id']}');
          // Le statut a pu changer (acceptée, terminée…)
          ref.invalidate(_consultationsMedecinProvider);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_typeIcon(type), color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${patient?['prenom'] ?? ''} ${patient?['nom'] ?? ''}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statutColor(statut).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statutLabel(statut),
                      style: TextStyle(
                          color: _statutColor(statut),
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(_formatDate(consultation['created_at'] as String?),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              if (consultation['symptomes'] != null) ...[
                const SizedBox(height: 6),
                Text(
                  consultation['symptomes'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
              if (type == 'VIDEO' &&
                  (statut == 'CONFIRMEE' || statut == 'EN_COURS')) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.video_call),
                    label: const Text('Démarrer la téléconsultation'),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 40)),
                    onPressed: () => context
                        .push('/consultations/${consultation['id']}/video'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Profile sheet médecin ────────────────────────────────────────────────────

class _MedecinProfileSheet extends StatelessWidget {
  final WidgetRef ref;
  const _MedecinProfileSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final medecin = user?['medecin'] as Map<String, dynamic>?;
    final nom = medecin != null
        ? 'Dr. ${medecin['prenom'] ?? ''} ${medecin['nom'] ?? ''}'.trim()
        : (user?['email'] ?? '');

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(radius: 32, child: Icon(Icons.person, size: 32)),
          const SizedBox(height: 12),
          Text(nom,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (medecin?['specialite'] != null)
            Text(medecin!['specialite'] as String,
                style: TextStyle(color: Colors.grey[600])),
          Text(user?['email'] ?? '',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: AppTheme.primary),
            title: const Text('Modifier mon profil'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final router = GoRouter.of(context); // le contexte de la fiche disparaît au pop
              Navigator.pop(context);
              await router.push('/profil');
              ref.invalidate(_medecinInfoProvider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.errorColor),
            title: const Text('Se déconnecter',
                style: TextStyle(color: AppTheme.errorColor)),
            onTap: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}

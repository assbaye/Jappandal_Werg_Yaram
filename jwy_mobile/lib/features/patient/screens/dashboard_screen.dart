import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ─── Shell (BottomNav) ────────────────────────────────────────────────────────

class PatientShell extends StatefulWidget {
  final Widget child;
  const PatientShell({super.key, required this.child});

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _currentIndex = 0;

  static const _routes = ['/', '/consultations', '/pharmacies'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _currentIndex = index);
          context.go(_routes[index]);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.medical_services_outlined), activeIcon: Icon(Icons.medical_services), label: 'Consultations'),
          BottomNavigationBarItem(icon: Icon(Icons.local_pharmacy_outlined), activeIcon: Icon(Icons.local_pharmacy), label: 'Pharmacies'),
        ],
      ),
    );
  }
}

// ─── Onglet Accueil ───────────────────────────────────────────────────────────

class DashboardHomeTab extends ConsumerWidget {
  const DashboardHomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final patient = user?['patient'] as Map<String, dynamic>?;
    final prenom = patient?['prenom'] ?? user?['email'] ?? 'Utilisateur';

    return Scaffold(
      appBar: AppBar(
        title: const Text('JWY Santé'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => _showProfile(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Salutation
              _WelcomeCard(prenom: prenom),
              const SizedBox(height: 20),

              // Actions rapides
              const Text('Actions rapides', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _QuickActionsGrid(),
              const SizedBox(height: 24),

              // Prochaine consultation
              const Text('Ma prochaine consultation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _NextConsultationCard(),
              const SizedBox(height: 24),

              // Accès santé urgence
              _UrgenceCard(),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfile(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _ProfileSheet(ref: ref),
    );
  }
}

// ─── Widgets du Dashboard ─────────────────────────────────────────────────────

class _WelcomeCard extends StatelessWidget {
  final String prenom;
  const _WelcomeCard({required this.prenom});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Bonjour' : hour < 18 ? 'Bon après-midi' : 'Bonsoir';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, Color(0xFF4CAF50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, $prenom !',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Comment vous sentez-vous aujourd\'hui ?',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const Icon(Icons.health_and_safety, color: Colors.white, size: 48),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(icon: Icons.video_call, label: 'Téléconsultation', color: AppTheme.secondary, route: '/consultations/nouvelle'),
      _QuickAction(icon: Icons.calendar_month, label: 'Rendez-vous', color: const Color(0xFF7B1FA2), route: '/consultations'),
      _QuickAction(icon: Icons.local_pharmacy, label: 'Pharmacies', color: const Color(0xFFF57C00), route: '/pharmacies'),
      _QuickAction(icon: Icons.folder_shared, label: 'Mon dossier', color: const Color(0xFF00838F), route: '/consultations'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      children: actions.map((a) => _QuickActionCard(action: a)).toList(),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final String route;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.route});
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go(action.route),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(action.icon, color: action.color, size: 32),
              const SizedBox(height: 8),
              Text(
                action.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextConsultationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Placeholder — sera remplacé par une vraie query Riverpod
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Dr. Diallo - Médecine générale', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Téléconsultation', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      const Text('Demain, 10h00', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                    ],
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(70, 36)),
              onPressed: () => context.go('/consultations'),
              child: const Text('Voir', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UrgenceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.emergency, color: AppTheme.errorColor, size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Urgence médicale ?', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
                Text('Consultez un médecin disponible maintenant', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              minimumSize: const Size(70, 36),
            ),
            onPressed: () => context.go('/consultations/nouvelle'),
            child: const Text('SOS', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

String _buildDisplayName(Map<String, dynamic>? patient, Map<String, dynamic>? user) {
  final prenom = patient?['prenom'] as String? ?? '';
  final nom = patient?['nom'] as String? ?? '';
  final fullName = '$prenom $nom'.trim();
  return fullName.isEmpty ? (user?['email'] as String? ?? '') : fullName;
}

class _ProfileSheet extends StatelessWidget {
  final WidgetRef ref;
  const _ProfileSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final patient = user?['patient'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircleAvatar(radius: 32, child: Icon(Icons.person, size: 32)),
          const SizedBox(height: 12),
          Text(
            _buildDisplayName(patient, user),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(user?['email'] ?? '', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.errorColor),
            title: const Text('Se déconnecter', style: TextStyle(color: AppTheme.errorColor)),
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

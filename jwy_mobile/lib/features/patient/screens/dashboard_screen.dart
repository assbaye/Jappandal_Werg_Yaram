import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../notifications/screens/notifications_screen.dart';

// ─── Shell patient ────────────────────────────────────────────────────────────

class PatientShell extends StatelessWidget {
  final Widget child;
  const PatientShell({super.key, required this.child});

  static const _routes = ['/', '/consultations', '/rendez-vous', '/pharmacies'];

  @override
  Widget build(BuildContext context) {
    // L'onglet actif suit l'URL (y compris après une navigation depuis une notification)
    final index = _routes.indexOf(GoRouterState.of(context).matchedLocation);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        indicatorColor: AppTheme.primary.withValues(alpha: 0.15),
        onDestinationSelected: (i) => context.go(_routes[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppTheme.primary),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services, color: AppTheme.primary),
            label: 'Consultations',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event, color: AppTheme.primary),
            label: 'Rendez-vous',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_pharmacy_outlined),
            selectedIcon: Icon(Icons.local_pharmacy, color: AppTheme.primary),
            label: 'Pharmacies',
          ),
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
    final prenom = patient?['prenom'] as String? ?? user?['email'] ?? 'Utilisateur';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('JWY'),
        actions: [
          const NotificationBell(),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Bannière de bienvenue ────────────────────────────────────
              _WelcomeBanner(prenom: prenom, patient: patient),

              // ── Actions rapides ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Actions rapides',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    _QuickActionsGrid(),
                    const SizedBox(height: 24),

                    // ── Urgence ──────────────────────────────────────────
                    const Text('Accès rapide',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    _UrgenceCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfile(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProfileSheet(ref: ref),
    );
  }
}

// ─── Bannière de bienvenue ────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final String prenom;
  final Map<String, dynamic>? patient;
  const _WelcomeBanner({required this.prenom, required this.patient});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Bonjour' : hour < 18 ? 'Bon après-midi' : 'Bonsoir';
    final groupeSanguin = patient?['groupe_sanguin'] as String?;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary, Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $prenom 👋',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Comment vous sentez-vous aujourd\'hui ?',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              if (groupeSanguin != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    _InfoBadge(icon: Icons.bloodtype, label: groupeSanguin),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Grille actions rapides ───────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final _actions = const [
    _QuickAction(
      icon: Icons.video_call,
      label: 'Téléconsultation',
      color: Color(0xFF1565C0),
      bgColor: Color(0xFFE3F2FD),
      route: '/consultations/nouvelle',
      isPush: true,
    ),
    _QuickAction(
      icon: Icons.calendar_month,
      label: 'Mes consultations',
      color: Color(0xFF7B1FA2),
      bgColor: Color(0xFFF3E5F5),
      route: '/consultations',
      isPush: false,
    ),
    _QuickAction(
      icon: Icons.local_pharmacy,
      label: 'Pharmacies',
      color: Color(0xFFF57C00),
      bgColor: Color(0xFFFFF3E0),
      route: '/pharmacies',
      isPush: false,
    ),
    _QuickAction(
      icon: Icons.event_available,
      label: 'Prendre rendez-vous',
      color: Color(0xFF0277BD),
      bgColor: Color(0xFFE1F5FE),
      route: '/rendez-vous/nouveau',
      isPush: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      children: _actions.map((a) => _QuickActionCard(action: a)).toList(),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final String route;
  final bool isPush;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.route,
    required this.isPush,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1.5,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => action.isPush ? context.push(action.route) : context.go(action.route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: action.bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, color: action.color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                action.label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Carte urgence ────────────────────────────────────────────────────────────

class _UrgenceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.emergency, color: AppTheme.errorColor, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Urgence médicale ?',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.errorColor, fontSize: 14)),
                SizedBox(height: 2),
                Text('Consultez un médecin disponible maintenant',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              minimumSize: const Size(60, 38),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => context.push('/consultations/nouvelle'),
            child: const Text('SOS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _buildDisplayName(Map<String, dynamic>? patient, Map<String, dynamic>? user) {
  final prenom = patient?['prenom'] as String? ?? '';
  final nom = patient?['nom'] as String? ?? '';
  final full = '$prenom $nom'.trim();
  return full.isEmpty ? (user?['email'] as String? ?? '') : full;
}

// ─── Fiche profil ─────────────────────────────────────────────────────────────

class _ProfileSheet extends StatelessWidget {
  final WidgetRef ref;
  const _ProfileSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final patient = user?['patient'] as Map<String, dynamic>?;
    final nom = _buildDisplayName(patient, user);
    final groupeSanguin = patient?['groupe_sanguin'] as String?;
    final adresse = patient?['adresse'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person, size: 36, color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          Text(nom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(user?['email'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          if (groupeSanguin != null || adresse != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            if (groupeSanguin != null)
              ListTile(
                dense: true,
                leading: const Icon(Icons.bloodtype, color: AppTheme.errorColor),
                title: const Text('Groupe sanguin'),
                trailing: Text(groupeSanguin, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            if (adresse != null)
              ListTile(
                dense: true,
                leading: const Icon(Icons.location_on_outlined, color: AppTheme.primary),
                title: const Text('Adresse'),
                subtitle: Text(adresse),
              ),
          ],
          const Divider(height: 24),
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

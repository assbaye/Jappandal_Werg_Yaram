import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../rendez_vous/screens/rendez_vous_screen.dart' show rendezVousProvider;
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/outils.dart';
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
        onDestinationSelected: (i) => context.go(_routes[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.house),
            selectedIcon: Icon(PhosphorIconsFill.house),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.stethoscope),
            selectedIcon: Icon(PhosphorIconsFill.stethoscope),
            label: 'Consultations',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.calendarBlank),
            selectedIcon: Icon(PhosphorIconsFill.calendarBlank),
            label: 'Rendez-vous',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.firstAidKit),
            selectedIcon: Icon(PhosphorIconsFill.firstAidKit),
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
    final prenom = patient?['prenom'] as String? ?? '';
    final nom = patient?['nom'] as String? ?? '';
    final heure = DateTime.now().hour;
    final salutation = heure < 18 ? 'Bonjour' : 'Bonsoir';
    final initiales = '${prenom.isNotEmpty ? prenom[0] : ''}${nom.isNotEmpty ? nom[0] : ''}'.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(salutation, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.inkSoft)),
            Text(prenom.isEmpty ? 'Bienvenue' : prenom,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppTheme.ink)),
          ],
        ),
        actions: [
          const NotificationBell(),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _showProfile(context, ref),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: AppTheme.primarySoft,
                child: initiales.isEmpty
                    ? const Icon(PhosphorIconsRegular.user, color: AppTheme.primary, size: 20)
                    : Text(initiales,
                        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(rendezVousProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: const [
            _ProchainRendezVous(),
            SizedBox(height: 12),
            _OrientationCard(),
            SizedBox(height: 28),
            _TitreSection('Services'),
            SizedBox(height: 12),
            _ServicesGrid(),
            SizedBox(height: 28),
            _UrgenceCard(),
          ],
        ),
      ),
    );
  }

  void _showProfile(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProfileSheet(ref: ref),
    );
  }
}

class _TitreSection extends StatelessWidget {
  final String texte;
  const _TitreSection(this.texte);

  @override
  Widget build(BuildContext context) =>
      Text(texte, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.ink));
}

/// Pastille d'icône commune aux cartes de l'accueil.
class _Pastille extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final Color fond;
  const _Pastille(this.icone, {this.couleur = AppTheme.primary, this.fond = AppTheme.primarySoft});

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(12)),
        child: Icon(icone, color: couleur, size: 22),
      );
}

// ─── Prochain rendez-vous ─────────────────────────────────────────────────────

class _ProchainRendezVous extends ConsumerWidget {
  const _ProchainRendezVous();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liste = ref.watch(rendezVousProvider).valueOrNull ?? [];
    final maintenant = DateTime.now();
    final aVenir = liste
        .cast<Map<String, dynamic>>()
        .where((r) =>
            r['statut'] != 'ANNULE' &&
            (DateTime.tryParse(r['date_rendez_vous'] as String? ?? '')?.isAfter(maintenant) ?? false))
        .toList()
      ..sort((a, b) => (a['date_rendez_vous'] as String).compareTo(b['date_rendez_vous'] as String));
    final rdv = aVenir.firstOrNull;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => rdv == null ? context.push('/rendez-vous/nouveau') : context.go('/rendez-vous'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const _Pastille(PhosphorIconsRegular.calendarBlank),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Prochain rendez-vous',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.inkMuted)),
                    const SizedBox(height: 3),
                    if (rdv == null)
                      const Text('Aucun rendez-vous prévu',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))
                    else ...[
                      Text('Dr ${rdv['medecin']?['prenom'] ?? ''} ${rdv['medecin']?['nom'] ?? ''}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      Text(
                        DateFormat("EEEE d MMMM 'à' HH:mm", 'fr_FR')
                            .format(DateTime.parse(rdv['date_rendez_vous'] as String)),
                        style: const TextStyle(fontSize: 13, color: AppTheme.inkSoft),
                      ),
                    ],
                  ],
                ),
              ),
              Text(rdv == null ? 'Prendre' : 'Voir',
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Orientation (assistant) ──────────────────────────────────────────────────

class _OrientationCard extends StatelessWidget {
  const _OrientationCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.push('/triage'),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              _Pastille(PhosphorIconsRegular.stethoscope),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Besoin d\'un avis ?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    SizedBox(height: 2),
                    Text('Décrivez vos symptômes, nous vous orientons vers le bon médecin.',
                        style: TextStyle(fontSize: 13, color: AppTheme.inkSoft)),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(PhosphorIconsRegular.caretRight, color: AppTheme.inkMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Services ─────────────────────────────────────────────────────────────────

class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid();

  static const _services = [
    (icone: PhosphorIconsRegular.videoCamera, titre: 'Téléconsultation', detail: 'Un médecin en vidéo',
        route: '/consultations/nouvelle'),
    (icone: PhosphorIconsRegular.calendarCheck, titre: 'Rendez-vous', detail: 'Au cabinet ou en vidéo',
        route: '/rendez-vous/nouveau'),
    (icone: PhosphorIconsRegular.firstAidKit, titre: 'Pharmacies', detail: 'De garde et ouvertes',
        route: '/pharmacies'),
    (icone: PhosphorIconsRegular.fileText, titre: 'Ordonnances', detail: 'Vos médicaments',
        route: '/ordonnances'),
  ];

  @override
  Widget build(BuildContext context) {
    // Hauteur fixe plutôt qu'un ratio : le texte ne déborde pas sur les écrans étroits
    return GridView(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 132,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final s in _services)
          Card(
            clipBehavior: Clip.antiAlias,
            margin: EdgeInsets.zero,
            child: InkWell(
              // Pharmacies est un onglet : on y va ; les autres écrans s'empilent
              onTap: () => s.route == '/pharmacies' ? context.go(s.route) : context.push(s.route),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Pastille(s.icone),
                    const Spacer(),
                    Text(s.titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(s.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppTheme.inkSoft)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Urgence ──────────────────────────────────────────────────────────────────

class _UrgenceCard extends StatelessWidget {
  const _UrgenceCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.rayon,
        side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _Pastille(PhosphorIconsRegular.siren,
                couleur: AppTheme.errorColor, fond: AppTheme.errorColor.withValues(alpha: 0.08)),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Urgence médicale', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('SAMU 1515 et alerte aux médecins', style: TextStyle(fontSize: 13, color: AppTheme.inkSoft)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor),
                minimumSize: const Size(64, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () => context.push('/urgence'),
              child: const Text('SOS', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
          ],
        ),
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
    final groupeSanguin = groupeSanguinLabel(patient?['groupe_sanguin'] as String?);
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
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          CircleAvatar(
            radius: 36,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: const Icon(PhosphorIconsRegular.user, size: 36, color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          Text(nom, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(user?['email'] ?? '', style: TextStyle(color: AppTheme.inkSoft, fontSize: 13)),
          if (groupeSanguin != null || adresse != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            if (groupeSanguin != null)
              ListTile(
                dense: true,
                leading: const Icon(PhosphorIconsRegular.drop, color: AppTheme.errorColor),
                title: const Text('Groupe sanguin'),
                trailing: Text(groupeSanguin, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            if (adresse != null)
              ListTile(
                dense: true,
                leading: const Icon(PhosphorIconsRegular.mapPin, color: AppTheme.primary),
                title: const Text('Adresse'),
                subtitle: Text(adresse),
              ),
          ],
          const Divider(height: 24),
          ListTile(
            leading: const Icon(PhosphorIconsRegular.pencilSimple, color: AppTheme.primary),
            title: const Text('Modifier mon profil'),
            trailing: const Icon(PhosphorIconsRegular.caretRight),
            onTap: () {
              final router = GoRouter.of(context); // le contexte de la fiche disparaît au pop
              Navigator.pop(context);
              router.push('/profil');
            },
          ),
          ListTile(
            leading: const Icon(PhosphorIconsRegular.signOut, color: AppTheme.errorColor),
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

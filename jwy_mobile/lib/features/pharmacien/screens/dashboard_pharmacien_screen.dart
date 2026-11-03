import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/pharmacien_queries.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import 'commandes_pharmacien_screen.dart';
import 'stock_screen.dart';

// ─── Shell pharmacien ─────────────────────────────────────────────────────────

class PharmacienShell extends StatelessWidget {
  final Widget child;
  const PharmacienShell({super.key, required this.child});

  static const _routes = ['/pharmacien', '/pharmacien/commandes', '/pharmacien/stock'];

  @override
  Widget build(BuildContext context) {
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
            icon: Icon(PhosphorIconsRegular.receipt),
            selectedIcon: Icon(PhosphorIconsFill.receipt),
            label: 'Commandes',
          ),
          NavigationDestination(
            icon: Icon(PhosphorIconsRegular.package),
            selectedIcon: Icon(PhosphorIconsFill.package),
            label: 'Stock',
          ),
        ],
      ),
    );
  }
}

// ─── Accueil ──────────────────────────────────────────────────────────────────

final _maPharmacieProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final result = await ref.read(graphQLClientProvider).query(QueryOptions(
        document: gql(maPharmacieQuery),
        fetchPolicy: FetchPolicy.networkOnly,
      ));
  if (result.hasException) throw result.exception!;
  return result.data?['maPharmacie'] as Map<String, dynamic>?;
});

class DashboardPharmacienTab extends ConsumerWidget {
  const DashboardPharmacienTab({super.key});

  Future<void> _rafraichir(WidgetRef ref) async {
    ref.invalidate(_maPharmacieProvider);
    ref.invalidate(stockProvider);
    ref.invalidate(commandesPharmacieProvider);
    await ref.read(commandesPharmacieProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pharmacie = ref.watch(_maPharmacieProvider).valueOrNull;
    final commandes = ref.watch(commandesPharmacieProvider);
    final stock = ref.watch(stockProvider).valueOrNull ?? [];
    final liste = commandes.valueOrNull ?? [];

    int compter(List<String> statuts) => liste.where((c) => statuts.contains(c['statut'])).length;
    final aTraiter = liste.where((c) => c['statut'] == 'EN_ATTENTE').toList();
    final faibles = stock.where((s) => s['is_stock_faible'] == true).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma pharmacie'),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: 'Mon profil',
            icon: const Icon(PhosphorIconsRegular.user),
            onPressed: () async {
              await context.push('/profil');
              ref.invalidate(_maPharmacieProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _rafraichir(ref),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── En-tête pharmacie ────────────────────────────────────────
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: AppTheme.primarySoft, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(PhosphorIconsRegular.firstAidKit, color: AppTheme.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pharmacie?['nom_pharmacie'] as String? ?? 'Ma pharmacie',
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(pharmacie?['adresse'] as String? ?? '',
                              style: const TextStyle(color: AppTheme.inkSoft, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Garde ────────────────────────────────────────────────────
            if (pharmacie != null) ...[
              _GardeCard(pharmacie: pharmacie, onChange: () => ref.invalidate(_maPharmacieProvider)),
              const SizedBox(height: 16),
            ],

            // ── Chiffres clés ────────────────────────────────────────────
            Row(
              children: [
                _Stat(valeur: aTraiter.length, label: 'À traiter', couleur: AppTheme.warningColor,
                    onTap: () => context.go('/pharmacien/commandes')),
                const SizedBox(width: 10),
                _Stat(valeur: compter(['CONFIRMEE', 'EN_PREPARATION']), label: 'En préparation',
                    couleur: AppTheme.secondary, onTap: () => context.go('/pharmacien/commandes')),
                const SizedBox(width: 10),
                _Stat(valeur: compter(['PRETE', 'EN_LIVRAISON']), label: 'Prêtes',
                    couleur: AppTheme.primary, onTap: () => context.go('/pharmacien/commandes')),
              ],
            ),
            const SizedBox(height: 20),

            // ── Alertes de stock ─────────────────────────────────────────
            if (faibles.isNotEmpty) ...[
              Card(
                color: AppTheme.warningSoft,
                child: ListTile(
                  leading: const Icon(PhosphorIconsRegular.warning, color: AppTheme.warningColor),
                  title: Text('${faibles.length} produit(s) en stock faible'),
                  subtitle: Text(
                    faibles.take(3).map((s) => s['medicament']?['nom_commercial']).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(PhosphorIconsRegular.caretRight),
                  onTap: () => context.go('/pharmacien/stock'),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Commandes à traiter ──────────────────────────────────────
            const Text('Commandes à traiter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            commandes.when(
              skipError: true, // un rafraîchissement raté garde l'affichage précédent
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (_, __) => const Text('Impossible de charger les commandes'),
              data: (_) => aTraiter.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('Aucune nouvelle commande', style: TextStyle(color: AppTheme.inkSoft)),
                      ),
                    )
                  : Column(
                      children: [
                        for (final c in aTraiter.take(5))
                          CommandePharmacienCard(commande: c as Map<String, dynamic>),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final int valeur;
  final String label;
  final Color couleur;
  final VoidCallback onTap;
  const _Stat({required this.valeur, required this.label, required this.couleur, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Text('$valeur', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: couleur)),
                const SizedBox(height: 2),
                Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppTheme.inkSoft)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Garde ────────────────────────────────────────────────────────────────────

class _GardeCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> pharmacie;
  final VoidCallback onChange;
  const _GardeCard({required this.pharmacie, required this.onChange});

  @override
  ConsumerState<_GardeCard> createState() => _GardeCardState();
}

class _GardeCardState extends ConsumerState<_GardeCard> {
  bool _loading = false;

  Future<void> _envoyer(DateTime? jusquAu) async {
    setState(() => _loading = true);
    final result = await ref.read(graphQLClientProvider).mutate(MutationOptions(
          document: gql(declarerGardeMutation),
          variables: {
            'jusqu_au': jusquAu == null ? null : DateFormat('yyyy-MM-dd HH:mm:ss').format(jusquAu),
          },
        ));
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.exception?.graphqlErrors.firstOrNull?.message ?? 'Une erreur est survenue'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    widget.onChange();
  }

  Future<void> _declarer() async {
    // Par défaut : garde jusqu'au lendemain 8 h
    final demain = DateTime.now().add(const Duration(days: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: demain,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      helpText: 'Fin de la garde',
    );
    if (date == null || !mounted) return;
    final heure = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Heure de fin de la garde',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (heure == null) return;
    await _envoyer(DateTime(date.year, date.month, date.day, heure.hour, heure.minute));
  }

  @override
  Widget build(BuildContext context) {
    final deGarde = widget.pharmacie['est_de_garde'] == true;
    final couleur = deGarde ? AppTheme.primary : AppTheme.inkSoft;

    return Card(
      color: deGarde ? AppTheme.primarySoft : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(PhosphorIconsFill.moonStars, color: couleur, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deGarde ? 'Pharmacie de garde' : 'Pas de garde en cours',
                      style: TextStyle(fontWeight: FontWeight.bold, color: couleur)),
                  Text(widget.pharmacie['statut_ouverture'] as String? ?? '',
                      style: TextStyle(fontSize: 12, color: AppTheme.inkSoft)),
                ],
              ),
            ),
            if (_loading)
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            else
              TextButton(
                onPressed: deGarde ? () => _envoyer(null) : _declarer,
                child: Text(deGarde ? 'Terminer' : 'Déclarer'),
              ),
          ],
        ),
      ),
    );
  }
}

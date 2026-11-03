import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
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
        indicatorColor: AppTheme.primary.withValues(alpha: 0.15),
        onDestinationSelected: (i) => context.go(_routes[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppTheme.primary),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppTheme.primary),
            label: 'Commandes',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: AppTheme.primary),
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
        title: const Text('JWY — Pharmacie'),
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _rafraichir(ref),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── En-tête pharmacie ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF42A5F5)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.local_pharmacy, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pharmacie?['nom_pharmacie'] as String? ?? 'Ma pharmacie',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(pharmacie?['adresse'] as String? ?? '',
                            style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Chiffres clés ────────────────────────────────────────────
            Row(
              children: [
                _Stat(valeur: aTraiter.length, label: 'À traiter', couleur: AppTheme.warningColor,
                    onTap: () => context.go('/pharmacien/commandes')),
                const SizedBox(width: 10),
                _Stat(valeur: compter(['CONFIRMEE', 'EN_PREPARATION']), label: 'En préparation',
                    couleur: const Color(0xFF7B1FA2), onTap: () => context.go('/pharmacien/commandes')),
                const SizedBox(width: 10),
                _Stat(valeur: compter(['PRETE', 'EN_LIVRAISON']), label: 'Prêtes',
                    couleur: AppTheme.primary, onTap: () => context.go('/pharmacien/commandes')),
              ],
            ),
            const SizedBox(height: 20),

            // ── Alertes de stock ─────────────────────────────────────────
            if (faibles.isNotEmpty) ...[
              Card(
                color: const Color(0xFFFFF3E0),
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
                  title: Text('${faibles.length} produit(s) en stock faible'),
                  subtitle: Text(
                    faibles.take(3).map((s) => s['medicament']?['nom_commercial']).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/pharmacien/stock'),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Commandes à traiter ──────────────────────────────────────
            const Text('Commandes à traiter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            commandes.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (_, __) => const Text('Impossible de charger les commandes'),
              data: (_) => aTraiter.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('Aucune nouvelle commande', style: TextStyle(color: Colors.grey[600])),
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
                Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

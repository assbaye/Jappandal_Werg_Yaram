import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/patient_queries.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pharmacien/screens/commandes_pharmacien_screen.dart' show fcfa, statutCommandeInfo;

final _mesCommandesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final result = await ref.read(graphQLClientProvider).query(QueryOptions(
        document: gql(mesCommandesQuery),
        variables: const {'first': 50, 'page': 1},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
  if (result.hasException) throw result.exception!;
  return (result.data?['mesCommandes']?['data'] as List<dynamic>?) ?? [];
});

/// Étapes affichées dans la frise de suivi.
const _etapes = ['EN_ATTENTE', 'CONFIRMEE', 'EN_PREPARATION', 'PRETE', 'LIVREE'];

class MesCommandesScreen extends ConsumerWidget {
  const MesCommandesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_mesCommandesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes commandes')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(_mesCommandesProvider),
            child: const Text('Impossible de charger les commandes — réessayer'),
          ),
        ),
        data: (commandes) => RefreshIndicator(
          onRefresh: () => ref.refresh(_mesCommandesProvider.future),
          child: commandes.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 120),
                  Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'Aucune commande.\nCommandez vos médicaments depuis une ordonnance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: commandes.length,
                  itemBuilder: (_, i) => _CommandeCard(commande: commandes[i] as Map<String, dynamic>),
                ),
        ),
      ),
    );
  }
}

class _CommandeCard extends StatelessWidget {
  final Map<String, dynamic> commande;
  const _CommandeCard({required this.commande});

  @override
  Widget build(BuildContext context) {
    final statut = commande['statut'] as String? ?? '';
    final (label, couleur) = statutCommandeInfo(statut);
    final pharmacie = commande['pharmacie'] as Map<String, dynamic>?;
    final lignes = (commande['lignes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final livraison = commande['type_livraison'] == 'LIVRAISON';
    final total = ((commande['montant_total'] as num?) ?? 0) + ((commande['frais_livraison'] as num?) ?? 0);
    final date = DateTime.tryParse(commande['created_at'] as String? ?? '');
    // En livraison, « en livraison » se place entre « prête » et « remise »
    final etape = statut == 'EN_LIVRAISON' ? 3 : _etapes.indexOf(statut);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pharmacie?['nom_pharmacie'] as String? ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        '${commande['numero_commande']}'
                        '${date == null ? '' : ' · ${DateFormat('dd/MM/yyyy', 'fr_FR').format(date)}'}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: couleur.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(label, style: TextStyle(color: couleur, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            if (statut != 'ANNULEE') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  for (int i = 0; i < _etapes.length; i++) ...[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= etape ? AppTheme.primary : Colors.grey.shade300,
                      ),
                    ),
                    if (i < _etapes.length - 1)
                      Expanded(
                        child: Container(height: 2, color: i < etape ? AppTheme.primary : Colors.grey.shade300),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final e in ['Envoyée', 'Acceptée', 'Préparée', 'Prête', 'Remise'])
                    Text(e, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                ],
              ),
            ],
            const Divider(height: 24),
            for (final l in lignes)
              Text('${l['quantite']} × ${l['medicament']?['nom_commercial'] ?? ''}',
                  style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(livraison ? Icons.delivery_dining : Icons.storefront, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    livraison
                        ? 'Livraison : ${commande['adresse_livraison'] ?? ''}'
                        : 'Retrait : ${pharmacie?['adresse'] ?? ''}',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ),
                Text('${fcfa.format(total)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

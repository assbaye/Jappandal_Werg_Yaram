import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/patient_queries.dart';
import '../../auth/providers/auth_provider.dart';

final _ordonnancesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final result = await ref.read(graphQLClientProvider).query(QueryOptions(
        document: gql(mesPrescriptionsQuery),
        variables: const {'first': 50, 'page': 1},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
  if (result.hasException) throw result.exception!;
  return (result.data?['mesPrescriptions']?['data'] as List<dynamic>?) ?? [];
});

class MesOrdonnancesScreen extends ConsumerWidget {
  const MesOrdonnancesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_ordonnancesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes ordonnances')),
      body: async.when(
        skipError: true, // un rafraîchissement raté garde l'affichage précédent
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(_ordonnancesProvider),
            child: const Text('Impossible de charger les ordonnances — réessayer'),
          ),
        ),
        data: (ordonnances) => RefreshIndicator(
          onRefresh: () => ref.refresh(_ordonnancesProvider.future),
          child: ordonnances.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 120),
                  Icon(PhosphorIconsRegular.fileText, size: 64, color: AppTheme.inkMuted),
                  const SizedBox(height: 12),
                  Text(
                    'Aucune ordonnance.\nElles apparaissent ici après une consultation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.inkSoft),
                  ),
                ])
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: ordonnances.length,
                  itemBuilder: (_, i) => _OrdonnanceCard(ordonnance: ordonnances[i] as Map<String, dynamic>),
                ),
        ),
      ),
    );
  }
}

class _OrdonnanceCard extends StatelessWidget {
  final Map<String, dynamic> ordonnance;
  const _OrdonnanceCard({required this.ordonnance});

  @override
  Widget build(BuildContext context) {
    final medecin = ordonnance['medecin'] as Map<String, dynamic>?;
    final meds = (ordonnance['medicaments_prescrits'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final expiree = ordonnance['is_expiree'] == true;
    final date = DateTime.tryParse(ordonnance['created_at'] as String? ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(PhosphorIconsRegular.fileText, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Dr. ${medecin?['prenom'] ?? ''} ${medecin?['nom'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (date != null)
                  Text(DateFormat('dd/MM/yyyy', 'fr_FR').format(date),
                      style: TextStyle(color: AppTheme.inkSoft, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            for (final m in meds)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${m['medicament']?['nom_commercial'] ?? ''} × ${m['quantite']} — ${m['posologie']}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            const SizedBox(height: 10),
            if (expiree)
              Text('Ordonnance expirée (valable ${ordonnance['validite_jours']} jours)',
                  style: const TextStyle(color: AppTheme.errorColor, fontSize: 13))
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(PhosphorIconsRegular.shoppingBag),
                  label: const Text('Commander en pharmacie'),
                  onPressed: meds.isEmpty ? null : () => context.push('/commandes/ordonnance', extra: ordonnance),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

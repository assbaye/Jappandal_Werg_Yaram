import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/pharmacien_queries.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notifications/screens/notifications_screen.dart';

/// Libellé et couleur d'un statut de commande (partagé avec l'écran patient).
(String, Color) statutCommandeInfo(String statut) => switch (statut) {
      'EN_ATTENTE' => ('Nouvelle', AppTheme.warningColor),
      'CONFIRMEE' => ('Acceptée', AppTheme.secondary),
      'EN_PREPARATION' => ('En préparation', const Color(0xFF7B1FA2)),
      'PRETE' => ('Prête', AppTheme.primary),
      'EN_LIVRAISON' => ('En livraison', const Color(0xFF0277BD)),
      'LIVREE' => ('Remise', AppTheme.successColor),
      'ANNULEE' => ('Annulée', AppTheme.errorColor),
      _ => (statut, Colors.grey),
    };

final fcfa = NumberFormat.decimalPattern('fr_FR');

final commandesPharmacieProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final result = await ref.read(graphQLClientProvider).query(QueryOptions(
        document: gql(commandesPharmacieQuery),
        variables: const {'first': 50, 'page': 1},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
  if (result.hasException) throw result.exception!;
  return (result.data?['commandesPharmacie']?['data'] as List<dynamic>?) ?? [];
});

/// Groupes de statuts affichés en onglets.
const _onglets = <(String, List<String>)>[
  ('À traiter', ['EN_ATTENTE']),
  ('En cours', ['CONFIRMEE', 'EN_PREPARATION', 'PRETE', 'EN_LIVRAISON']),
  ('Terminées', ['LIVREE', 'ANNULEE']),
];

class CommandesPharmacienScreen extends ConsumerWidget {
  const CommandesPharmacienScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(commandesPharmacieProvider);

    return DefaultTabController(
      length: _onglets.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Commandes'),
          actions: const [NotificationBell()],
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              for (final (label, statuts) in _onglets)
                Tab(
                  text: async.valueOrNull == null
                      ? label
                      : '$label (${async.value!.where((c) => statuts.contains(c['statut'])).length})',
                ),
            ],
          ),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: TextButton(
              onPressed: () => ref.invalidate(commandesPharmacieProvider),
              child: const Text('Impossible de charger les commandes — réessayer'),
            ),
          ),
          data: (commandes) => TabBarView(
            children: [
              for (final (_, statuts) in _onglets)
                RefreshIndicator(
                  onRefresh: () => ref.refresh(commandesPharmacieProvider.future),
                  child: Builder(builder: (_) {
                    final liste = commandes.where((c) => statuts.contains(c['statut'])).toList();
                    if (liste.isEmpty) {
                      return ListView(children: [
                        const SizedBox(height: 120),
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Center(child: Text('Aucune commande', style: TextStyle(color: Colors.grey[600]))),
                      ]);
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: liste.length,
                      itemBuilder: (_, i) => CommandePharmacienCard(commande: liste[i] as Map<String, dynamic>),
                    );
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommandePharmacienCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> commande;
  const CommandePharmacienCard({super.key, required this.commande});

  @override
  ConsumerState<CommandePharmacienCard> createState() => _CommandePharmacienCardState();
}

class _CommandePharmacienCardState extends ConsumerState<CommandePharmacienCard> {
  bool _loading = false;

  Map<String, dynamic> get c => widget.commande;

  /// Étape suivante proposée au pharmacien : (statut cible, libellé du bouton).
  (String, String)? _etapeSuivante() {
    final livraison = c['type_livraison'] == 'LIVRAISON';
    return switch (c['statut']) {
      'EN_ATTENTE' => ('CONFIRMEE', 'Accepter la commande'),
      'CONFIRMEE' => ('EN_PREPARATION', 'Commencer la préparation'),
      'EN_PREPARATION' => ('PRETE', livraison ? 'Prête à livrer' : 'Prête à retirer'),
      'PRETE' => livraison ? ('EN_LIVRAISON', 'Partir en livraison') : ('LIVREE', 'Remise au patient'),
      'EN_LIVRAISON' => ('LIVREE', 'Livrée'),
      _ => null,
    };
  }

  Future<void> _changer(String statut) async {
    if (statut == 'ANNULEE') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(c['statut'] == 'EN_ATTENTE' ? 'Refuser la commande ?' : 'Annuler la commande ?'),
          content: const Text('Les médicaments retournent en stock et le patient est prévenu.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
              child: const Text('Oui'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _loading = true);
    final result = await ref.read(graphQLClientProvider).mutate(MutationOptions(
          document: gql(updateStatutCommandeMutation),
          variables: {'id': c['id'], 'statut': statut},
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
    ref.invalidate(commandesPharmacieProvider);
  }

  @override
  Widget build(BuildContext context) {
    final statut = c['statut'] as String? ?? '';
    final (label, couleur) = statutCommandeInfo(statut);
    final patient = c['patient'] as Map<String, dynamic>?;
    final lignes = (c['lignes'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final livraison = c['type_livraison'] == 'LIVRAISON';
    final total = ((c['montant_total'] as num?) ?? 0) + ((c['frais_livraison'] as num?) ?? 0);
    final date = DateTime.tryParse(c['created_at'] as String? ?? '');
    final suivante = _etapeSuivante();
    final annulable = ['EN_ATTENTE', 'CONFIRMEE', 'EN_PREPARATION'].contains(statut);

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
                      Text('${patient?['prenom'] ?? ''} ${patient?['nom'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        '${c['numero_commande']}'
                        '${date == null ? '' : ' · ${DateFormat('dd/MM à HH:mm', 'fr_FR').format(date)}'}',
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
            const Divider(height: 20),
            for (final l in lignes)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Text('${l['quantite']} ×  ', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Expanded(child: Text('${l['medicament']?['nom_commercial'] ?? ''}')),
                    Text('${fcfa.format((l['prix_unitaire'] as num) * (l['quantite'] as num))} F',
                        style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(livraison ? Icons.delivery_dining : Icons.storefront, size: 16, color: Colors.grey[700]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    livraison ? 'Livraison : ${c['adresse_livraison'] ?? ''}' : 'Retrait en pharmacie',
                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  ),
                ),
                Text('${fcfa.format(total)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            if (c['prescription'] != null) ...[
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.description_outlined, size: 16, color: AppTheme.primary),
                  SizedBox(width: 6),
                  Text('Sur ordonnance', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                ],
              ),
            ],
            if (suivante != null || annulable) ...[
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    if (annulable)
                      TextButton(
                        onPressed: () => _changer('ANNULEE'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
                        child: Text(statut == 'EN_ATTENTE' ? 'Refuser' : 'Annuler'),
                      ),
                    const Spacer(),
                    if (suivante != null)
                      ElevatedButton(
                        onPressed: () => _changer(suivante.$1),
                        style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42)),
                        child: Text(suivante.$2),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

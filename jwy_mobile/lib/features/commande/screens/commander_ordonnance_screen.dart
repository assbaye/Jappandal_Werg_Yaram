import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/patient_queries.dart';
import '../../auth/providers/auth_provider.dart';
import '../../patient/screens/pharmacies_screen.dart' show locationProvider;
import '../../pharmacien/screens/commandes_pharmacien_screen.dart' show fcfa;

// Centre de Dakar si la position n'est pas disponible
const _latDefaut = 14.6928;
const _lngDefaut = -17.4467;

final _pharmaciesStockProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final position = await ref.watch(locationProvider.future);
  final result = await ref.read(graphQLClientProvider).query(QueryOptions(
        document: gql(pharmaciesAvecStockQuery),
        variables: {
          'latitude': position?.latitude ?? _latDefaut,
          'longitude': position?.longitude ?? _lngDefaut,
          'rayon': 20.0,
        },
        fetchPolicy: FetchPolicy.networkOnly,
      ));
  if (result.hasException) throw result.exception!;
  return (result.data?['pharmaciesProches'] as List<dynamic>?) ?? [];
});

/// Ce qu'une pharmacie peut fournir pour l'ordonnance.
class _Offre {
  final Map<String, dynamic> pharmacie;
  final List<(Map<String, dynamic> ligne, num prix)> disponibles;
  final List<Map<String, dynamic>> manquants;
  _Offre(this.pharmacie, this.disponibles, this.manquants);

  num get total => disponibles.fold<num>(0, (t, d) => t + d.$2 * (d.$1['quantite'] as num));
}

class CommanderOrdonnanceScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> prescription;
  const CommanderOrdonnanceScreen({super.key, required this.prescription});

  @override
  ConsumerState<CommanderOrdonnanceScreen> createState() => _CommanderOrdonnanceScreenState();
}

class _CommanderOrdonnanceScreenState extends ConsumerState<CommanderOrdonnanceScreen> {
  String? _pharmacieId;
  bool _livraison = false;
  final _adresseCtrl = TextEditingController();
  bool _loading = false;

  List<Map<String, dynamic>> get _lignes =>
      (widget.prescription['medicaments_prescrits'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

  @override
  void dispose() {
    _adresseCtrl.dispose();
    super.dispose();
  }

  _Offre _offre(Map<String, dynamic> pharmacie) {
    final stocks = (pharmacie['stocks'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final dispo = <(Map<String, dynamic>, num)>[];
    final manquants = <Map<String, dynamic>>[];
    for (final l in _lignes) {
      final s = stocks.where((s) => s['medicament']?['id'] == l['medicament']?['id']).firstOrNull;
      if (s != null && (s['quantite_disponible'] as int) >= (l['quantite'] as int)) {
        dispo.add((l, s['prix_vente'] as num));
      } else {
        manquants.add(l);
      }
    }
    return _Offre(pharmacie, dispo, manquants);
  }

  Future<void> _commander(_Offre offre) async {
    if (_livraison && _adresseCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indiquez votre adresse de livraison')),
      );
      return;
    }
    setState(() => _loading = true);
    final result = await ref.read(graphQLClientProvider).mutate(MutationOptions(
          document: gql(commanderMedicamentsMutation),
          variables: {
            'input': {
              'pharmacie_id': offre.pharmacie['id'],
              'prescription_id': widget.prescription['id'],
              'type_livraison': _livraison ? 'LIVRAISON' : 'RETRAIT',
              if (_livraison) 'adresse_livraison': _adresseCtrl.text.trim(),
              'medicaments': [
                for (final (l, _) in offre.disponibles)
                  {'medicament_id': l['medicament']['id'], 'quantite': l['quantite']},
              ],
            },
          },
        ));
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.exception?.graphqlErrors.firstOrNull?.message ?? 'Commande impossible'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    final numero = result.data?['commanderMedicaments']?['numero_commande'];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Commande $numero envoyée à ${offre.pharmacie['nom_pharmacie']}'),
      backgroundColor: AppTheme.successColor,
    ));
    context.pushReplacement('/commandes');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_pharmaciesStockProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Commander l\'ordonnance')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(_pharmaciesStockProvider),
            child: const Text('Impossible de charger les pharmacies — réessayer'),
          ),
        ),
        data: (pharmacies) {
          // Les pharmacies qui ont tout en premier, puis les plus proches
          final offres = pharmacies.cast<Map<String, dynamic>>().map(_offre)
              .where((o) => o.disponibles.isNotEmpty)
              .toList()
            ..sort((a, b) {
              final c = a.manquants.length.compareTo(b.manquants.length);
              return c != 0 ? c : ((a.pharmacie['distance'] as num?) ?? 0).compareTo((b.pharmacie['distance'] as num?) ?? 0);
            });
          final choisie = offres.where((o) => o.pharmacie['id'] == _pharmacieId).firstOrNull;

          if (offres.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Aucune pharmacie proche n\'a ces médicaments en stock.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Choisissez une pharmacie', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              for (final o in offres) _carteOffre(o, o == choisie),
              if (choisie != null) ...[
                const SizedBox(height: 16),
                const Text('Mode de récupération', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: [
                    const ButtonSegment(value: false, icon: Icon(Icons.storefront), label: Text('Retrait')),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.delivery_dining),
                      label: const Text('Livraison'),
                      enabled: choisie.pharmacie['livraison_disponible'] == true,
                    ),
                  ],
                  selected: {_livraison},
                  onSelectionChanged: (s) => setState(() => _livraison = s.first),
                ),
                if (_livraison) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _adresseCtrl,
                    decoration: const InputDecoration(labelText: 'Adresse de livraison'),
                  ),
                ],
                const SizedBox(height: 16),
                _recap(choisie),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loading ? null : () => _commander(choisie),
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirmer la commande'),
                ),
                const SizedBox(height: 8),
                Text('Le paiement se fait à la pharmacie, au retrait ou à la livraison.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _carteOffre(_Offre o, bool selection) {
    final complet = o.manquants.isEmpty;
    final distance = (o.pharmacie['distance'] as num?)?.toStringAsFixed(1);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selection ? AppTheme.primary : Colors.transparent, width: 2),
      ),
      child: ListTile(
        onTap: () => setState(() {
          _pharmacieId = o.pharmacie['id'] as String;
          if (o.pharmacie['livraison_disponible'] != true) _livraison = false;
        }),
        leading: Icon(Icons.local_pharmacy, color: complet ? AppTheme.successColor : AppTheme.warningColor),
        title: Text(o.pharmacie['nom_pharmacie'] as String? ?? ''),
        subtitle: Text(
          '${distance == null ? '' : '$distance km · '}'
          '${complet ? 'Tout est disponible' : '${o.manquants.length} médicament(s) manquant(s)'}',
        ),
        trailing: Text('${fcfa.format(o.total)} F', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _recap(_Offre o) {
    final frais = _livraison ? 1000 : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (l, prix) in o.disponibles)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: Text('${l['quantite']} × ${l['medicament']?['nom_commercial']}')),
                    Text('${fcfa.format(prix * (l['quantite'] as num))} F'),
                  ],
                ),
              ),
            for (final l in o.manquants)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${l['medicament']?['nom_commercial']} — indisponible ici',
                    style: const TextStyle(color: AppTheme.errorColor, fontSize: 13)),
              ),
            if (frais > 0)
              Row(children: [const Expanded(child: Text('Livraison')), Text('${fcfa.format(frais)} F')]),
            const Divider(),
            Row(
              children: [
                const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                Text('${fcfa.format(o.total + frais)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

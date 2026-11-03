import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/outils.dart';
import '../../../core/graphql/queries/patient_queries.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pharmacien/screens/commandes_pharmacien_screen.dart' show fcfa;

final _pharmacieProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async {
  final result = await ref.read(graphQLClientProvider).query(QueryOptions(
        document: gql(pharmacieDetailQuery),
        variables: {'id': id},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
  if (result.hasException) throw result.exception!;
  return result.data?['pharmacie'] as Map<String, dynamic>?;
});

const _fraisLivraison = 1000;

class PharmacieDetailScreen extends ConsumerStatefulWidget {
  final String pharmacieId;
  const PharmacieDetailScreen({super.key, required this.pharmacieId});

  @override
  ConsumerState<PharmacieDetailScreen> createState() => _PharmacieDetailScreenState();
}

class _PharmacieDetailScreenState extends ConsumerState<PharmacieDetailScreen> {
  /// medicament_id → quantité dans le panier
  final Map<String, int> _panier = {};
  String _filtre = '';

  void _changer(String medId, int delta, int max) {
    setState(() {
      final q = ((_panier[medId] ?? 0) + delta).clamp(0, max);
      q == 0 ? _panier.remove(medId) : _panier[medId] = q;
    });
  }

  Future<void> _valider(Map<String, dynamic> pharmacie, List<Map<String, dynamic>> stocks) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ValidationSheet(pharmacie: pharmacie, stocks: stocks, panier: Map.of(_panier)),
    );
    if (ok == true && mounted) {
      setState(_panier.clear);
      context.pushReplacement('/commandes');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_pharmacieProvider(widget.pharmacieId));

    return Scaffold(
      appBar: AppBar(title: Text(async.valueOrNull?['nom_pharmacie'] as String? ?? 'Pharmacie')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(_pharmacieProvider(widget.pharmacieId)),
            child: const Text('Impossible de charger la pharmacie — réessayer'),
          ),
        ),
        data: (pharmacie) {
          if (pharmacie == null) return const Center(child: Text('Pharmacie introuvable'));
          final stocks = (pharmacie['stocks'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>()
              .where((s) => (s['quantite_disponible'] as int? ?? 0) > 0)
              .toList()
            ..sort((a, b) => (a['medicament']['nom_commercial'] as String)
                .compareTo(b['medicament']['nom_commercial'] as String));
          final visibles = stocks.where((s) {
            final m = s['medicament'] as Map<String, dynamic>;
            return '${m['nom_commercial']} ${m['principe_actif']}'.toLowerCase().contains(_filtre);
          }).toList();
          final total = _panier.entries.fold<num>(0, (t, e) {
            final s = stocks.firstWhere((s) => s['medicament']['id'] == e.key);
            return t + (s['prix_vente'] as num) * e.value;
          });

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _EnTete(pharmacie: pharmacie),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Rechercher un médicament',
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _filtre = v.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Les médicaments sur ordonnance se commandent depuis « Commander une ordonnance ».',
                              style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (visibles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('Aucun médicament', style: TextStyle(color: Colors.grey[600]))),
                      ),
                    for (final s in visibles) _ligne(s),
                  ],
                ),
              ),
              if (_panier.isNotEmpty)
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
                    ),
                    child: ElevatedButton(
                      onPressed: () => _valider(pharmacie, stocks),
                      child: Text(
                        'Commander · ${_panier.values.fold<int>(0, (a, b) => a + b)} article(s) · ${fcfa.format(total)} FCFA',
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _ligne(Map<String, dynamic> s) {
    final m = s['medicament'] as Map<String, dynamic>;
    final id = m['id'] as String;
    final dispo = s['quantite_disponible'] as int;
    final surOrdonnance = m['necessite_ordonnance'] == true;
    final q = _panier[id] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m['nom_commercial'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  '${fcfa.format(s['prix_vente'])} FCFA'
                  '${dispo < 10 ? ' · plus que $dispo' : ''}',
                  style: TextStyle(color: dispo < 10 ? AppTheme.warningColor : Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          if (surOrdonnance)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Sur ordonnance', style: TextStyle(fontSize: 11)),
            )
          else if (q == 0)
            OutlinedButton(
              onPressed: () => _changer(id, 1, dispo),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36)),
              child: const Text('Ajouter'),
            )
          else
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppTheme.primary,
                  onPressed: () => _changer(id, -1, dispo),
                ),
                Text('$q', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppTheme.primary,
                  onPressed: q < dispo ? () => _changer(id, 1, dispo) : null,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EnTete extends StatelessWidget {
  final Map<String, dynamic> pharmacie;
  const _EnTete({required this.pharmacie});

  @override
  Widget build(BuildContext context) {
    final tel = pharmacie['telephone'] as String?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified, color: AppTheme.primary, size: 18),
                const SizedBox(width: 6),
                const Text('Partenaire JWY', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (pharmacie['livraison_disponible'] == true)
                  const Row(children: [
                    Icon(Icons.delivery_dining, size: 16, color: AppTheme.successColor),
                    SizedBox(width: 4),
                    Text('Livraison', style: TextStyle(color: AppTheme.successColor, fontSize: 12)),
                  ]),
              ],
            ),
            const SizedBox(height: 8),
            Text(pharmacie['adresse'] as String? ?? '', style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 4),
            Text(
              pharmacie['statut_ouverture'] as String? ?? '',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: pharmacie['est_de_garde'] == true
                    ? const Color(0xFF0D47A1)
                    : pharmacie['est_ouverte'] == true
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (tel != null)
                  TextButton.icon(
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: const Text('Appeler'),
                    onPressed: () => appeler(context, tel),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.directions_outlined, size: 18),
                  label: const Text('Itinéraire'),
                  onPressed: () => ouvrirCarte(
                    (pharmacie['latitude'] as num).toDouble(),
                    (pharmacie['longitude'] as num).toDouble(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Validation de la commande ────────────────────────────────────────────────

class _ValidationSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> pharmacie;
  final List<Map<String, dynamic>> stocks;
  final Map<String, int> panier;
  const _ValidationSheet({required this.pharmacie, required this.stocks, required this.panier});

  @override
  ConsumerState<_ValidationSheet> createState() => _ValidationSheetState();
}

class _ValidationSheetState extends ConsumerState<_ValidationSheet> {
  bool _livraison = false;
  final _adresseCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _adresseCtrl.text = ref.read(authProvider).user?['patient']?['adresse'] as String? ?? '';
  }

  @override
  void dispose() {
    _adresseCtrl.dispose();
    super.dispose();
  }

  Future<void> _commander() async {
    if (_livraison && _adresseCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indiquez votre adresse')));
      return;
    }
    setState(() => _loading = true);
    final result = await ref.read(graphQLClientProvider).mutate(MutationOptions(
          document: gql(commanderMedicamentsMutation),
          variables: {
            'input': {
              'pharmacie_id': widget.pharmacie['id'],
              'type_livraison': _livraison ? 'LIVRAISON' : 'RETRAIT',
              if (_livraison) 'adresse_livraison': _adresseCtrl.text.trim(),
              'medicaments': [
                for (final e in widget.panier.entries) {'medicament_id': e.key, 'quantite': e.value},
              ],
            },
          },
        ));
    if (!mounted) return;
    setState(() => _loading = false);
    final messenger = ScaffoldMessenger.of(context);
    if (result.hasException) {
      messenger.showSnackBar(SnackBar(
        content: Text(result.exception?.graphqlErrors.firstOrNull?.message ?? 'Commande impossible'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    Navigator.pop(context, true);
    messenger.showSnackBar(SnackBar(
      content: Text('Commande ${result.data?['commanderMedicaments']?['numero_commande']} envoyée'),
      backgroundColor: AppTheme.successColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lignes = [
      for (final e in widget.panier.entries)
        (widget.stocks.firstWhere((s) => s['medicament']['id'] == e.key), e.value),
    ];
    final sousTotal = lignes.fold<num>(0, (t, l) => t + (l.$1['prix_vente'] as num) * l.$2);
    final frais = _livraison ? _fraisLivraison : 0;
    final livrable = widget.pharmacie['livraison_disponible'] == true;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Votre commande', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final (s, q) in lignes)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Expanded(child: Text('$q × ${s['medicament']['nom_commercial']}')),
                  Text('${fcfa.format((s['prix_vente'] as num) * q)} F'),
                ]),
              ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: [
                const ButtonSegment(value: false, icon: Icon(Icons.storefront), label: Text('Retrait')),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.delivery_dining),
                  label: const Text('Livraison'),
                  enabled: livrable,
                ),
              ],
              selected: {_livraison},
              onSelectionChanged: (s) => setState(() => _livraison = s.first),
            ),
            if (_livraison) ...[
              const SizedBox(height: 12),
              TextField(controller: _adresseCtrl, decoration: const InputDecoration(labelText: 'Adresse de livraison')),
            ],
            const Divider(height: 28),
            if (frais > 0)
              Row(children: [const Expanded(child: Text('Livraison')), Text('${fcfa.format(frais)} F')]),
            Row(children: [
              const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
              Text('${fcfa.format(sousTotal + frais)} FCFA', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _commander,
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Confirmer la commande'),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('Paiement à la pharmacie, au retrait ou à la livraison.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
          ],
        ),
      ),
    );
  }
}

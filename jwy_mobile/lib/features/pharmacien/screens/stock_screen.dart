import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/medecin_queries.dart';
import '../../../core/graphql/queries/pharmacien_queries.dart';
import '../../auth/providers/auth_provider.dart';
import 'commandes_pharmacien_screen.dart' show fcfa;

final stockProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final result = await ref.read(graphQLClientProvider).query(QueryOptions(
        document: gql(monStockQuery),
        variables: const {'first': 200, 'page': 1},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
  if (result.hasException) throw result.exception!;
  return (result.data?['monStock']?['data'] as List<dynamic>?) ?? [];
});

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  String _filtre = '';
  bool _faibleSeulement = false;

  Future<void> _modifier(Map<String, dynamic> medicament, {Map<String, dynamic>? stock}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _StockSheet(medicament: medicament, stock: stock),
    );
    if (ok == true) ref.invalidate(stockProvider);
  }

  Future<void> _ajouter() async {
    final med = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _RechercheSheet(),
    );
    if (med == null || !mounted) return;
    final existant = ref.read(stockProvider).valueOrNull?.cast<Map<String, dynamic>>().where(
          (s) => s['medicament']?['id'] == med['id'],
        );
    await _modifier(med, stock: existant?.firstOrNull);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(stockProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stock')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
        onPressed: _ajouter,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(stockProvider),
            child: const Text('Impossible de charger le stock — réessayer'),
          ),
        ),
        data: (stocks) {
          final nbFaible = stocks.where((s) => s['is_stock_faible'] == true).length;
          final liste = stocks.cast<Map<String, dynamic>>().where((s) {
            if (_faibleSeulement && s['is_stock_faible'] != true) return false;
            if (_filtre.isEmpty) return true;
            final m = s['medicament'] as Map<String, dynamic>? ?? {};
            return '${m['nom_commercial']} ${m['principe_actif']}'.toLowerCase().contains(_filtre);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Rechercher dans le stock',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _filtre = v.trim().toLowerCase()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    FilterChip(
                      avatar: const Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.warningColor),
                      label: Text('Stock faible ($nbFaible)'),
                      selected: _faibleSeulement,
                      onSelected: (v) => setState(() => _faibleSeulement = v),
                    ),
                    const Spacer(),
                    Text('${stocks.length} produits', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.refresh(stockProvider.future),
                  child: liste.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 80),
                          Center(child: Text('Aucun produit', style: TextStyle(color: Colors.grey[600]))),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: liste.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
                          itemBuilder: (_, i) => _ligneStock(liste[i]),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ligneStock(Map<String, dynamic> s) {
    final m = s['medicament'] as Map<String, dynamic>? ?? {};
    final faible = s['is_stock_faible'] == true;
    final qte = s['quantite_disponible'] as int? ?? 0;

    return ListTile(
      onTap: () => _modifier(m, stock: s),
      title: Row(
        children: [
          Flexible(child: Text(m['nom_commercial'] as String? ?? '', overflow: TextOverflow.ellipsis)),
          if (m['necessite_ordonnance'] == true) ...[
            const SizedBox(width: 6),
            const Tooltip(
              message: 'Sur ordonnance',
              child: Icon(Icons.description_outlined, size: 15, color: AppTheme.primary),
            ),
          ],
        ],
      ),
      subtitle: Text('${fcfa.format(s['prix_vente'] ?? 0)} FCFA · seuil ${s['quantite_minimale']}'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: (qte == 0 ? AppTheme.errorColor : faible ? AppTheme.warningColor : AppTheme.successColor)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          qte == 0 ? 'Rupture' : '$qte',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: qte == 0 ? AppTheme.errorColor : faible ? AppTheme.warningColor : AppTheme.successColor,
          ),
        ),
      ),
    );
  }
}

// ─── Modification d'une ligne de stock ────────────────────────────────────────

class _StockSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> medicament;
  final Map<String, dynamic>? stock;
  const _StockSheet({required this.medicament, this.stock});

  @override
  ConsumerState<_StockSheet> createState() => _StockSheetState();
}

class _StockSheetState extends ConsumerState<_StockSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _qte = TextEditingController(text: '${widget.stock?['quantite_disponible'] ?? 0}');
  late final _prix = TextEditingController(
      text: '${((widget.stock?['prix_vente'] ?? widget.medicament['prix_unitaire'] ?? 0) as num).toInt()}');
  late final _seuil = TextEditingController(text: '${widget.stock?['quantite_minimale'] ?? 10}');
  bool _loading = false;

  @override
  void dispose() {
    _qte.dispose();
    _prix.dispose();
    _seuil.dispose();
    super.dispose();
  }

  void _ajuster(int delta) {
    final v = (int.tryParse(_qte.text) ?? 0) + delta;
    _qte.text = '${v < 0 ? 0 : v}';
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref.read(graphQLClientProvider).mutate(MutationOptions(
          document: gql(updateStockMutation),
          variables: {
            'medicament_id': widget.medicament['id'],
            'quantite_disponible': int.parse(_qte.text),
            'prix_vente': double.parse(_prix.text),
            'quantite_minimale': int.parse(_seuil.text),
          },
        ));
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.hasException) {
      final e = result.exception!;
      final validation = e.graphqlErrors.firstOrNull?.extensions?['validation'];
      final msg = validation is Map && validation.isNotEmpty
          ? (validation.values.first as List).first.toString()
          : e.graphqlErrors.firstOrNull?.message ?? 'Enregistrement impossible';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor));
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final chiffres = [FilteringTextInputFormatter.digitsOnly];
    String? requis(String? v) => int.tryParse(v ?? '') == null ? 'Requis' : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.medicament['nom_commercial'] as String? ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.stock == null ? 'Nouveau produit en stock' : 'Mettre à jour le stock',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton.outlined(onPressed: () => _ajuster(-10), icon: const Text('-10')),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _qte,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: chiffres,
                    decoration: const InputDecoration(labelText: 'Quantité en stock'),
                    validator: requis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(onPressed: () => _ajuster(10), icon: const Text('+10')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prix,
                    keyboardType: TextInputType.number,
                    inputFormatters: chiffres,
                    decoration: const InputDecoration(labelText: 'Prix de vente (FCFA)'),
                    validator: requis,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _seuil,
                    keyboardType: TextInputType.number,
                    inputFormatters: chiffres,
                    decoration: const InputDecoration(labelText: 'Seuil d\'alerte'),
                    validator: requis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _enregistrer,
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recherche dans le catalogue ──────────────────────────────────────────────

class _RechercheSheet extends ConsumerStatefulWidget {
  const _RechercheSheet();

  @override
  ConsumerState<_RechercheSheet> createState() => _RechercheSheetState();
}

class _RechercheSheetState extends ConsumerState<_RechercheSheet> {
  Timer? _debounce;
  List<dynamic> _resultats = [];
  String _terme = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final terme = v.trim();
      _terme = terme;
      if (terme.length < 2) {
        setState(() => _resultats = []);
        return;
      }
      final result = await ref.read(graphQLClientProvider).query(QueryOptions(
            document: gql(rechercherMedicamentQuery),
            variables: {'terme': terme},
            fetchPolicy: FetchPolicy.networkOnly,
          ));
      if (!mounted || terme != _terme) return;
      setState(() => _resultats = (result.data?['rechercherMedicament'] as List<dynamic>?) ?? []);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Médicament du catalogue',
              ),
              onChanged: _onChanged,
            ),
            Expanded(
              child: _resultats.isEmpty
                  ? Center(
                      child: Text(_terme.length < 2 ? 'Tapez au moins 2 lettres' : 'Aucun résultat',
                          style: TextStyle(color: Colors.grey[600])))
                  : ListView.builder(
                      itemCount: _resultats.length,
                      itemBuilder: (_, i) {
                        final m = _resultats[i] as Map<String, dynamic>;
                        return ListTile(
                          leading: const Icon(Icons.medication, color: AppTheme.primary),
                          title: Text(m['nom_commercial'] as String),
                          subtitle: Text('${m['principe_actif']} · ${m['dosage'] ?? ''}'),
                          onTap: () => Navigator.pop(context, m),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

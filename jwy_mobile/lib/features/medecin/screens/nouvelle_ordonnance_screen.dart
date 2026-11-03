import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/medecin_queries.dart';
import '../../auth/providers/auth_provider.dart';

/// Une ligne de l'ordonnance en cours de rédaction.
class _Ligne {
  final Map<String, dynamic> medicament;
  final quantite = TextEditingController(text: '1');
  final posologie = TextEditingController();
  final duree = TextEditingController(text: '7');
  final instructions = TextEditingController();

  _Ligne(this.medicament);

  void dispose() {
    quantite.dispose();
    posologie.dispose();
    duree.dispose();
    instructions.dispose();
  }
}

class NouvelleOrdonnanceScreen extends ConsumerStatefulWidget {
  final String consultationId;
  final String patientId;
  const NouvelleOrdonnanceScreen({super.key, required this.consultationId, required this.patientId});

  @override
  ConsumerState<NouvelleOrdonnanceScreen> createState() => _NouvelleOrdonnanceScreenState();
}

class _NouvelleOrdonnanceScreenState extends ConsumerState<NouvelleOrdonnanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _instructionsCtrl = TextEditingController();
  final List<_Ligne> _lignes = [];
  int _validite = 30;
  bool _loading = false;

  @override
  void dispose() {
    _instructionsCtrl.dispose();
    for (final l in _lignes) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _ajouterMedicament() async {
    final med = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _RechercheMedicamentSheet(),
    );
    if (med == null || !mounted) return;
    if (_lignes.any((l) => l.medicament['id'] == med['id'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce médicament est déjà sur l\'ordonnance')),
      );
      return;
    }
    setState(() => _lignes.add(_Ligne(med)));
  }

  void _retirer(_Ligne l) {
    setState(() => _lignes.remove(l));
    l.dispose();
  }

  Future<void> _envoyer() async {
    if (_lignes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un médicament')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final result = await ref.read(graphQLClientProvider).mutate(MutationOptions(
          document: gql(creerPrescriptionMutation),
          variables: {
            'input': {
              'consultation_id': widget.consultationId,
              'patient_id': widget.patientId,
              'validite_jours': _validite,
              if (_instructionsCtrl.text.trim().isNotEmpty) 'instructions': _instructionsCtrl.text.trim(),
              'medicaments': [
                for (final l in _lignes)
                  {
                    'medicament_id': l.medicament['id'],
                    'quantite': int.parse(l.quantite.text),
                    'posologie': l.posologie.text.trim(),
                    'duree_traitement': int.parse(l.duree.text),
                    if (l.instructions.text.trim().isNotEmpty)
                      'instructions_speciales': l.instructions.text.trim(),
                  },
              ],
            },
          },
        ));
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.hasException) {
      final msg = result.exception?.graphqlErrors.firstOrNull?.message ??
          'Impossible d\'envoyer l\'ordonnance';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
      );
      return;
    }
    context.pop(true);
  }

  String? _entierPositif(String? v) {
    final n = int.tryParse(v ?? '');
    return (n == null || n < 1) ? 'Requis' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle ordonnance')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_lignes.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    Icon(PhosphorIconsRegular.pill, size: 40, color: AppTheme.inkMuted),
                    const SizedBox(height: 8),
                    Text('Aucun médicament pour l\'instant',
                        style: TextStyle(color: AppTheme.inkSoft)),
                  ],
                ),
              ),
            for (int i = 0; i < _lignes.length; i++) _carteLigne(i, _lignes[i]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(PhosphorIconsRegular.plus),
              label: const Text('Ajouter un médicament'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _ajouterMedicament,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _instructionsCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Instructions générales',
                hintText: 'Ex. : prendre pendant les repas, revenir si la fièvre persiste…',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _validite,
              decoration: const InputDecoration(labelText: 'Validité de l\'ordonnance'),
              items: const [
                DropdownMenuItem(value: 15, child: Text('15 jours')),
                DropdownMenuItem(value: 30, child: Text('30 jours')),
                DropdownMenuItem(value: 90, child: Text('3 mois')),
              ],
              onChanged: (v) => setState(() => _validite = v ?? 30),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: _loading
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(PhosphorIconsRegular.paperPlaneTilt),
              label: const Text('Envoyer l\'ordonnance au patient'),
              onPressed: _loading ? null : _envoyer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteLigne(int i, _Ligne l) {
    final med = l.medicament;
    final chiffres = [FilteringTextInputFormatter.digitsOnly];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}. ${med['nom_commercial']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('${med['principe_actif'] ?? ''} · ${med['forme']?.toString().toLowerCase() ?? ''}',
                          style: TextStyle(color: AppTheme.inkSoft, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(PhosphorIconsRegular.trash, color: AppTheme.errorColor),
                  tooltip: 'Retirer',
                  onPressed: () => _retirer(l),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                children: [
                  TextFormField(
                    controller: l.posologie,
                    decoration: const InputDecoration(
                      labelText: 'Posologie *',
                      hintText: 'Ex. : 1 comprimé matin et soir',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez la posologie' : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: l.quantite,
                          keyboardType: TextInputType.number,
                          inputFormatters: chiffres,
                          decoration: const InputDecoration(labelText: 'Quantité (boîtes)'),
                          validator: _entierPositif,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: l.duree,
                          keyboardType: TextInputType.number,
                          inputFormatters: chiffres,
                          decoration: const InputDecoration(labelText: 'Durée (jours)'),
                          validator: _entierPositif,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: l.instructions,
                    decoration: const InputDecoration(labelText: 'Instructions particulières'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recherche de médicament ──────────────────────────────────────────────────

class _RechercheMedicamentSheet extends ConsumerStatefulWidget {
  const _RechercheMedicamentSheet();

  @override
  ConsumerState<_RechercheMedicamentSheet> createState() => _RechercheMedicamentSheetState();
}

class _RechercheMedicamentSheetState extends ConsumerState<_RechercheMedicamentSheet> {
  Timer? _debounce;
  List<dynamic> _resultats = [];
  bool _loading = false;
  String? _erreur;
  String _terme = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _rechercher(v.trim()));
  }

  Future<void> _rechercher(String terme) async {
    _terme = terme;
    if (terme.length < 2) {
      setState(() => _resultats = []);
      return;
    }
    setState(() {
      _loading = true;
      _erreur = null;
    });
    final result = await ref.read(graphQLClientProvider).query(QueryOptions(
          document: gql(rechercherMedicamentQuery),
          variables: {'terme': terme},
          fetchPolicy: FetchPolicy.networkOnly,
        ));
    if (!mounted || terme != _terme) return; // une recherche plus récente est en cours
    setState(() {
      _loading = false;
      _erreur = result.hasException ? 'Recherche impossible' : null;
      _resultats = (result.data?['rechercherMedicament'] as List<dynamic>?) ?? [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(PhosphorIconsRegular.magnifyingGlass),
                hintText: 'Nom ou principe actif (ex. : paracétamol)',
              ),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: _erreur != null
                  ? Center(child: Text(_erreur!))
                  : _resultats.isEmpty
                      ? Center(
                          child: Text(
                            _terme.length < 2 ? 'Tapez au moins 2 lettres' : 'Aucun médicament trouvé',
                            style: TextStyle(color: AppTheme.inkSoft),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _resultats.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final m = _resultats[i] as Map<String, dynamic>;
                            return ListTile(
                              leading: const Icon(PhosphorIconsRegular.pill, color: AppTheme.primary),
                              title: Text(m['nom_commercial'] as String),
                              subtitle: Text(
                                  '${m['principe_actif']} · ${m['dosage'] ?? ''} · ${(m['prix_unitaire'] as num?)?.toInt() ?? 0} FCFA'),
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

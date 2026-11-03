import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/profil_queries.dart';
import '../../auth/providers/auth_provider.dart';

final _profilProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final result = await ref.read(graphQLClientProvider).query(QueryOptions(
        document: gql(monProfilQuery),
        fetchPolicy: FetchPolicy.networkOnly,
      ));
  if (result.hasException) throw result.exception!;
  return result.data?['me'] as Map<String, dynamic>?;
});

/// Message lisible d'une erreur GraphQL (validation comprise).
String _erreur(OperationException e) {
  if (e.linkException != null) return 'Impossible de joindre le serveur';
  final err = e.graphqlErrors.firstOrNull;
  final validation = err?.extensions?['validation'];
  if (validation is Map && validation.isNotEmpty) {
    final msgs = validation.values.first;
    if (msgs is List && msgs.isNotEmpty) return msgs.first.toString();
  }
  return err?.message ?? 'Une erreur est survenue';
}

const _groupes = {
  'A_POS': 'A+', 'A_NEG': 'A-', 'B_POS': 'B+', 'B_NEG': 'B-',
  'AB_POS': 'AB+', 'AB_NEG': 'AB-', 'O_POS': 'O+', 'O_NEG': 'O-',
};

class ProfilScreen extends ConsumerWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_profilProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(_profilProvider),
            child: const Text('Impossible de charger le profil — réessayer'),
          ),
        ),
        data: (me) => me == null ? const Center(child: Text('Profil introuvable')) : _Formulaire(me: me),
      ),
    );
  }
}

class _Formulaire extends ConsumerStatefulWidget {
  final Map<String, dynamic> me;
  const _Formulaire({required this.me});

  @override
  ConsumerState<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends ConsumerState<_Formulaire> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _c = {};
  bool _loading = false;

  // Patient
  String? _genre;
  String? _groupe;
  DateTime? _naissance;
  // Pharmacie
  bool _livraison = false;

  String get _role => widget.me['role'] as String? ?? '';
  Map<String, dynamic>? get _patient => widget.me['patient'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _medecin => widget.me['medecin'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _pharmacien => widget.me['pharmacien'] as Map<String, dynamic>?;
  Map<String, dynamic>? get _pharmacie =>
      (_pharmacien?['pharmacies'] as List<dynamic>?)?.cast<Map<String, dynamic>>().firstOrNull;

  TextEditingController _ctrl(String cle, Object? valeur) =>
      _c.putIfAbsent(cle, () => TextEditingController(text: valeur == null ? '' : '$valeur'));

  @override
  void initState() {
    super.initState();
    _ctrl('telephone', widget.me['telephone']);
    switch (_role) {
      case 'patient':
        final p = _patient ?? {};
        for (final k in ['nom', 'prenom', 'adresse', 'numero_urgence']) {
          _ctrl(k, p[k]);
        }
        _ctrl('allergies', (p['allergies'] as List<dynamic>? ?? []).join(', '));
        _genre = p['genre'] as String?;
        _groupe = p['groupe_sanguin'] as String?;
        _naissance = DateTime.tryParse(p['date_naissance'] as String? ?? '');
      case 'medecin':
        final m = _medecin ?? {};
        for (final k in ['nom', 'prenom', 'specialite', 'hopital_rattachement', 'biographie']) {
          _ctrl(k, m[k]);
        }
        _ctrl('tarif_consultation', (m['tarif_consultation'] as num?)?.toInt());
        _ctrl('annees_experience', m['annees_experience']);
      case 'pharmacien':
        _ctrl('nom', _pharmacien?['nom']);
        _ctrl('prenom', _pharmacien?['prenom']);
        _ctrl('nom_pharmacie', _pharmacie?['nom_pharmacie']);
        _ctrl('adresse_pharmacie', _pharmacie?['adresse']);
        _ctrl('telephone_pharmacie', _pharmacie?['telephone']);
        _livraison = _pharmacie?['livraison_disponible'] == true;
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _v(String cle) => _c[cle]!.text.trim();
  String? _vOuNull(String cle) => _v(cle).isEmpty ? null : _v(cle);

  /// Mutations à envoyer selon le rôle : (document, input).
  List<(String, Map<String, dynamic>)> _mutations() {
    final liste = <(String, Map<String, dynamic>)>[
      (updateCompteMutation, {'telephone': _vOuNull('telephone')}),
    ];
    switch (_role) {
      case 'patient':
        liste.add((updateProfilPatientMutation, {
          'nom': _v('nom'),
          'prenom': _v('prenom'),
          'adresse': _vOuNull('adresse'),
          'numero_urgence': _vOuNull('numero_urgence'),
          'genre': _genre,
          'groupe_sanguin': _groupe,
          'date_naissance': _naissance == null ? null : DateFormat('yyyy-MM-dd').format(_naissance!),
          'allergies': _v('allergies').split(',').map((a) => a.trim()).where((a) => a.isNotEmpty).toList(),
        }));
      case 'medecin':
        liste.add((updateProfilMedecinMutation, {
          'nom': _v('nom'),
          'prenom': _v('prenom'),
          'specialite': _v('specialite'),
          'hopital_rattachement': _vOuNull('hopital_rattachement'),
          'biographie': _vOuNull('biographie'),
          'tarif_consultation': double.tryParse(_v('tarif_consultation')),
          'annees_experience': int.tryParse(_v('annees_experience')),
        }));
      case 'pharmacien':
        liste.add((updateProfilPharmacienMutation, {'nom': _v('nom'), 'prenom': _v('prenom')}));
        if (_pharmacie != null) {
          liste.add((updateMaPharmacieMutation, {
            'nom_pharmacie': _v('nom_pharmacie'),
            'adresse': _v('adresse_pharmacie'),
            'telephone': _vOuNull('telephone_pharmacie'),
            'livraison_disponible': _livraison,
          }));
        }
    }
    return liste;
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final client = ref.read(graphQLClientProvider);
    String? erreur;
    for (final (doc, input) in _mutations()) {
      final result = await client.mutate(MutationOptions(document: gql(doc), variables: {'input': input}));
      if (result.hasException) {
        erreur = _erreur(result.exception!);
        break;
      }
    }
    await ref.read(authProvider.notifier).rafraichirUtilisateur();
    if (!mounted) return;
    setState(() => _loading = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(erreur ?? 'Profil enregistré'),
      backgroundColor: erreur == null ? AppTheme.successColor : AppTheme.errorColor,
    ));
    if (erreur == null) context.pop();
  }

  Future<void> _choisirNaissance() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _naissance ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Date de naissance',
    );
    if (d != null) setState(() => _naissance = d);
  }

  @override
  Widget build(BuildContext context) {
    String? requis(String? v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;
    final chiffres = [FilteringTextInputFormatter.digitsOnly];

    Widget champ(String cle, String label,
            {String? Function(String?)? validator, TextInputType? clavier, int lignes = 1, String? aide,
            List<TextInputFormatter>? formats}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: _c[cle],
            validator: validator,
            keyboardType: clavier,
            inputFormatters: formats,
            maxLines: lignes,
            textCapitalization: clavier == null ? TextCapitalization.sentences : TextCapitalization.none,
            decoration: InputDecoration(labelText: label, helperText: aide),
          ),
        );

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Compte ────────────────────────────────────────────────────
          const _Section('Compte'),
          TextFormField(
            initialValue: widget.me['email'] as String? ?? '',
            enabled: false,
            decoration: const InputDecoration(labelText: 'Email', helperText: 'L\'email ne peut pas être modifié'),
          ),
          const SizedBox(height: 12),
          champ('telephone', 'Téléphone', clavier: TextInputType.phone),

          // ── Patient ───────────────────────────────────────────────────
          if (_role == 'patient') ...[
            const _Section('Informations personnelles'),
            Row(children: [
              Expanded(child: champ('prenom', 'Prénom', validator: requis)),
              const SizedBox(width: 12),
              Expanded(child: champ('nom', 'Nom', validator: requis)),
            ]),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cake_outlined),
                label: Text(_naissance == null
                    ? 'Date de naissance'
                    : 'Né(e) le ${DateFormat('d MMMM yyyy', 'fr_FR').format(_naissance!)}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _choisirNaissance,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'F', label: Text('Femme')),
                  ButtonSegment(value: 'M', label: Text('Homme')),
                ],
                emptySelectionAllowed: true,
                selected: {if (_genre != null) _genre!},
                onSelectionChanged: (s) => setState(() => _genre = s.firstOrNull),
              ),
            ),
            champ('adresse', 'Adresse'),
            champ('numero_urgence', 'Contact d\'urgence', clavier: TextInputType.phone,
                aide: 'Personne à prévenir en cas d\'urgence'),
            const _Section('Santé'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _groupe,
                decoration: const InputDecoration(labelText: 'Groupe sanguin'),
                items: [
                  for (final e in _groupes.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _groupe = v),
              ),
            ),
            champ('allergies', 'Allergies', aide: 'Séparées par des virgules (ex. : pénicilline, arachide)'),
          ],

          // ── Médecin ───────────────────────────────────────────────────
          if (_role == 'medecin') ...[
            const _Section('Profil professionnel'),
            Row(children: [
              Expanded(child: champ('prenom', 'Prénom', validator: requis)),
              const SizedBox(width: 12),
              Expanded(child: champ('nom', 'Nom', validator: requis)),
            ]),
            if (_medecin?['numero_ordre'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('N° d\'ordre : ${_medecin!['numero_ordre']}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ),
            champ('specialite', 'Spécialité', validator: requis),
            champ('hopital_rattachement', 'Hôpital / clinique de rattachement'),
            Row(children: [
              Expanded(
                child: champ('tarif_consultation', 'Tarif (FCFA)',
                    clavier: TextInputType.number, formats: chiffres, validator: requis),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: champ('annees_experience', 'Années d\'expérience',
                    clavier: TextInputType.number, formats: chiffres, validator: requis),
              ),
            ]),
            champ('biographie', 'Présentation', lignes: 4, aide: 'Visible par les patients'),
          ],

          // ── Pharmacien ────────────────────────────────────────────────
          if (_role == 'pharmacien') ...[
            const _Section('Pharmacien'),
            Row(children: [
              Expanded(child: champ('prenom', 'Prénom', validator: requis)),
              const SizedBox(width: 12),
              Expanded(child: champ('nom', 'Nom', validator: requis)),
            ]),
            if (_pharmacie != null) ...[
              const _Section('Ma pharmacie'),
              champ('nom_pharmacie', 'Nom de la pharmacie', validator: requis),
              champ('adresse_pharmacie', 'Adresse', validator: requis),
              champ('telephone_pharmacie', 'Téléphone de la pharmacie', clavier: TextInputType.phone),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Livraison à domicile'),
                subtitle: const Text('Les patients peuvent choisir la livraison'),
                value: _livraison,
                onChanged: (v) => setState(() => _livraison = v),
              ),
            ],
          ],

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loading ? null : _enregistrer,
            child: _loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Enregistrer'),
          ),

          // ── Sécurité ──────────────────────────────────────────────────
          const _Section('Sécurité'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline, color: AppTheme.primary),
              title: const Text('Changer le mot de passe'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const _MotDePasseSheet(),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.errorColor),
              title: const Text('Se déconnecter', style: TextStyle(color: AppTheme.errorColor)),
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String titre;
  const _Section(this.titre);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 10),
        child: Text(titre.toUpperCase(),
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Colors.grey[600])),
      );
}

// ─── Changement de mot de passe ───────────────────────────────────────────────

class _MotDePasseSheet extends ConsumerStatefulWidget {
  const _MotDePasseSheet();

  @override
  ConsumerState<_MotDePasseSheet> createState() => _MotDePasseSheetState();
}

class _MotDePasseSheetState extends ConsumerState<_MotDePasseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _ancien = TextEditingController();
  final _nouveau = TextEditingController();
  final _confirmation = TextEditingController();
  bool _masque = true;
  bool _loading = false;

  @override
  void dispose() {
    _ancien.dispose();
    _nouveau.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref.read(graphQLClientProvider).mutate(MutationOptions(
          document: gql(changerMotDePasseMutation),
          variables: {'ancien': _ancien.text, 'nouveau': _nouveau.text},
        ));
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_erreur(result.exception!)), backgroundColor: AppTheme.errorColor),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context); // la fiche disparaît au pop
    Navigator.pop(context);
    messenger.showSnackBar(const SnackBar(
      content: Text('Mot de passe modifié'),
      backgroundColor: AppTheme.successColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final oeil = IconButton(
      icon: Icon(_masque ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      onPressed: () => setState(() => _masque = !_masque),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Changer le mot de passe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ancien,
              obscureText: _masque,
              decoration: InputDecoration(labelText: 'Mot de passe actuel', suffixIcon: oeil),
              validator: (v) => (v == null || v.isEmpty) ? 'Champ obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nouveau,
              obscureText: _masque,
              decoration: const InputDecoration(labelText: 'Nouveau mot de passe', helperText: '8 caractères minimum'),
              validator: (v) => (v == null || v.length < 8) ? 'Au moins 8 caractères' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmation,
              obscureText: _masque,
              decoration: const InputDecoration(labelText: 'Confirmer le nouveau mot de passe'),
              validator: (v) => v != _nouveau.text ? 'Les mots de passe ne correspondent pas' : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _valider,
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Modifier le mot de passe'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/outils.dart';
import '../../../core/graphql/queries/patient_queries.dart';
import '../../auth/providers/auth_provider.dart';

class NouvelleConsultationScreen extends ConsumerStatefulWidget {
  /// Pré-orientation IA (facultative) : pré-remplit les symptômes, le type et la spécialité conseillée.
  final Map<String, dynamic>? triage;
  const NouvelleConsultationScreen({super.key, this.triage});

  @override
  ConsumerState<NouvelleConsultationScreen> createState() => _NouvelleConsultationScreenState();
}

class _NouvelleConsultationScreenState extends ConsumerState<NouvelleConsultationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _symptomesCtrl = TextEditingController();

  String _typeConsultation = 'VIDEO';
  Map<String, dynamic>? _selectedMedecin;
  bool _isLoading = false;

  static const _types = [
    {'value': 'VIDEO', 'label': 'Téléconsultation vidéo', 'icon': PhosphorIconsRegular.videoCamera},
    {'value': 'CHAT', 'label': 'Chat médical', 'icon': PhosphorIconsRegular.chatCircle},
    {'value': 'PHYSIQUE', 'label': 'Consultation physique', 'icon': PhosphorIconsRegular.hospital},
  ];

  String? get _specialiteConseillee => widget.triage?['specialite_recommandee'] as String?;

  @override
  void initState() {
    super.initState();
    final t = widget.triage;
    if (t != null) {
      _symptomesCtrl.text = t['symptomes'] as String? ?? '';
      if (t['type_consultation'] is String) _typeConsultation = t['type_consultation'] as String;
    }
  }

  @override
  void dispose() {
    _symptomesCtrl.dispose();
    super.dispose();
  }

  Future<void> _soumettre() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMedecin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un médecin'), backgroundColor: AppTheme.errorColor),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final client = ref.read(graphQLClientProvider);
      final result = await client.mutate(
        MutationOptions(
          document: gql(demanderConsultationMutation),
          variables: {
            'input': {
              'medecin_id': _selectedMedecin!['id'],
              'type_consultation': _typeConsultation,
              'symptomes': _symptomesCtrl.text.trim(),
              if (widget.triage?['id'] != null) 'triage_ia_id': widget.triage!['id'],
            },
          },
        ),
      );

      if (!mounted) return;
      if (result.hasException) {
        final msg = result.exception?.graphqlErrors.firstOrNull?.message ?? 'Erreur';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppTheme.errorColor),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consultation créée avec succès !'), backgroundColor: AppTheme.successColor),
        );
        context.go('/consultations');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('Nouvelle consultation'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.triage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsRegular.stethoscope, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pré-rempli d\'après votre orientation · spécialité conseillée : $_specialiteConseillee. '
                        'Le médecin verra le résumé.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            // Type de consultation
            const Text('Type de consultation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ..._types.map((t) => _TypeCard(
              typeValue: t['value'] as String,
              label: t['label'] as String,
              icon: t['icon'] as IconData,
              selected: _typeConsultation == t['value'],
              onTap: () => setState(() => _typeConsultation = t['value'] as String),
            )),

            const SizedBox(height: 24),

            // Sélection médecin
            const Text('Choisir un médecin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _MedecinSelector(
              selectedMedecin: _selectedMedecin,
              specialiteConseillee: _specialiteConseillee,
              client: ref.watch(graphQLClientProvider),
              onSelected: (m) => setState(() => _selectedMedecin = m),
            ),

            const SizedBox(height: 24),

            // Symptômes
            const Text('Décrivez vos symptômes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _symptomesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Ex: Fièvre depuis 3 jours, maux de tête, fatigue...',
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().length < 10) return 'Décrivez vos symptômes (min. 10 caractères)';
                return null;
              },
            ),

            const SizedBox(height: 32),

            ElevatedButton.icon(
              icon: _isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(PhosphorIconsRegular.paperPlaneTilt),
              label: Text(_isLoading ? 'Envoi...' : 'Demander la consultation'),
              onPressed: _isLoading ? null : _soumettre,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String typeValue;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.typeValue,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.primary : AppTheme.inkMuted),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            const Spacer(),
            if (selected) const Icon(PhosphorIconsFill.checkCircle, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

class _MedecinSelector extends StatelessWidget {
  final Map<String, dynamic>? selectedMedecin;
  final String? specialiteConseillee;
  final GraphQLClient client;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _MedecinSelector({
    required this.selectedMedecin,
    this.specialiteConseillee,
    required this.client,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedMedecin != null) {
      return GestureDetector(
        onTap: () => _showMedecinPicker(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primary, width: 2),
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.primary.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              const CircleAvatar(child: Icon(PhosphorIconsRegular.user)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dr. ${selectedMedecin!['prenom'] ?? ''} ${selectedMedecin!['nom'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(selectedMedecin!['specialite'] as String? ?? '',
                        style: TextStyle(color: AppTheme.inkSoft, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(PhosphorIconsRegular.pencilSimple, color: AppTheme.primary),
            ],
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
      label: const Text('Rechercher un médecin'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        side: const BorderSide(color: AppTheme.primary),
      ),
      onPressed: () => _showMedecinPicker(context),
    );
  }

  void _showMedecinPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => _MedecinPickerSheet(client: client, specialiteConseillee: specialiteConseillee, onSelected: (m) {
        Navigator.pop(sheetContext); // fermer la feuille, pas l'écran
        onSelected(m);
      }),
    );
  }
}

class _MedecinPickerSheet extends StatefulWidget {
  final GraphQLClient client;
  final String? specialiteConseillee;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _MedecinPickerSheet({required this.client, this.specialiteConseillee, required this.onSelected});

  @override
  State<_MedecinPickerSheet> createState() => _MedecinPickerSheetState();
}

class _MedecinPickerSheetState extends State<_MedecinPickerSheet> {
  late final Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadMedecins();
  }

  Future<List<dynamic>> _loadMedecins() async {
    final result = await widget.client.query(
      QueryOptions(
        document: gql(medecinsPaginateQuery),
        variables: const {'first': 20},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );
    if (result.hasException) throw result.exception!;
    return (result.data?['medecins']?['data'] as List<dynamic>?) ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Choisir un médecin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(messageErreur(snapshot.error)));
                }
                // Spécialité conseillée par l'assistant IA en premier
                final conseil = widget.specialiteConseillee;
                final medecins = [...?snapshot.data]
                  ..sort((a, b) => (b['specialite'] == conseil ? 1 : 0) - (a['specialite'] == conseil ? 1 : 0));
                return ListView.builder(
                  controller: controller,
                  itemCount: medecins.length,
                  itemBuilder: (_, i) {
                    final m = medecins[i] as Map<String, dynamic>;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(PhosphorIconsRegular.user)),
                      title: Text('Dr. ${m['prenom'] ?? ''} ${m['nom'] ?? ''}'),
                      subtitle: Row(
                        children: [
                          Flexible(child: Text(m['specialite'] as String? ?? '')),
                          if (conseil != null && m['specialite'] == conseil) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Conseillé',
                                  style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                      trailing: Text(
                        '${m['tarif_consultation'] ?? 0} FCFA',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                      onTap: () => widget.onSelected(m),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

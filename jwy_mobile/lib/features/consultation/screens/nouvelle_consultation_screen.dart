import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/patient_queries.dart';
import '../../auth/providers/auth_provider.dart';

class NouvelleConsultationScreen extends ConsumerStatefulWidget {
  const NouvelleConsultationScreen({super.key});

  @override
  ConsumerState<NouvelleConsultationScreen> createState() => _NouvelleConsultationScreenState();
}

class _NouvelleConsultationScreenState extends ConsumerState<NouvelleConsultationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _symptomesCtrl = TextEditingController();

  String _typeConsultation = 'video';
  Map<String, dynamic>? _selectedMedecin;
  bool _isLoading = false;

  static const _types = [
    {'value': 'video', 'label': 'Téléconsultation vidéo', 'icon': Icons.video_call},
    {'value': 'chat', 'label': 'Chat médical', 'icon': Icons.chat_bubble_outline},
    {'value': 'physique', 'label': 'Consultation physique', 'icon': Icons.local_hospital_outlined},
  ];

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
              'type': _typeConsultation,
              'symptomes': _symptomesCtrl.text.trim(),
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
      appBar: AppBar(title: const Text('Nouvelle consultation')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
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
                  : const Icon(Icons.send),
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
          color: selected ? AppTheme.primary.withOpacity(0.08) : Colors.white,
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.primary : Colors.grey),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
            const Spacer(),
            if (selected) const Icon(Icons.check_circle, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

class _MedecinSelector extends StatelessWidget {
  final Map<String, dynamic>? selectedMedecin;
  final GraphQLClient client;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _MedecinSelector({
    required this.selectedMedecin,
    required this.client,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedMedecin != null) {
      final user = selectedMedecin!['user'] as Map<String, dynamic>? ?? {};
      return GestureDetector(
        onTap: () => _showMedecinPicker(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primary, width: 2),
            borderRadius: BorderRadius.circular(12),
            color: AppTheme.primary.withOpacity(0.05),
          ),
          child: Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dr. ${user['prenom'] ?? ''} ${user['nom'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(selectedMedecin!['specialite'] as String? ?? '',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.edit, color: AppTheme.primary),
            ],
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      icon: const Icon(Icons.search),
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
      builder: (_) => _MedecinPickerSheet(client: client, onSelected: (m) {
        Navigator.pop(context);
        onSelected(m);
      }),
    );
  }
}

class _MedecinPickerSheet extends StatelessWidget {
  final GraphQLClient client;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _MedecinPickerSheet({required this.client, required this.onSelected});

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
            child: Query(
              options: QueryOptions(
                document: gql(medecinsPaginateQuery),
                variables: const {'first': 20},
                fetchPolicy: FetchPolicy.networkOnly,
              ),
              builder: (result, {fetchMore, refetch}) {
                if (result.isLoading) return const Center(child: CircularProgressIndicator());
                final medecins = (result.data?['medecins']?['data'] as List<dynamic>?) ?? [];
                return ListView.builder(
                  controller: controller,
                  itemCount: medecins.length,
                  itemBuilder: (_, i) {
                    final m = medecins[i] as Map<String, dynamic>;
                    final user = m['user'] as Map<String, dynamic>? ?? {};
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text('Dr. ${user['prenom'] ?? ''} ${user['nom'] ?? ''}'),
                      subtitle: Text(m['specialite'] as String? ?? ''),
                      trailing: Text('${m['tarif_consultation'] ?? 0} FCFA', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                      onTap: () => onSelected(m),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/patient_queries.dart';
import '../../../core/graphql/queries/rendez_vous_queries.dart';
import '../../auth/providers/auth_provider.dart';
import 'rendez_vous_screen.dart';

final _medecinsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final result = await ref.read(graphQLClientProvider).query(QueryOptions(
        document: gql(medecinsPaginateQuery),
        variables: const {'first': 50},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
  if (result.hasException) throw result.exception!;
  return (result.data?['medecins']?['data'] as List<dynamic>?) ?? [];
});

class NouveauRendezVousScreen extends ConsumerStatefulWidget {
  const NouveauRendezVousScreen({super.key});

  @override
  ConsumerState<NouveauRendezVousScreen> createState() => _NouveauRendezVousScreenState();
}

class _NouveauRendezVousScreenState extends ConsumerState<NouveauRendezVousScreen> {
  final _motifCtrl = TextEditingController();
  Map<String, dynamic>? _medecin;
  String _type = 'PHYSIQUE';
  DateTime? _date;
  bool _loading = false;

  @override
  void dispose() {
    _motifCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirDate() async {
    final d = await choisirDateHeure(context, initiale: _date);
    if (d != null) setState(() => _date = d);
  }

  Future<void> _valider() async {
    if (_medecin == null || _date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez un médecin et une date')),
      );
      return;
    }
    setState(() => _loading = true);
    final result = await ref.read(graphQLClientProvider).mutate(MutationOptions(
          document: gql(prendreRendezVousMutation),
          variables: {
            'input': {
              'medecin_id': _medecin!['id'],
              'date_rendez_vous': formatDateServeur(_date!),
              'type_rendez_vous': _type,
              if (_motifCtrl.text.trim().isNotEmpty) 'motif': _motifCtrl.text.trim(),
            },
          },
        ));
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.exception?.graphqlErrors.firstOrNull?.message ??
            'Impossible de prendre le rendez-vous'),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Demande envoyée — le médecin doit la confirmer'),
      backgroundColor: AppTheme.successColor,
    ));
    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final medecinsAsync = ref.watch(_medecinsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Prendre rendez-vous')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Titre('1. Médecin'),
          medecinsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => TextButton(
              onPressed: () => ref.invalidate(_medecinsProvider),
              child: const Text('Impossible de charger les médecins — réessayer'),
            ),
            data: (medecins) => Column(
              children: [
                for (final m in medecins.cast<Map<String, dynamic>>())
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _medecin?['id'] == m['id'] ? AppTheme.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        child: const Icon(Icons.person, color: AppTheme.primary),
                      ),
                      title: Text('Dr. ${m['prenom']} ${m['nom']}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                          '${m['specialite']} · ${(m['tarif_consultation'] as num?)?.toInt() ?? 0} FCFA'),
                      trailing: _medecin?['id'] == m['id']
                          ? const Icon(Icons.check_circle, color: AppTheme.primary)
                          : null,
                      onTap: () => setState(() => _medecin = m),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _Titre('2. Type de rendez-vous'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'PHYSIQUE', icon: Icon(Icons.local_hospital_outlined), label: Text('Au cabinet')),
              ButtonSegment(value: 'VIDEO', icon: Icon(Icons.videocam_outlined), label: Text('En vidéo')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 20),
          const _Titre('3. Date et heure'),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_month),
            label: Text(_date == null
                ? 'Choisir une date'
                : DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr_FR').format(_date!)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _choisirDate,
          ),
          const SizedBox(height: 20),
          const _Titre('4. Motif (facultatif)'),
          TextField(
            controller: _motifCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Ex. : contrôle annuel, renouvellement d\'ordonnance…'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _valider,
            child: _loading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Envoyer la demande'),
          ),
        ],
      ),
    );
  }
}

class _Titre extends StatelessWidget {
  final String texte;
  const _Titre(this.texte);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(texte, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      );
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/paiement_queries.dart';
import '../../auth/providers/auth_provider.dart';
import '../../pharmacien/screens/commandes_pharmacien_screen.dart' show fcfa;

/// Suivi d'un paiement Wave : le serveur interroge Wave (verifierPaiement) ;
/// l'application ne fait qu'afficher le statut, elle ne peut pas le confirmer.
class PaiementSuiviScreen extends ConsumerStatefulWidget {
  final String paiementId;
  const PaiementSuiviScreen({super.key, required this.paiementId});

  @override
  ConsumerState<PaiementSuiviScreen> createState() => _PaiementSuiviScreenState();
}

class _PaiementSuiviScreenState extends ConsumerState<PaiementSuiviScreen> with WidgetsBindingObserver {
  // Une session Wave expire au bout de 30 minutes
  static const _dureeMax = Duration(minutes: 31);

  Timer? _timer;
  final _debut = DateTime.now();
  Map<String, dynamic>? _paiement;
  bool _enCours = false;

  String get _statut => _paiement?['statut'] as String? ?? 'EN_ATTENTE';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verifier();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _verifier());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Retour depuis l'application Wave : vérifier tout de suite
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verifier();
  }

  Future<void> _verifier() async {
    if (_enCours || _statut != 'EN_ATTENTE') return;
    if (DateTime.now().difference(_debut) > _dureeMax) {
      _timer?.cancel();
      setState(() {});
      return;
    }
    _enCours = true;
    final result = await ref.read(graphQLClientProvider).mutate(MutationOptions(
          document: gql(verifierPaiementMutation),
          variables: {'paiement_id': widget.paiementId},
        ));
    _enCours = false;
    if (!mounted) return;
    final p = result.data?['verifierPaiement'] as Map<String, dynamic>?;
    if (p != null) {
      setState(() => _paiement = p);
      if (_statut != 'EN_ATTENTE') _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final expire = _statut == 'EN_ATTENTE' && DateTime.now().difference(_debut) > _dureeMax;
    final facture = _paiement?['facture'] as Map<String, dynamic>?;

    final (icone, couleur, titre, texte) = switch (_statut) {
      'CONFIRME' => (PhosphorIconsFill.sealCheck, AppTheme.successColor, 'Paiement confirmé',
          'Wave a confirmé votre paiement de ${fcfa.format(_paiement?['montant'] ?? 0)} FCFA.'),
      'ECHEC' => (PhosphorIconsRegular.warningCircle, AppTheme.errorColor, 'Paiement non abouti',
          'Le paiement a été annulé ou a expiré. Vous n\'avez pas été débité.'),
      _ when expire => (PhosphorIconsRegular.timer, AppTheme.warningColor, 'Délai dépassé',
          'Nous n\'avons pas reçu de confirmation de Wave. Si vous avez payé, elle arrivera par notification.'),
      _ => (PhosphorIconsRegular.waves, const Color(0xFF1BAAE1), 'En attente de Wave',
          'Finalisez le paiement dans l\'application Wave, puis revenez ici.'),
    };

    return PopScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Paiement Wave')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icone, size: 72, color: couleur),
                const SizedBox(height: 16),
                Text(titre, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: couleur)),
                const SizedBox(height: 8),
                Text(texte, textAlign: TextAlign.center, style: const TextStyle(height: 1.5)),
                if (_statut == 'EN_ATTENTE' && !expire) ...[
                  const SizedBox(height: 24),
                  const LinearProgressIndicator(color: Color(0xFF1BAAE1)),
                ],
                if (facture != null) ...[
                  const SizedBox(height: 16),
                  Text('Facture ${facture['numero_facture']}', style: TextStyle(color: AppTheme.inkSoft)),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.go('/consultations'),
                  child: Text(_statut == 'EN_ATTENTE' && !expire ? 'Revenir plus tard' : 'Retour à mes consultations'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

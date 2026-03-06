import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/graphql/queries/paiement_queries.dart';
import '../../auth/providers/auth_provider.dart';

class PaiementWebviewScreen extends ConsumerStatefulWidget {
  final String redirectUrl;
  final String transactionId;

  const PaiementWebviewScreen({
    super.key,
    required this.redirectUrl,
    required this.transactionId,
  });

  @override
  ConsumerState<PaiementWebviewScreen> createState() => _PaiementWebviewScreenState();
}

class _PaiementWebviewScreenState extends ConsumerState<PaiementWebviewScreen> {
  bool _isLoading = true;
  double _progress = 0;

  // URLs de callback success/cancel — à personnaliser selon votre config backend
  static const _successUrlPatterns = ['jwy://payment/success', 'payment/success', 'paiement/success'];
  static const _cancelUrlPatterns = ['jwy://payment/cancel', 'payment/cancel', 'paiement/cancel'];

  Future<void> _confirmerPaiement() async {
    try {
      final client = ref.read(graphQLClientProvider);
      final result = await client.mutate(
        MutationOptions(
          document: gql(confirmerPaiementMutation),
          variables: {'transactionId': widget.transactionId},
        ),
      );

      if (!mounted) return;

      if (result.hasException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.exception?.graphqlErrors.firstOrNull?.message ?? 'Erreur de confirmation'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      } else {
        final paiement = result.data?['confirmerPaiement'] as Map<String, dynamic>?;
        final facture = paiement?['facture'] as Map<String, dynamic>?;
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              icon: const Icon(Icons.check_circle, color: AppTheme.successColor, size: 56),
              title: const Text('Paiement réussi !'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Votre consultation a été confirmée.'),
                  if (facture != null) ...[
                    const SizedBox(height: 8),
                    Text('Facture n° ${facture['numero_facture']}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/consultations');
                  },
                  child: const Text('Voir mes consultations'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  bool _urlMatchesPatterns(String url, List<String> patterns) {
    return patterns.any((p) => url.toLowerCase().contains(p.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement sécurisé'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showCancelDialog(),
        ),
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                ),
              )
            : null,
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.redirectUrl)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          useOnLoadResource: true,
          useShouldOverrideUrlLoading: true,
        ),
        onWebViewCreated: (_) {},
        onLoadStart: (controller, url) {
          setState(() => _isLoading = true);
          // Détecter URL de succès
          if (url != null && _urlMatchesPatterns(url.toString(), _successUrlPatterns)) {
            _confirmerPaiement();
          }
          // Détecter URL d'annulation
          if (url != null && _urlMatchesPatterns(url.toString(), _cancelUrlPatterns)) {
            context.go('/consultations');
          }
        },
        onLoadStop: (controller, url) => setState(() => _isLoading = false),
        onProgressChanged: (controller, progress) {
          setState(() => _progress = progress / 100);
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final url = navigationAction.request.url?.toString() ?? '';
          if (_urlMatchesPatterns(url, _successUrlPatterns)) {
            await _confirmerPaiement();
            return NavigationActionPolicy.CANCEL;
          }
          if (_urlMatchesPatterns(url, _cancelUrlPatterns)) {
            if (mounted) context.go('/consultations');
            return NavigationActionPolicy.CANCEL;
          }
          return NavigationActionPolicy.ALLOW;
        },
      ),
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler le paiement ?'),
        content: const Text('Votre paiement n\'a pas été effectué.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Continuer')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/consultations');
            },
            child: const Text('Annuler', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}

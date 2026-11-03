import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/outils.dart';
import '../../../core/graphql/queries/notification_queries.dart';
import '../../auth/providers/auth_provider.dart';

// ─── Providers ────────────────────────────────────────────────────────────────

/// Nombre de notifications non lues, rafraîchi toutes les 30 secondes.
final notificationsNonLuesProvider = FutureProvider.autoDispose<int>((ref) async {
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);

  final result = await ref.read(graphQLClientProvider).query(QueryOptions(
        document: gql(notificationsNonLuesQuery),
        fetchPolicy: FetchPolicy.networkOnly,
      ));
  if (result.hasException) return 0;
  return (result.data?['me']?['notifications_non_lues'] as int?) ?? 0;
});

final _notificationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final result = await ref.read(graphQLClientProvider).query(QueryOptions(
        document: gql(mesNotificationsQuery),
        variables: const {'first': 50, 'page': 1},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
  if (result.hasException) throw result.exception!;
  return (result.data?['mesNotifications']?['data'] as List<dynamic>?) ?? [];
});

// ─── Cloche avec badge (AppBar) ───────────────────────────────────────────────

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(notificationsNonLuesProvider).valueOrNull ?? 0;

    return IconButton(
      tooltip: 'Notifications',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () async {
        await context.push('/notifications');
        ref.invalidate(notificationsNonLuesProvider);
      },
    );
  }
}

// ─── Écran ────────────────────────────────────────────────────────────────────

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _toutLire(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(graphQLClientProvider).mutate(
          MutationOptions(document: gql(marquerToutesLuesMutation)),
        );
    if (result.hasException) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Impossible de marquer les notifications'),
          backgroundColor: AppTheme.errorColor,
        ));
      }
      return;
    }
    ref.invalidate(_notificationsProvider);
    ref.invalidate(notificationsNonLuesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_notificationsProvider);
    final aDesNonLues = async.valueOrNull?.any((n) => n['est_lue'] == false) ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (aDesNonLues)
            TextButton(
              onPressed: () => _toutLire(context, ref),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Tout lire'),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Impossible de charger les notifications'),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(_notificationsProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (notifs) => RefreshIndicator(
          onRefresh: () => ref.refresh(_notificationsProvider.future),
          child: notifs.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 120),
                    Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Center(
                      child: Text('Aucune notification',
                          style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                    ),
                  ],
                )
              : ListView.separated(
                  itemCount: notifs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _NotificationTile(notification: notifs[i] as Map<String, dynamic>),
                ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final Map<String, dynamic> notification;
  const _NotificationTile({required this.notification});

  (IconData, Color) _style(String? type) => switch (type) {
        'CONSULTATION' => (Icons.medical_services_outlined, AppTheme.primary),
        'RENDEZ_VOUS' => (Icons.event_outlined, const Color(0xFF7B1FA2)),
        'PRESCRIPTION' => (Icons.medication_outlined, AppTheme.warningColor),
        'PAIEMENT' => (Icons.payments_outlined, AppTheme.successColor),
        'URGENCE' || 'ALERTE_SANTE' => (Icons.warning_amber_rounded, AppTheme.errorColor),
        _ => (Icons.notifications_outlined, Colors.grey.shade700),
      };

  String _quand(String? d) {
    final date = dateServeurUtc(d);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return DateFormat('dd/MM/yyyy', 'fr_FR').format(date);
  }

  /// Écran lié à la notification, selon les données envoyées par le serveur.
  String? _destination(WidgetRef ref) {
    final data = notification['data'];
    if (data is! Map) return null;
    if (data['consultation_id'] != null) return '/consultations/${data['consultation_id']}';
    if (data['alerte_urgence_id'] != null) {
      final role = ref.read(authProvider).user?['role'];
      return role == 'medecin' ? '/medecin/urgences' : '/urgence';
    }
    if (data['commande_id'] != null) {
      final role = ref.read(authProvider).user?['role'];
      return role == 'pharmacien' ? '/pharmacien/commandes' : '/commandes';
    }
    if (data['rendez_vous_id'] != null) {
      final role = ref.read(authProvider).user?['role'];
      return role == 'medecin' ? '/medecin/rendez-vous' : '/rendez-vous';
    }
    return null;
  }

  Future<void> _ouvrir(BuildContext context, WidgetRef ref) async {
    if (notification['est_lue'] == false) {
      await ref.read(graphQLClientProvider).mutate(MutationOptions(
            document: gql(marquerNotificationLueMutation),
            variables: {'id': notification['id']},
          ));
      ref.invalidate(_notificationsProvider);
      ref.invalidate(notificationsNonLuesProvider);
    }
    final dest = _destination(ref);
    if (dest != null && context.mounted) {
      // Les onglets (rendez-vous) se remplacent, les détails s'empilent
      const empilees = ['/commandes', '/urgence', '/medecin/urgences'];
      (dest.startsWith('/consultations/') || empilees.contains(dest)) ? context.push(dest) : context.go(dest);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = _style(notification['type'] as String?);
    final nonLue = notification['est_lue'] == false;

    return ListTile(
      tileColor: nonLue ? AppTheme.primary.withValues(alpha: 0.05) : null,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        notification['titre'] as String? ?? '',
        style: TextStyle(fontWeight: nonLue ? FontWeight.bold : FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(notification['message'] as String? ?? ''),
          const SizedBox(height: 4),
          Text(_quand(notification['created_at'] as String?),
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
      trailing: nonLue
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
            )
          : null,
      isThreeLine: true,
      onTap: () => _ouvrir(context, ref),
    );
  }
}

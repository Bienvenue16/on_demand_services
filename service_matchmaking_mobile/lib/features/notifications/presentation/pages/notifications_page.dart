import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/app_semantic_colors.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/brand_header.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../bloc/notifications_bloc.dart';
import '../bloc/notifications_event.dart';
import '../bloc/notifications_state.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  void _handleNotificationTap(
    BuildContext context,
    NotificationsBloc bloc,
    AppNotification notif,
  ) {
    if (!notif.isRead) {
      bloc.add(NotificationsMarkOneRead(notif.id));
    }

    final roomId = notif.targetRoomId?.trim();
    if (roomId != null && roomId.isNotEmpty) {
      context.push('/messages?roomId=$roomId');
      return;
    }

    final requestId = notif.targetRequestId?.trim();
    if (requestId != null && requestId.isNotEmpty) {
      context.push('/requests/$requestId');
      return;
    }

    if (notif.type == 'message') {
      context.push('/messages');
      return;
    }

    if (notif.type.contains('proposal') || notif.type.contains('request')) {
      context.push('/requests');
    }
  }

  Map<String, List<AppNotification>> _groupByRecency(List<AppNotification> items) {
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    final weekAgo = todayKey.subtract(const Duration(days: 7));

    final today = <AppNotification>[];
    final week = <AppNotification>[];
    final older = <AppNotification>[];

    for (final notif in items) {
      final created = notif.createdAt;
      if (created == null) {
        week.add(notif);
        continue;
      }
      final day = DateTime(created.year, created.month, created.day);
      if (day == todayKey) {
        today.add(notif);
      } else if (day.isAfter(weekAgo)) {
        week.add(notif);
      } else {
        older.add(notif);
      }
    }

    return {
      if (today.isNotEmpty) 'Aujourd\'hui': today,
      if (week.isNotEmpty) 'Cette semaine': week,
      if (older.isNotEmpty) 'Plus ancien': older,
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationsBloc(
        context.read<NotificationsRepository>(),
      )..add(const NotificationsStarted()),
      child: Scaffold(
        bottomNavigationBar: const AppBottomNav(currentLocation: '/notifications'),
        body: SafeArea(
          child: BlocConsumer<NotificationsBloc, NotificationsState>(
            listener: (context, state) {
              if (state.status == NotificationsStatus.failure &&
                  state.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.errorMessage!)),
                );
              }
            },
            builder: (context, state) {
              final theme = Theme.of(context);
              final isDark = theme.brightness == Brightness.dark;
              final goldAccent = isDark ? theme.colorScheme.primary : theme.colorScheme.tertiary;
              final grouped = _groupByRecency(state.notifications);

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: BrandHeader(
                      title: 'Notifications',
                      subtitle: '${state.unreadCount} non lues',
                      onBack: () => context.pop(),
                      trailing: state.unreadCount > 0
                          ? TextButton(
                              onPressed: () {
                                context
                                    .read<NotificationsBloc>()
                                    .add(const NotificationsMarkAllRead());
                              },
                              style: TextButton.styleFrom(foregroundColor: goldAccent),
                              child: const Text('Tout marquer lu'),
                            )
                          : null,
                    ),
                  ),
                  if (state.status == NotificationsStatus.loading ||
                      state.status == NotificationsStatus.initial)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.notifications.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('Aucune notification')),
                    )
                  else
                    SliverList.list(
                      children: [
                        for (final entry in grouped.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                            child: Text(
                              entry.key.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: context.semanticColors.metaText,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          ...entry.value.map(
                            (notif) => _NotificationRow(
                              notif: notif,
                              onTap: () => _handleNotificationTap(
                                context,
                                context.read<NotificationsBloc>(),
                                notif,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.notif, required this.onTap});

  final AppNotification notif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: notif.isRead ? null : theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeTile(type: notif.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif.title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notif.body,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notif.createdAt == null
                          ? ''
                          : DateFormat('dd/MM HH:mm').format(notif.createdAt!),
                      style: TextStyle(
                        color: context.semanticColors.metaText,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notif.isRead)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.primary
                          : theme.colorScheme.tertiary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    final Color bg;
    final Color fg;
    final IconData icon;

    switch (type) {
      case 'new_proposal':
        bg = semantic.warnSoft;
        fg = semantic.warn;
        icon = Icons.work_outline;
        break;
      case 'message':
      case 'new_message':
        bg = theme.colorScheme.primaryContainer;
        fg = theme.colorScheme.onPrimaryContainer;
        icon = Icons.chat_bubble_outline;
        break;
      case 'proposal_accepted':
      case 'accepted':
        bg = semantic.successSoft;
        fg = semantic.success;
        icon = Icons.check_circle_outline;
        break;
      case 'new_review':
      case 'review':
        bg = semantic.warnSoft;
        fg = semantic.warn;
        icon = Icons.star_border;
        break;
      case 'validation':
      case 'account_verified':
        bg = theme.colorScheme.primaryContainer;
        fg = theme.colorScheme.onPrimaryContainer;
        icon = Icons.verified_outlined;
        break;
      case 'account':
        bg = semantic.dangerSoft;
        fg = semantic.danger;
        icon = Icons.person_outline;
        break;
      case 'broadcast':
        bg = theme.colorScheme.primaryContainer;
        fg = theme.colorScheme.onPrimaryContainer;
        icon = Icons.campaign_outlined;
        break;
      default:
        bg = theme.colorScheme.surfaceContainerHighest;
        fg = theme.colorScheme.onSurfaceVariant;
        icon = Icons.notifications_none;
    }

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: fg),
    );
  }
}

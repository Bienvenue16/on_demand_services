import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_bottom_nav.dart';
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
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.secondaryContainer,
                            Theme.of(context).colorScheme.surface,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => context.pop(),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notifications',
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                Text('${state.unreadCount} non lues'),
                              ],
                            ),
                          ),
                          if (state.unreadCount > 0)
                            FilledButton.tonal(
                              onPressed: () {
                                context.read<NotificationsBloc>().add(
                                      const NotificationsMarkAllRead(),
                                    );
                              },
                              child: const Text('Tout lire'),
                            ),
                        ],
                      ),
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
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: state.notifications.length,
                        itemBuilder: (context, index) {
                          final notif = state.notifications[index];
                          final bloc = context.read<NotificationsBloc>();
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            color: notif.isRead
                                ? null
                                : Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.35),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                _handleNotificationTap(context, bloc, notif);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _TypeAvatar(type: notif.type),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  notif.title,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall,
                                                ),
                                              ),
                                              if (!notif.isRead)
                                                const Icon(
                                                  Icons.fiber_manual_record,
                                                  size: 10,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(notif.body),
                                          const SizedBox(height: 8),
                                          Text(
                                            notif.createdAt == null
                                                ? ''
                                                : DateFormat('dd/MM HH:mm')
                                                    .format(notif.createdAt!),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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

class _TypeAvatar extends StatelessWidget {
  const _TypeAvatar({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case 'message':
        icon = Icons.chat_bubble_outline;
        break;
      case 'new_proposal':
        icon = Icons.request_quote_outlined;
        break;
      default:
        icon = Icons.notifications_none;
    }

    return CircleAvatar(
      child: Icon(icon, size: 18),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/repositories/requests_repository.dart';
import '../bloc/my_requests_bloc.dart';
import '../bloc/my_requests_event.dart';
import '../bloc/my_requests_state.dart';

class MyRequestsPage extends StatelessWidget {
  const MyRequestsPage({super.key});

  static const statuses = <String>["open", "in_progress", "done", "cancelled"];

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthBloc>().state.user?.id;
    if (userId == null || userId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Session invalide')));
    }

    return BlocProvider(
      create: (context) => MyRequestsBloc(context.read<RequestsRepository>())
        ..add(MyRequestsStarted(userId)),
      child: Scaffold(
        bottomNavigationBar: const AppBottomNav(currentLocation: '/my-requests'),
        body: SafeArea(
          child: BlocConsumer<MyRequestsBloc, MyRequestsState>(
            listener: (context, state) {
              if (state.status == MyRequestsStatus.failure &&
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
                    child: _HeroHeader(
                      title: 'Mes demandes',
                      subtitle: 'Suivez et gerez vos besoins publies',
                      onBack: () => context.pop(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Toutes'),
                            selected: state.selectedStatus == null,
                            onSelected: (_) => context.read<MyRequestsBloc>().add(
                                  MyRequestsStatusFilterChanged(userId, null),
                                ),
                          ),
                          ...statuses.map(
                            (status) => ChoiceChip(
                              label: Text(_statusLabel(status)),
                              selected: state.selectedStatus == status,
                              onSelected: (_) => context.read<MyRequestsBloc>().add(
                                    MyRequestsStatusFilterChanged(userId, status),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (state.status == MyRequestsStatus.loading ||
                      state.status == MyRequestsStatus.initial)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.requests.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('Aucune demande pour ce filtre')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: state.requests.length,
                        itemBuilder: (context, index) {
                          final request = state.requests[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => context.push('/requests/${request.id}'),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (request.photos.isNotEmpty) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: Image.network(
                                            request.photos.first,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                              alignment: Alignment.center,
                                              child: const Icon(Icons.broken_image_outlined),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            request.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                        ),
                                        _StatusChip(status: request.status),
                                        PopupMenuButton<String>(
                                          itemBuilder: (_) => statuses
                                              .map(
                                                (s) => PopupMenuItem(
                                                  value: s,
                                                  child: Text(_statusLabel(s)),
                                                ),
                                              )
                                              .toList(),
                                          onSelected: (status) {
                                            context.read<MyRequestsBloc>().add(
                                                  MyRequestsStatusUpdated(
                                                    userId: userId,
                                                    requestId: request.id,
                                                    status: status,
                                                  ),
                                                );
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      request.description,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        Chip(
                                          label: Text(
                                            'Urgence ${request.urgency.toUpperCase()}',
                                          ),
                                        ),
                                        if (request.createdAt != null)
                                          Chip(
                                            label: Text(
                                              DateFormat('dd/MM/yyyy HH:mm')
                                                  .format(request.createdAt!),
                                            ),
                                          ),
                                      ],
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

  static String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Ouvert';
      case 'in_progress':
        return 'En cours';
      case 'done':
        return 'Termine';
      case 'cancelled':
        return 'Annule';
      default:
        return status;
    }
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'open':
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade800;
        break;
      case 'in_progress':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        break;
      case 'done':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'cancelled':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        MyRequestsPage._statusLabel(status),
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

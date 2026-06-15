import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/repositories/requests_repository.dart';
import '../bloc/my_proposals_bloc.dart';
import '../bloc/my_proposals_event.dart';
import '../bloc/my_proposals_state.dart';

class MyProposalsPage extends StatelessWidget {
  const MyProposalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthBloc>().state.user;
    return BlocProvider(
      create: (context) => MyProposalsBloc(context.read<RequestsRepository>())
        ..add(const MyProposalsStarted()),
      child: Scaffold(
        bottomNavigationBar: const AppBottomNav(currentLocation: '/provider/proposals'),
        body: SafeArea(
          child: BlocConsumer<MyProposalsBloc, MyProposalsState>(
            listener: (context, state) {
              if (state.status == MyProposalsStatus.failure &&
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.tertiaryContainer,
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
                                  'Mes offres',
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 2),
                                const Text('Toutes vos propositions prestataire'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (state.status == MyProposalsStatus.loading ||
                      state.status == MyProposalsStatus.initial)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.proposals.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('Aucune offre envoyee')), 
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: state.proposals.length,
                        itemBuilder: (context, index) {
                          final proposal = state.proposals[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 1.5,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => context.push('/requests/${proposal.requestId}'),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (proposal.requestPhotos.isNotEmpty) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: Image.network(
                                            proposal.requestPhotos.first,
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
                                            proposal.requestTitle ?? 'Demande ${proposal.requestId}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                        ),
                                        _ProposalStatusChip(status: proposal.status),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      proposal.message,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        if (proposal.requestUrgency != null)
                                          Chip(
                                            label: Text(
                                              'Urgence ${proposal.requestUrgency!.toUpperCase()}',
                                            ),
                                          ),
                                        if (proposal.priceEstimate != null)
                                          Chip(
                                            label: Text(
                                              '${proposal.priceEstimate!.toStringAsFixed(0)} FCFA',
                                            ),
                                          ),
                                        if (proposal.createdAt != null)
                                          Chip(
                                            label: Text(
                                              DateFormat('dd/MM HH:mm')
                                                  .format(proposal.createdAt!),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 13,
                                            foregroundImage: (currentUser?.avatarUrl != null &&
                                                    currentUser!.avatarUrl!.isNotEmpty)
                                                ? NetworkImage(currentUser.avatarUrl!)
                                                : null,
                                            child: Text(
                                              (currentUser?.fullName.isNotEmpty ?? false)
                                                  ? currentUser!.fullName.trim()[0].toUpperCase()
                                                  : 'U',
                                              style: Theme.of(context).textTheme.labelSmall,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Propose par ${currentUser?.fullName ?? 'Vous'}',
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
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

class _ProposalStatusChip extends StatelessWidget {
  const _ProposalStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'accepted':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Acceptee';
        break;
      case 'declined':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'Refusee';
        break;
      default:
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        label = 'En attente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

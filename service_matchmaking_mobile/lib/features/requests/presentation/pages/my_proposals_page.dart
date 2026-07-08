import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_semantic_colors.dart';
import '../../../../core/utils/time_ago.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/brand_header.dart';
import '../../../messages/domain/repositories/messages_repository.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/proposal.dart';
import '../../domain/repositories/requests_repository.dart';
import '../bloc/my_proposals_bloc.dart';
import '../bloc/my_proposals_event.dart';
import '../bloc/my_proposals_state.dart';

class MyProposalsPage extends StatefulWidget {
  const MyProposalsPage({super.key});

  @override
  State<MyProposalsPage> createState() => _MyProposalsPageState();
}

class _MyProposalsPageState extends State<MyProposalsPage> {
  String _selectedStatus = 'pending';
  List<Category> _categories = const [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await context.read<RequestsRepository>().getCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (_) {
      // L'eyebrow de categorie est un bonus visuel : on l'ignore en cas d'echec.
    }
  }

  Future<void> _openConversation(Proposal proposal) async {
    final clientId = proposal.clientId;
    if (clientId == null || clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client introuvable')),
      );
      return;
    }
    try {
      final roomId = await context
          .read<MessagesRepository>()
          .startConversation(proposal.requestId, clientId);
      if (!mounted) return;
      context.push('/messages?roomId=$roomId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String _emptyMessage(String status) {
    switch (status) {
      case 'accepted':
        return 'Aucune offre acceptee pour le moment';
      case 'declined':
        return 'Aucune offre refusee';
      default:
        return 'Aucune offre en attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MyProposalsBloc(context.read<RequestsRepository>())
        ..add(const MyProposalsStarted()),
      child: Scaffold(
        bottomNavigationBar: const AppBottomNav(currentLocation: '/provider/proposals'),
        body: SafeArea(
          child: BlocConsumer<MyProposalsBloc, MyProposalsState>(
            listener: (context, state) {
              if (state.status == MyProposalsStatus.failure && state.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.errorMessage!)),
                );
              }
            },
            builder: (context, state) {
              final categoriesById = <String, Category>{
                for (final category in _categories) category.id: category,
              };
              final pendingCount =
                  state.proposals.where((p) => p.status == 'pending').length;
              final acceptedCount =
                  state.proposals.where((p) => p.status == 'accepted').length;
              final declinedCount =
                  state.proposals.where((p) => p.status == 'declined').length;
              final visible =
                  state.proposals.where((p) => p.status == _selectedStatus).toList();
              final isLoading = state.status == MyProposalsStatus.loading ||
                  state.status == MyProposalsStatus.initial;

              return CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(
                    child: BrandHeader(
                      title: 'Mes offres',
                      accentSuffix: 'offres',
                      subtitle: 'Suivez les propositions que vous avez envoyees',
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _StatusSegments(
                        selected: _selectedStatus,
                        pendingCount: pendingCount,
                        acceptedCount: acceptedCount,
                        declinedCount: declinedCount,
                        onChanged: (status) => setState(() => _selectedStatus = status),
                      ),
                    ),
                  ),
                  if (isLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (visible.isEmpty)
                    SliverFillRemaining(
                      child: Center(child: Text(_emptyMessage(_selectedStatus))),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      sliver: SliverList.list(
                        children: visible
                            .map(
                              (proposal) => _ProposalCard(
                                proposal: proposal,
                                category: categoriesById[proposal.requestCategoryId],
                                isWithdrawing: state.withdrawingId == proposal.id,
                                onOpenRequest: () =>
                                    context.push('/requests/${proposal.requestId}'),
                                onWithdraw: () => context
                                    .read<MyProposalsBloc>()
                                    .add(MyProposalsWithdrawRequested(proposal.id)),
                                onOpenConversation: () => _openConversation(proposal),
                              ),
                            )
                            .toList(),
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

class _StatusSegments extends StatelessWidget {
  const _StatusSegments({
    required this.selected,
    required this.pendingCount,
    required this.acceptedCount,
    required this.declinedCount,
    required this.onChanged,
  });

  final String selected;
  final int pendingCount;
  final int acceptedCount;
  final int declinedCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text('En attente · $pendingCount'),
            selected: selected == 'pending',
            onSelected: (_) => onChanged('pending'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text('Acceptees · $acceptedCount'),
            selected: selected == 'accepted',
            onSelected: (_) => onChanged('accepted'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text('Refusees · $declinedCount'),
            selected: selected == 'declined',
            onSelected: (_) => onChanged('declined'),
          ),
        ],
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.category,
    required this.isWithdrawing,
    required this.onOpenRequest,
    required this.onWithdraw,
    required this.onOpenConversation,
  });

  final Proposal proposal;
  final Category? category;
  final bool isWithdrawing;
  final VoidCallback onOpenRequest;
  final VoidCallback onWithdraw;
  final VoidCallback onOpenConversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final hasPhoto = proposal.requestPhotos.isNotEmpty;

    final subParts = <String>[
      if (proposal.clientName != null && proposal.clientName!.isNotEmpty)
        proposal.clientName!,
      if (proposal.clientLocationAddress != null &&
          proposal.clientLocationAddress!.isNotEmpty)
        proposal.clientLocationAddress!,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenRequest,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: hasPhoto
                        ? Image.network(
                            proposal.requestPhotos.first,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _thumbPlaceholder(semantic),
                          )
                        : _thumbPlaceholder(semantic),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (category != null)
                          Text(
                            category!.label.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        Text(
                          proposal.requestTitle ?? 'Demande',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subParts.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subParts.join(' · '),
                              style: TextStyle(color: semantic.metaText, fontSize: 11.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ProposalStatusPill(status: proposal.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (proposal.priceEstimate != null)
                    _KeyValue(
                      label: 'Votre prix',
                      value: '${proposal.priceEstimate!.toStringAsFixed(0)} F',
                    ),
                  if (proposal.createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: _KeyValue(
                        label: 'Envoyee',
                        value: timeAgo(proposal.createdAt!),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (proposal.status == 'accepted')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onOpenConversation,
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Ouvrir la conversation'),
                  ),
                )
              else if (proposal.status == 'pending')
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isWithdrawing ? null : onWithdraw,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: semantic.danger,
                      side: BorderSide(color: semantic.danger.withValues(alpha: 0.4)),
                    ),
                    icon: isWithdrawing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: semantic.danger,
                            ),
                          )
                        : const Icon(Icons.close, size: 18),
                    label: Text(isWithdrawing ? 'Retrait...' : 'Retirer ma proposition'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbPlaceholder(AppSemanticColors semantic) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: semantic.cardImageGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: semantic.metaText, fontSize: 11)),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ProposalStatusPill extends StatelessWidget {
  const _ProposalStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final Color bg;
    final Color fg;
    final String label;

    switch (status) {
      case 'accepted':
        bg = semantic.successSoft;
        fg = semantic.success;
        label = 'ACCEPTEE';
        break;
      case 'declined':
        bg = semantic.dangerSoft;
        fg = semantic.danger;
        label = 'REFUSEE';
        break;
      default:
        bg = semantic.warnSoft;
        fg = semantic.warn;
        label = 'EN ATTENTE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3),
      ),
    );
  }
}

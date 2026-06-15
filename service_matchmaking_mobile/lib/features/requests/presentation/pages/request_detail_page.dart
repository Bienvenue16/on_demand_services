import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../messages/domain/repositories/messages_repository.dart';
import '../../domain/entities/proposal.dart';
import '../../domain/repositories/requests_repository.dart';
import '../bloc/request_detail_bloc.dart';
import '../bloc/request_detail_event.dart';
import '../bloc/request_detail_state.dart';

class RequestDetailPage extends StatefulWidget {
  const RequestDetailPage({super.key, required this.requestId});

  final String requestId;

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  final _proposalMessageController = TextEditingController();
  final _proposalPriceController = TextEditingController();
  late final RequestDetailBloc _requestDetailBloc;

  @override
  void initState() {
    super.initState();
    _requestDetailBloc = RequestDetailBloc(context.read<RequestsRepository>())
      ..add(RequestDetailStarted(widget.requestId));
  }

  @override
  void dispose() {
    _requestDetailBloc.close();
    _proposalMessageController.dispose();
    _proposalPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final currentUser = authState.user;
    final isProviderUser = currentUser?.isProvider == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail de la demande')),
      body: BlocConsumer<RequestDetailBloc, RequestDetailState>(
          bloc: _requestDetailBloc,
          listenWhen: (previous, current) {
            final isFailure = current.status == RequestDetailStatus.failure &&
                current.errorMessage != null;
            final isActionSuccess =
                previous.status == RequestDetailStatus.actionLoading &&
                current.status == RequestDetailStatus.success;
            final roomIdChanged = current.roomIdToOpen != null &&
                current.roomIdToOpen != previous.roomIdToOpen;
            return isFailure || isActionSuccess || roomIdChanged;
          },
          listener: (context, state) {
            if (state.status == RequestDetailStatus.failure &&
                state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage!)),
              );
              return;
            }

            final roomIdToOpen = state.roomIdToOpen;
            if (roomIdToOpen != null && roomIdToOpen.isNotEmpty) {
              _requestDetailBloc.add(const ProposalRoomOpenConsumed());
              if (!context.mounted) return;
              context.push('/messages?roomId=$roomIdToOpen');
              return;
            }

            if (state.status == RequestDetailStatus.success && isProviderUser) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Proposition envoyee avec succes')),
              );
            }
          },
          builder: (context, state) {
            if (state.status == RequestDetailStatus.loading ||
                state.status == RequestDetailStatus.initial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.request == null) {
              return const Center(child: Text('Demande introuvable'));
            }

            final request = state.request!;
            final isOwner = currentUser?.id == request.clientId;
            final isProvider = isProviderUser;
            final hasAlreadyProposed = currentUser != null &&
              state.proposals.any((proposal) => proposal.providerId == currentUser.id);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                request.title,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Chip(label: Text(request.status)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(request.description),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text('Urgence: ${request.urgency}')),
                            if (request.locationAddress != null)
                              Chip(label: Text(request.locationAddress!)),
                          ],
                        ),
                        if (request.photos.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 96,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: request.photos.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final photo = request.photos[index];
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    photo,
                                    width: 120,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 120,
                                      height: 96,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Propositions (${state.proposals.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (state.proposals.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Aucune proposition pour le moment'),
                    ),
                  )
                else
                  ...state.proposals.map(
                    (proposal) => _ProposalTile(
                      proposal: proposal,
                      isOwner: isOwner,
                      onAccept: () {
                        _requestDetailBloc.add(
                              ProposalAccepted(
                                requestId: request.id,
                                proposalId: proposal.id,
                              ),
                            );
                      },
                      onDecline: () {
                        _requestDetailBloc.add(
                              ProposalDeclined(
                                requestId: request.id,
                                proposalId: proposal.id,
                              ),
                            );
                      },
                    ),
                  ),
                if (isProvider)
                  Card(
                    margin: const EdgeInsets.only(top: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Envoyer une proposition',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _proposalMessageController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Votre message',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _proposalPriceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Estimation (optionnel)',
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: state.status == RequestDetailStatus.actionLoading ||
                                    hasAlreadyProposed
                                ? null
                                : () {
                                    FocusScope.of(context).unfocus();
                                    final message = _proposalMessageController.text.trim();
                                    if (message.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Message requis')),
                                      );
                                      return;
                                    }

                                    _requestDetailBloc.add(
                                          ProposalSubmitted(
                                            requestId: request.id,
                                            message: message,
                                            priceEstimate: double.tryParse(
                                              _proposalPriceController.text.trim(),
                                            ),
                                          ),
                                        );
                                  },
                            icon: state.status == RequestDetailStatus.actionLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : hasAlreadyProposed
                                    ? const Icon(Icons.check_circle_outline)
                                : const Icon(Icons.send),
                            label: Text(
                              hasAlreadyProposed ? 'Proposition deja envoyee' : 'Soumettre',
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final clientId = request.clientId;
                                if (clientId == null || clientId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Client introuvable')),
                                  );
                                  return;
                                }
                                try {
                                  final roomId = await context
                                      .read<MessagesRepository>()
                                      .startConversation(request.id, clientId);
                                  if (!context.mounted) return;
                                  context.push('/messages?roomId=$roomId');
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              },
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Contacter le client'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
    );
  }
}

class _ProposalTile extends StatelessWidget {
  const _ProposalTile({
    required this.proposal,
    required this.isOwner,
    required this.onAccept,
    required this.onDecline,
  });

  final Proposal proposal;
  final bool isOwner;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).take(2).toList();
    if (parts.isEmpty) return 'P';
    return parts.map((p) => p[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = proposal.providerName?.isNotEmpty == true
        ? proposal.providerName!
        : 'Prestataire';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  foregroundImage: (proposal.providerAvatarUrl?.isNotEmpty == true)
                      ? NetworkImage(proposal.providerAvatarUrl!)
                      : null,
                  child: Text(
                    _initials(name),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Chip(
                  label: Text(proposal.status),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(proposal.message),
            if (proposal.priceEstimate != null) ...[
              const SizedBox(height: 6),
              Text('Estimation: ${proposal.priceEstimate} FCFA'),
            ],
            if (isOwner && proposal.status == 'pending') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: onDecline,
                    icon: const Icon(Icons.close),
                    label: const Text('Refuser'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check),
                    label: const Text('Accepter'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

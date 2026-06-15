import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../messages/domain/repositories/messages_repository.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/service_request.dart';
import '../../domain/repositories/requests_repository.dart';
import '../bloc/requests_bloc.dart';
import '../bloc/requests_event.dart';
import '../bloc/requests_state.dart';

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  Future<void> _openQuickProposalSheet(ServiceRequest request) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _QuickProposalSheet(request: request),
    );

    if (!mounted || submitted != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Proposition envoyee. Vous pouvez maintenant contacter le client.',
        ),
        action: SnackBarAction(
          label: 'Messages',
          onPressed: () => context.push('/messages'),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    context.read<RequestsBloc>().add(const RequestsStarted());
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthBloc>().state.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes ouvertes'),
        actions: [
          IconButton(
            tooltip: 'Messages',
            onPressed: () => context.push('/messages'),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: 'Profil',
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            tooltip: 'Mes demandes',
            onPressed: () => context.push('/my-requests'),
            icon: const Icon(Icons.list_alt),
          ),
          if (currentUser?.isProvider == true)
            IconButton(
              tooltip: 'Mes offres',
              onPressed: () => context.push('/provider/proposals'),
              icon: const Icon(Icons.work_outline),
            ),
          IconButton(
            tooltip: 'Rafraichir',
            onPressed: () {
              context.read<RequestsBloc>().add(const RequestsRefreshed());
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Deconnexion',
            onPressed: () {
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/requests/new'),
        icon: const Icon(Icons.add),
        label: const Text('Publier'),
      ),
      bottomNavigationBar: const AppBottomNav(currentLocation: '/requests'),
      body: BlocBuilder<RequestsBloc, RequestsState>(
        builder: (context, state) {
          if (state.status == RequestsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == RequestsStatus.failure) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(state.errorMessage ?? 'Erreur inconnue'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        context.read<RequestsBloc>().add(const RequestsRefreshed());
                      },
                      child: const Text('Reessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<RequestsBloc>().add(const RequestsRefreshed());
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Filtrer par categorie',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _CategoryFilter(
                  categories: state.categories,
                  selectedCategoryId: state.selectedCategoryId,
                  onChanged: (categoryId) {
                    context
                        .read<RequestsBloc>()
                        .add(RequestsCategoryChanged(categoryId));
                  },
                ),
                const SizedBox(height: 16),
                if (state.requests.isEmpty)
                  const _EmptyState()
                else
                  ...state.requests.map(
                    (request) {
                      final canInteractAsProvider =
                          currentUser?.isProvider == true && currentUser?.id != request.clientId;
                      return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1.5,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.push('/requests/${request.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _PostAuthorHeader(
                                authorName: request.clientName ?? 'Client',
                                authorAvatarUrl: request.clientAvatarUrl,
                                createdAt: request.createdAt,
                              ),
                              const SizedBox(height: 12),
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
                                      style:
                                          Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                  Chip(
                                    avatar: const Icon(Icons.bolt, size: 14),
                                    label: Text(request.urgency.toUpperCase()),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                request.description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => context.push('/requests/${request.id}'),
                                    icon: const Icon(Icons.visibility_outlined),
                                    label: const Text('Voir'),
                                  ),
                                  if (canInteractAsProvider)
                                    FilledButton.tonalIcon(
                                      onPressed: () => _openQuickProposalSheet(request),
                                      icon: const Icon(Icons.request_quote_outlined),
                                      label: const Text('Proposer'),
                                    ),
                                  if (canInteractAsProvider)
                                    TextButton.icon(
                                      onPressed: () async {
                                        final clientId = request.clientId;
                                        if (clientId == null || clientId.isEmpty) return;
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
                                      label: const Text('Contacter'),
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
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickProposalSheet extends StatefulWidget {
  const _QuickProposalSheet({required this.request});

  final ServiceRequest request;

  @override
  State<_QuickProposalSheet> createState() => _QuickProposalSheetState();
}

class _QuickProposalSheetState extends State<_QuickProposalSheet> {
  final _messageController = TextEditingController();
  final _priceController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      await context.read<RequestsRepository>().submitProposal(
            requestId: widget.request.id,
            message: _messageController.text.trim(),
            priceEstimate: double.tryParse(_priceController.text.trim()),
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nouvelle proposition',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              widget.request.title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Message pour le client',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Message requis';
                }
                if (value.trim().length < 10) {
                  return 'Message trop court';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimation (optionnel, FCFA)',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: const Text('Envoyer la proposition'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.categories,
    required this.selectedCategoryId,
    required this.onChanged,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Toutes'),
            selected: selectedCategoryId == null,
            onSelected: (_) => onChanged(null),
          ),
          const SizedBox(width: 8),
          ...categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(category.name),
                selected: selectedCategoryId == category.id,
                onSelected: (_) => onChanged(category.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostAuthorHeader extends StatelessWidget {
  const _PostAuthorHeader({
    required this.authorName,
    this.authorAvatarUrl,
    this.createdAt,
  });

  final String authorName;
  final String? authorAvatarUrl;
  final DateTime? createdAt;

  String _initials(String value) {
    final parts = value
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .toList();
    if (parts.isEmpty) {
      return 'U';
    }
    return parts.map((part) => part[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          foregroundImage: (authorAvatarUrl != null && authorAvatarUrl!.isNotEmpty)
            ? NetworkImage(authorAvatarUrl!)
            : null,
          child: Text(_initials(authorName)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                authorName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                createdAt == null
                    ? 'Date inconnue'
                    : DateFormat('dd/MM/yyyy HH:mm').format(createdAt!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'Aucune demande ouverte pour le moment',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

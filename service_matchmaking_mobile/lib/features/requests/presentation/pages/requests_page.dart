import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_semantic_colors.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../../core/utils/time_ago.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/brand_header.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
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
  final _searchController = TextEditingController();
  final _locationService = const LocationService();
  String _searchQuery = '';
  double? _myLat;
  double? _myLng;

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
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    _tryCaptureMyLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _tryCaptureMyLocation() async {
    try {
      final result = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _myLat = result.latitude;
        _myLng = result.longitude;
      });
    } catch (_) {
      // La distance est un bonus : sans position dispo, on l'omet simplement.
    }
  }

  List<ServiceRequest> _applySearch(List<ServiceRequest> requests) {
    if (_searchQuery.isEmpty) return requests;
    return requests
        .where(
          (r) =>
              r.title.toLowerCase().contains(_searchQuery) ||
              r.description.toLowerCase().contains(_searchQuery),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthBloc>().state.user;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/requests/new'),
        icon: const Icon(Icons.add),
        label: const Text('Publier'),
      ),
      bottomNavigationBar: const AppBottomNav(currentLocation: '/requests'),
      body: SafeArea(
        child: BlocBuilder<RequestsBloc, RequestsState>(
          builder: (context, state) {
            final categoriesById = <String, Category>{
              for (final category in state.categories) category.id: category,
            };
            final visibleRequests = _applySearch(state.requests);

            return RefreshIndicator(
              onRefresh: () async {
                context.read<RequestsBloc>().add(const RequestsRefreshed());
              },
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: _RequestsHero()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _SearchField(
                        controller: _searchController,
                        hintText: 'Rechercher un service...',
                      ),
                    ),
                  ),
                  if (state.status == RequestsStatus.loading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.status == RequestsStatus.failure)
                    SliverFillRemaining(
                      child: Center(
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
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      sliver: SliverList.list(
                        children: [
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
                          if (visibleRequests.isEmpty)
                            const _EmptyState()
                          else
                            ...visibleRequests.map(
                              (request) {
                                final canInteractAsProvider =
                                    currentUser?.isProvider == true &&
                                        currentUser?.id != request.clientId;
                                final category = categoriesById[request.categoryId];
                                final distanceKm = (_myLat != null &&
                                        _myLng != null &&
                                        request.hasLocation)
                                    ? haversineKm(
                                        _myLat!,
                                        _myLng!,
                                        request.locationLat!,
                                        request.locationLng!,
                                      )
                                    : null;

                                return _RequestCard(
                                  request: request,
                                  category: category,
                                  distanceKm: distanceKm,
                                  canInteractAsProvider: canInteractAsProvider,
                                  onTap: () => context.push('/requests/${request.id}'),
                                  onPropose: () => _openQuickProposalSheet(request),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RequestsHero extends StatelessWidget {
  const _RequestsHero();

  @override
  Widget build(BuildContext context) {
    return const BrandHeader(
      title: 'Demandes ouvertes',
      accentSuffix: 'ouvertes',
      subtitle: 'Explorez les besoins publies pres de chez vous',
    );
  }
}

/// Champ de recherche generique, place sur le fond de page (pas sur le
/// degrade de marque) pour rester coherent quel que soit le theme.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hintText,
  });

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13.5),
        decoration: InputDecoration(
          filled: false,
          hintText: hintText,
          hintStyle: TextStyle(color: fg),
          prefixIcon: Icon(Icons.search, color: fg, size: 20),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.category,
    required this.distanceKm,
    required this.canInteractAsProvider,
    required this.onTap,
    required this.onPropose,
  });

  final ServiceRequest request;
  final Category? category;
  final double? distanceKm;
  final bool canInteractAsProvider;
  final VoidCallback onTap;
  final VoidCallback onPropose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;
    final hasPhotos = request.photos.isNotEmpty;

    final metaParts = <String>[
      if (request.locationAddress != null && request.locationAddress!.trim().isNotEmpty)
        request.locationAddress!.trim(),
      timeAgo(request.createdAt ?? DateTime.now()),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PostAuthorHeader(
                authorName: request.clientName ?? 'Client',
                authorAvatarUrl: request.clientAvatarUrl,
                metaText: metaParts.join(' · '),
              ),
              if (hasPhotos) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          request.photos.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: semantic.cardImageGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: semantic.imageTagBackground,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '\u{1F4F7} ${request.photos.length} photo${request.photos.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: semantic.imageTagForeground,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (category != null) ...[
                Text(
                  category!.label.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 5),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      request.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _UrgencyBadge(urgency: request.urgency),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                request.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (distanceKm != null) ...[
                    Icon(Icons.location_on_outlined, size: 14, color: semantic.metaText),
                    const SizedBox(width: 4),
                    Text(
                      formatDistanceKm(distanceKm!),
                      style: TextStyle(color: semantic.metaText, fontSize: 12),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Icon(Icons.chat_bubble_outline, size: 14, color: semantic.metaText),
                  const SizedBox(width: 4),
                  Text(
                    '${request.proposalsCount} proposition${request.proposalsCount > 1 ? 's' : ''}',
                    style: TextStyle(color: semantic.metaText, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  if (canInteractAsProvider) ...[
                    Expanded(
                      child: FilledButton(
                        onPressed: onPropose,
                        child: const Text('Proposer mes services'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onTap,
                        child: const Text('Voir'),
                      ),
                    ),
                  ] else
                    Expanded(
                      child: FilledButton(
                        onPressed: onTap,
                        child: const Text('Voir'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  const _UrgencyBadge({required this.urgency});

  final String urgency;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final theme = Theme.of(context);
    final isHigh = urgency == 'high';

    final bg = isHigh ? semantic.urgentBackground : theme.colorScheme.surfaceContainerHighest;
    final fg = isHigh ? semantic.urgentForeground : theme.colorScheme.onSurfaceVariant;
    final border = isHigh ? semantic.urgentBorder : null;

    final label = switch (urgency) {
      'high' => 'URGENT',
      'low' => 'FLEXIBLE',
      _ => 'NORMAL',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
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
                label: Text(category.label),
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
    required this.metaText,
    this.authorAvatarUrl,
  });

  final String authorName;
  final String metaText;
  final String? authorAvatarUrl;

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
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
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
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                metaText,
                style: TextStyle(color: context.semanticColors.metaText, fontSize: 11.5),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/widgets/gradient_header.dart';
import '../../../requests/domain/entities/category.dart';
import '../../../requests/domain/repositories/requests_repository.dart';
import '../../domain/repositories/provider_profile_repository.dart';
import '../bloc/provider_profile_bloc.dart';
import '../bloc/provider_profile_event.dart';
import '../bloc/provider_profile_state.dart';

class ProviderProfilePage extends StatelessWidget {
  const ProviderProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProviderProfileBloc(context.read<ProviderProfileRepository>())
        ..add(const ProviderProfileStarted()),
      child: const _ProviderProfileView(),
    );
  }
}

class _ProviderProfileView extends StatefulWidget {
  const _ProviderProfileView();

  @override
  State<_ProviderProfileView> createState() => _ProviderProfileViewState();
}

class _ProviderProfileViewState extends State<_ProviderProfileView> {
  final _bioController = TextEditingController();
  final _skillController = TextEditingController();
  final _locationService = const LocationService();
  final _imagePicker = ImagePicker();

  bool _initializedFromProfile = false;
  bool _capturingLocation = false;
  bool _loadingCategories = true;

  List<String> _skills = [];
  final Set<String> _selectedCategoryIds = {};
  double _radiusKm = 20;
  double? _lat;
  double? _lng;
  String? _city;
  String? _address;
  List<Category> _categories = const [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await context.read<RequestsRepository>().getCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (_) {
      if (!mounted) return;
      setState(() => _categories = const []);
    } finally {
      if (mounted) {
        setState(() => _loadingCategories = false);
      }
    }
  }

  void _syncFromProfile(ProviderProfileState state) {
    if (_initializedFromProfile) return;
    _initializedFromProfile = true;
    final profile = state.profile;
    _bioController.text = profile.bio ?? '';
    _skills = [...profile.skills];
    _selectedCategoryIds
      ..clear()
      ..addAll(profile.categoryIds);
    _radiusKm = profile.radiusKm;
    _lat = profile.locationLat;
    _lng = profile.locationLng;
    _city = profile.locationCity;
    _address = profile.locationAddress;
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _capturingLocation = true);
    try {
      final result = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
        _city = result.city;
        _address = result.address ??
            '${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _capturingLocation = false);
      }
    }
  }

  void _addSkill() {
    final value = _skillController.text.trim();
    if (value.isEmpty || _skills.contains(value)) {
      _skillController.clear();
      return;
    }
    setState(() {
      _skills = [..._skills, value];
      _skillController.clear();
    });
  }

  Future<void> _pickImage({required bool isCertificate}) async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        requestFullMetadata: false,
      );
      if (!mounted || file == null) return;

      context.read<ProviderProfileBloc>().add(
            isCertificate
                ? ProviderProfileCertificateImageAdded(file.path)
                : ProviderProfilePortfolioImageAdded(file.path),
          );
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selection d\'image indisponible: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de choisir la photo: $e')),
      );
    }
  }

  void _save() {
    context.read<ProviderProfileBloc>().add(
          ProviderProfileSaved(
            bio: _bioController.text.trim(),
            skills: _skills,
            categoryIds: _selectedCategoryIds.toList(),
            radiusKm: _radiusKm,
            locationLat: _lat,
            locationLng: _lng,
            locationCity: _city,
            locationAddress: _address,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<ProviderProfileBloc, ProviderProfileState>(
          listener: (context, state) {
            if (state.status == ProviderProfileStatus.success) {
              _syncFromProfile(state);
            }
            if (state.status == ProviderProfileStatus.failure && state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage!)),
              );
            }
          },
          builder: (context, state) {
            _syncFromProfile(state);
            final saving = state.status == ProviderProfileStatus.saving;
            final loading = state.status == ProviderProfileStatus.loading;

            return Column(
              children: [
                GradientHeader(
                  title: 'Profil prestataire',
                  subtitle: 'Aidez les clients a mieux vous connaitre',
                  onBack: () => context.pop(),
                ),
                if (loading)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (state.profile.isVerifiedProvider)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Chip(
                              avatar: const Icon(Icons.verified, size: 18),
                              label: const Text('Prestataire verifie'),
                            ),
                          ),
                        if (state.profile.totalReviews > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.star, size: 18, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(
                                  '${state.profile.avgRating.toStringAsFixed(1)} '
                                  '(${state.profile.totalReviews} avis)',
                                ),
                              ],
                            ),
                          ),
                        Text('A propos', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _bioController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Bio',
                            hintText: 'Presentez votre experience et vos services...',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text('Competences', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _skillController,
                                decoration: const InputDecoration(
                                  hintText: 'Ex: Electricite domestique',
                                ),
                                onSubmitted: (_) => _addSkill(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filledTonal(
                              onPressed: _addSkill,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                        if (_skills.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _skills
                                .map(
                                  (skill) => Chip(
                                    label: Text(skill),
                                    onDeleted: () {
                                      setState(() => _skills = _skills
                                          .where((s) => s != skill)
                                          .toList());
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          'Categories d\'intervention',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (_loadingCategories)
                          const LinearProgressIndicator()
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categories
                                .map(
                                  (category) => FilterChip(
                                    label: Text(category.label),
                                    selected: _selectedCategoryIds.contains(category.id),
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedCategoryIds.add(category.id);
                                        } else {
                                          _selectedCategoryIds.remove(category.id);
                                        }
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        const SizedBox(height: 24),
                        Text(
                          'Zone d\'intervention',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (_address != null && _address!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.my_location, size: 18),
                                const SizedBox(width: 6),
                                Expanded(child: Text(_address!)),
                              ],
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: _capturingLocation ? null : _useCurrentLocation,
                          icon: _capturingLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.location_searching),
                          label: Text(
                            _capturingLocation
                                ? 'Localisation...'
                                : (_address == null
                                    ? 'Definir ma position'
                                    : 'Mettre a jour ma position'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Rayon d\'intervention : ${_radiusKm.round()} km'),
                        Slider(
                          value: _radiusKm.clamp(1, 100),
                          min: 1,
                          max: 100,
                          divisions: 99,
                          label: '${_radiusKm.round()} km',
                          onChanged: (value) => setState(() => _radiusKm = value),
                        ),
                        const SizedBox(height: 24),
                        Text('Portfolio', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        _ImageGrid(
                          urls: state.profile.portfolio,
                          uploading: state.uploadingPortfolio,
                          onAdd: () => _pickImage(isCertificate: false),
                          onRemove: (url) => context
                              .read<ProviderProfileBloc>()
                              .add(ProviderProfilePortfolioImageRemoved(url)),
                        ),
                        const SizedBox(height: 24),
                        Text('Certificats', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Diplomes, attestations ou justificatifs professionnels',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        _ImageGrid(
                          urls: state.profile.certificates,
                          uploading: state.uploadingCertificate,
                          onAdd: () => _pickImage(isCertificate: true),
                          onRemove: (url) => context
                              .read<ProviderProfileBloc>()
                              .add(ProviderProfileCertificateImageRemoved(url)),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: saving ? null : _save,
                            icon: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('Enregistrer'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({
    required this.urls,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> urls;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ...urls.map(
          (url) => Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 92,
                    height: 92,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: IconButton(
                  onPressed: () => onRemove(url),
                  icon: const Icon(Icons.cancel, size: 20),
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: uploading ? null : onAdd,
          child: Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined),
          ),
        ),
      ],
    );
  }
}

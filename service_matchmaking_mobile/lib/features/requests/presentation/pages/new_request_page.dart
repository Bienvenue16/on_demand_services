import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../../../../core/location/location_service.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/requests_repository.dart';
import '../bloc/request_create_bloc.dart';
import '../bloc/request_create_event.dart';
import '../bloc/request_create_state.dart';

class NewRequestPage extends StatefulWidget {
  const NewRequestPage({super.key});

  @override
  State<NewRequestPage> createState() => _NewRequestPageState();
}

class _NewRequestPageState extends State<NewRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _locationService = const LocationService();

  String? _selectedCategoryId;
  String _urgency = 'medium';
  bool _loadingCategories = true;
  bool _uploadingPhotos = false;
  bool _capturingLocation = false;
  double? _capturedLat;
  double? _capturedLng;
  List<Category> _categories = const [];
  List<XFile> _pickedPhotos = const [];

  Future<void> _useCurrentLocation() async {
    setState(() => _capturingLocation = true);
    try {
      final result = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _capturedLat = result.latitude;
        _capturedLng = result.longitude;
        _addressController.text = (result.address != null && result.address!.isNotEmpty)
            ? result.address!
            : '${result.latitude.toStringAsFixed(5)}, ${result.longitude.toStringAsFixed(5)}';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _capturingLocation = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final repository = context.read<RequestsRepository>();
      final categories = await repository.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCategories = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RequestCreateBloc(context.read<RequestsRepository>()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Nouvelle demande')),
        body: BlocConsumer<RequestCreateBloc, RequestCreateState>(
          listener: (context, state) {
            if (state.status == RequestCreateStatus.success) {
              final requestId = state.createdRequestId;
              if (requestId != null && requestId.isNotEmpty) {
                context.go('/requests/$requestId');
              } else {
                context.go('/requests');
              }
            }

            if (state.status == RequestCreateStatus.failure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? 'Erreur lors de la creation'),
                ),
              );
            }
          },
          builder: (context, state) {
            final submitting = state.status == RequestCreateStatus.submitting;
            final isBusy = submitting || _uploadingPhotos;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loadingCategories)
                      const LinearProgressIndicator()
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Categorie',
                        ),
                        items: _categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category.id,
                                child: Text(category.name),
                              ),
                            )
                            .toList(),
                        onChanged: submitting
                            ? null
                            : (value) {
                                setState(() => _selectedCategoryId = value);
                              },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Categorie requise';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Titre'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Titre requis';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Description requise';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      onChanged: (_) {
                        if (_capturedLat != null || _capturedLng != null) {
                          setState(() {
                            _capturedLat = null;
                            _capturedLng = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Adresse (optionnel)',
                        suffixIcon: _capturedLat != null
                            ? Tooltip(
                                message: 'Position GPS capturee',
                                child: Icon(
                                  Icons.my_location,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: (isBusy || _capturingLocation) ? null : _useCurrentLocation,
                      icon: _capturingLocation
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.location_searching),
                      label: Text(
                        _capturingLocation ? 'Localisation...' : 'Utiliser ma position',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Photos (${_pickedPhotos.length}/5)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: isBusy
                              ? null
                              : () async {
                                  try {
                                    final files = await _imagePicker.pickMultiImage(
                                      requestFullMetadata: false,
                                    );
                                    if (!mounted || files.isEmpty) return;

                                    setState(() {
                                      final merged = [..._pickedPhotos, ...files];
                                      _pickedPhotos = merged.take(5).toList();
                                    });
                                  } on PlatformException catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Selection d\'image indisponible: ${e.message ?? e.code}',
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Impossible de choisir les photos: $e'),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Ajouter'),
                        ),
                      ],
                    ),
                    if (_pickedPhotos.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _pickedPhotos
                            .map(
                              (photo) => Chip(
                                avatar: const Icon(Icons.image_outlined, size: 16),
                                label: SizedBox(
                                  width: 140,
                                  child: Text(
                                    photo.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                onDeleted: isBusy
                                    ? null
                                    : () {
                                        setState(() {
                                          _pickedPhotos = _pickedPhotos
                                              .where((item) => item.path != photo.path)
                                              .toList();
                                        });
                                      },
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'low', label: Text('Flexible')),
                        ButtonSegment(value: 'medium', label: Text('Normal')),
                        ButtonSegment(value: 'high', label: Text('Urgent')),
                      ],
                      selected: {_urgency},
                      onSelectionChanged: isBusy
                          ? null
                          : (value) {
                              setState(() => _urgency = value.first);
                            },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: isBusy
                            ? null
                            : () async {
                                if (!_formKey.currentState!.validate()) {
                                  return;
                                }

                                final repository = context.read<RequestsRepository>();
                                final uploadedPhotoUrls = <String>[];
                                if (_pickedPhotos.isNotEmpty) {
                                  setState(() => _uploadingPhotos = true);
                                  try {
                                    for (final photo in _pickedPhotos) {
                                      final uploaded = await repository.uploadRequestImage(photo.path);
                                      if (uploaded != null && uploaded.isNotEmpty) {
                                        uploadedPhotoUrls.add(uploaded);
                                      }
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _uploadingPhotos = false);
                                    }
                                  }
                                }

                                context.read<RequestCreateBloc>().add(
                                      RequestCreateSubmitted(
                                        categoryId: _selectedCategoryId!,
                                        title: _titleController.text.trim(),
                                        description: _descriptionController.text.trim(),
                                        urgency: _urgency,
                                        locationAddress: _addressController.text.trim().isEmpty
                                            ? null
                                            : _addressController.text.trim(),
                                        locationLat: _capturedLat,
                                        locationLng: _capturedLng,
                                        photos: uploadedPhotoUrls,
                                      ),
                                    );
                              },
                        icon: isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.publish),
                        label: const Text('Publier ma demande'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

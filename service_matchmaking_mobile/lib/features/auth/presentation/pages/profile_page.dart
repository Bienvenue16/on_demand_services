import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/app_bottom_nav.dart';
import '../../domain/repositories/auth_repository.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/profile_bloc.dart';
import '../bloc/profile_event.dart';
import '../bloc/profile_state.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  Future<void> _pickAndUploadAvatar(BuildContext context) async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        requestFullMetadata: false,
      );
      if (!context.mounted || file == null) {
        return;
      }

      context.read<ProfileBloc>().add(
            ProfileAvatarUploadRequested(filePath: file.path),
          );
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selection d\'image indisponible: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de choisir la photo: $e')),
      );
    }
  }

  String _initialsFromName(String fullName) {
    if (fullName.trim().isEmpty) {
      return 'U';
    }

    return fullName
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileBloc(context.read<AuthRepository>())
        ..add(const ProfileStarted()),
      child: Scaffold(
        bottomNavigationBar: const AppBottomNav(currentLocation: '/profile'),
        body: SafeArea(
          child: BlocConsumer<ProfileBloc, ProfileState>(
            listenWhen: (prev, next) => prev.user != next.user,
            listener: (context, state) {
              final user = state.user;
              if (user != null) {
                _fullNameController.text = user.fullName;
                _phoneController.text = user.phone ?? '';
              }
            },
            builder: (context, state) {
              final user = state.user;
              final loading = state.status == ProfileStatus.loading;
              final saving = state.status == ProfileStatus.saving;

              if (loading && user == null) {
                return const Center(child: CircularProgressIndicator());
              }

              if (user == null) {
                return const Center(child: Text('Profil indisponible'));
              }

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
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
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => context.pop(),
                                icon: const Icon(Icons.arrow_back),
                              ),
                              const Spacer(),
                              FilledButton.tonalIcon(
                                onPressed: () {
                                  context.read<AuthBloc>().add(const AuthLogoutRequested());
                                },
                                icon: const Icon(Icons.logout),
                                label: const Text('Deconnexion'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 42,
                                child: ClipOval(
                                  child: (user.avatarUrl != null &&
                                          user.avatarUrl!.trim().isNotEmpty)
                                      ? Image.network(
                                          user.avatarUrl!,
                                          width: 84,
                                          height: 84,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Center(
                                            child: Text(_initialsFromName(user.fullName)),
                                          ),
                                        )
                                      : Center(
                                          child: Text(_initialsFromName(user.fullName)),
                                        ),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: IconButton.filledTonal(
                                  onPressed: saving
                                      ? null
                                      : () => _pickAndUploadAvatar(context),
                                  icon: saving
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.camera_alt_outlined, size: 18),
                                  tooltip: 'Changer avatar',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: saving
                                ? null
                                : () => _pickAndUploadAvatar(context),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Modifier la photo'),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.fullName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(user.email),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              Chip(label: Text(user.role.toUpperCase())),
                              if (user.isVerified)
                                const Chip(label: Text('VERIFIE')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Informations personnelles',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _fullNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nom complet',
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Nom requis';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _phoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'Telephone',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (state.status == ProfileStatus.failure &&
                                    state.errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      state.errorMessage!,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: saving
                                        ? null
                                        : () {
                                            if (!_formKey.currentState!.validate()) {
                                              return;
                                            }
                                            context.read<ProfileBloc>().add(
                                                  ProfileUpdated(
                                                    fullName: _fullNameController.text.trim(),
                                                    phone: _phoneController.text.trim().isEmpty
                                                        ? null
                                                        : _phoneController.text.trim(),
                                                    avatarUrl: user.avatarUrl,
                                                  ),
                                                );
                                            context.read<AuthBloc>().add(
                                                  const AuthAppStarted(),
                                                );
                                          },
                                    icon: saving
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.save_outlined),
                                    label: const Text('Enregistrer'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

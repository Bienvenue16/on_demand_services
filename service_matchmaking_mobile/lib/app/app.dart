import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network/api_client.dart';
import '../core/network/token_storage.dart';
import '../core/theme/theme_cubit.dart';
import '../core/theme/theme_preference_repository.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/messages/data/repositories/messages_repository_impl.dart';
import '../features/messages/domain/repositories/messages_repository.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/bloc/auth_event.dart';
import '../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../features/notifications/domain/repositories/notifications_repository.dart';
import '../features/provider_profile/data/repositories/provider_profile_repository_impl.dart';
import '../features/provider_profile/domain/repositories/provider_profile_repository.dart';
import '../features/requests/data/repositories/requests_repository_impl.dart';
import '../features/requests/domain/repositories/requests_repository.dart';
import '../features/requests/presentation/bloc/requests_bloc.dart';
import 'router.dart';
import 'theme.dart';

class ServiceMatchApp extends StatefulWidget {
  const ServiceMatchApp({super.key});

  @override
  State<ServiceMatchApp> createState() => _ServiceMatchAppState();
}

class _ServiceMatchAppState extends State<ServiceMatchApp> {
  late final TokenStorage _tokenStorage;
  late final ApiClient _apiClient;
  late final AuthRepositoryImpl _authRepository;
  late final RequestsRepositoryImpl _requestsRepository;
  late final NotificationsRepositoryImpl _notificationsRepository;
  late final MessagesRepositoryImpl _messagesRepository;
  late final ProviderProfileRepositoryImpl _providerProfileRepository;
  late final AuthBloc _authBloc;
  late final RequestsBloc _requestsBloc;
  late final ThemeCubit _themeCubit;
  late final router = AppRouter.create(_authBloc);

  @override
  void initState() {
    super.initState();
    _tokenStorage = TokenStorage(const FlutterSecureStorage());
    _apiClient = ApiClient(_tokenStorage);
    _authRepository = AuthRepositoryImpl(_apiClient);
    _requestsRepository = RequestsRepositoryImpl(_apiClient);
    _notificationsRepository = NotificationsRepositoryImpl(_apiClient);
    _messagesRepository = MessagesRepositoryImpl(_apiClient);
    _providerProfileRepository = ProviderProfileRepositoryImpl(_apiClient);
    _authBloc = AuthBloc(_authRepository)..add(const AuthAppStarted());
    _requestsBloc = RequestsBloc(_requestsRepository);
    _themeCubit = ThemeCubit(ThemePreferenceRepository());
  }

  @override
  void dispose() {
    _authBloc.close();
    _requestsBloc.close();
    _themeCubit.close();
    _apiClient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: _authRepository),
        RepositoryProvider<RequestsRepository>.value(value: _requestsRepository),
        RepositoryProvider<NotificationsRepository>.value(value: _notificationsRepository),
        RepositoryProvider<MessagesRepository>.value(value: _messagesRepository),
        RepositoryProvider<ProviderProfileRepository>.value(value: _providerProfileRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _authBloc),
          BlocProvider.value(value: _requestsBloc),
          BlocProvider.value(value: _themeCubit),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          bloc: _themeCubit,
          builder: (context, themeMode) {
            return MaterialApp.router(
              title: 'Service Matchmaking',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: themeMode,
              routerConfig: router,
            );
          },
        ),
      ),
    );
  }
}

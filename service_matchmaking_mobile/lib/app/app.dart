import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/network/api_client.dart';
import '../core/network/token_storage.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/messages/data/repositories/messages_repository_impl.dart';
import '../features/messages/domain/repositories/messages_repository.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/bloc/auth_event.dart';
import '../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../features/notifications/domain/repositories/notifications_repository.dart';
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
  late final AuthBloc _authBloc;
  late final RequestsBloc _requestsBloc;
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
    _authBloc = AuthBloc(_authRepository)..add(const AuthAppStarted());
    _requestsBloc = RequestsBloc(_requestsRepository);
  }

  @override
  void dispose() {
    _authBloc.close();
    _requestsBloc.close();
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
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _authBloc),
          BlocProvider.value(value: _requestsBloc),
        ],
        child: MaterialApp.router(
          title: 'Service Matchmaking',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
  }
}

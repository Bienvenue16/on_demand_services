import 'package:go_router/go_router.dart';

import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/bloc/auth_state.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/auth/presentation/pages/profile_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/reset_password_page.dart';
import '../features/messages/presentation/pages/messages_page.dart';
import '../features/notifications/presentation/pages/notifications_page.dart';
import '../features/provider_profile/presentation/pages/provider_profile_page.dart';
import '../features/requests/presentation/pages/my_proposals_page.dart';
import '../features/requests/presentation/pages/my_requests_page.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/requests/presentation/pages/new_request_page.dart';
import '../features/requests/presentation/pages/request_detail_page.dart';
import '../features/requests/presentation/pages/requests_page.dart';
import 'go_router_refresh_stream.dart';

class AppRouter {
  AppRouter._();

  static GoRouter create(AuthBloc authBloc) {
    return GoRouter(
      initialLocation: '/requests',
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
      redirect: (context, state) {
        final authState = authBloc.state;
        final location = state.uri.path;
        final isPublicAuthPage =
          location == '/login' ||
          location == '/register' ||
          location == '/forgot-password' ||
          location == '/reset-password';

        if (authState.status == AuthStatus.unknown ||
            authState.status == AuthStatus.loading) {
          return null;
        }

        if (!authState.isAuthenticated) {
          return isPublicAuthPage ? null : '/login';
        }

        if (isPublicAuthPage) {
          return '/requests';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginPage(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordPage(),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) {
            final token = state.uri.queryParameters['token'];
            return ResetPasswordPage(initialToken: token);
          },
        ),
        GoRoute(
          path: '/requests',
          builder: (context, state) => const RequestsPage(),
        ),
        GoRoute(
          path: '/requests/new',
          builder: (context, state) => const NewRequestPage(),
        ),
        GoRoute(
          path: '/requests/:id',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return RequestDetailPage(requestId: id);
          },
        ),
        GoRoute(
          path: '/my-requests',
          builder: (context, state) => const MyRequestsPage(),
        ),
        GoRoute(
          path: '/provider/proposals',
          builder: (context, state) => const MyProposalsPage(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsPage(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfilePage(),
        ),
        GoRoute(
          path: '/provider/profile',
          builder: (context, state) => const ProviderProfilePage(),
        ),
        GoRoute(
          path: '/messages',
          builder: (context, state) {
            final roomId = state.uri.queryParameters['roomId'];
            return MessagesPage(initialRoomId: roomId);
          },
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentLocation,
  });

  final String currentLocation;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    final isProvider = user?.isProvider == true;

    final items = <_NavItem>[
      const _NavItem('/requests', 'Demandes', Icons.home_outlined, Icons.home),
      _NavItem(
        isProvider ? '/provider/proposals' : '/my-requests',
        isProvider ? 'Offres' : 'Mes demandes',
        Icons.assignment_outlined,
        Icons.assignment,
      ),
      const _NavItem('/messages', 'Messages', Icons.chat_bubble_outline, Icons.chat_bubble),
      const _NavItem('/notifications', 'Notifs', Icons.notifications_outlined, Icons.notifications),
      const _NavItem('/profile', 'Profil', Icons.person_outline, Icons.person),
    ];

    int selectedIndex = 0;
    for (var i = 0; i < items.length; i++) {
      if (currentLocation.startsWith(items[i].route)) {
        selectedIndex = i;
        break;
      }
      if (items[i].route == '/my-requests' && currentLocation.startsWith('/requests')) {
        selectedIndex = 0;
      }
    }

    return NavigationBar(
      selectedIndex: selectedIndex,
      destinations: items
          .map(
            (item) => NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.selectedIcon),
              label: item.label,
            ),
          )
          .toList(),
      onDestinationSelected: (index) {
        final target = items[index].route;
        if (currentLocation != target) {
          context.go(target);
        }
      },
    );
  }
}

class _NavItem {
  const _NavItem(this.route, this.label, this.icon, this.selectedIcon);

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

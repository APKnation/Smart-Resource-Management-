import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_state.dart';
import 'core/constants.dart';
import 'core/utils.dart';
import 'models/models.dart';

/// Responsive scaffold: rail on wide screens, drawer + bottom bar on narrow.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.state, required this.child});

  final AppState state;
  final Widget child;

  static const _userDestinations = [
    (route: Routes.dashboard, label: 'Dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
    (route: Routes.resources, label: 'Resources', icon: Icons.library_books_outlined, activeIcon: Icons.library_books),
    (route: Routes.favorites, label: 'Favorites', icon: Icons.star_border, activeIcon: Icons.star),
    (route: Routes.notifications, label: 'Notifications', icon: Icons.notifications_outlined, activeIcon: Icons.notifications),
    (route: Routes.profile, label: 'Profile', icon: Icons.person_outline, activeIcon: Icons.person),
  ];

  static const _staffDestinations = [
    (route: Routes.myUploads, label: 'My Uploads', icon: Icons.upload_file_outlined, activeIcon: Icons.upload_file),
    (route: Routes.upload, label: 'Upload', icon: Icons.add_circle_outline, activeIcon: Icons.add_circle),
  ];

  static const _adminDestinations = [
    (route: Routes.approvals, label: 'Approvals', icon: Icons.fact_check_outlined, activeIcon: Icons.fact_check),
    (route: Routes.categories, label: 'Categories', icon: Icons.category_outlined, activeIcon: Icons.category),
    (route: Routes.users, label: 'Users', icon: Icons.groups_outlined, activeIcon: Icons.groups),
    (route: Routes.roles, label: 'Roles', icon: Icons.verified_user_outlined, activeIcon: Icons.verified_user),
    (route: Routes.reports, label: 'Reports', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart),
    (route: Routes.audit, label: 'Audit Trail', icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long),
    (route: Routes.settings, label: 'Settings', icon: Icons.settings_outlined, activeIcon: Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final goState = GoRouterState.of(context);
    final loc = goState.matchedLocation;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final profile = state.me;

    final destinations = <({String route, String label, IconData icon, IconData activeIcon})>[
      ..._userDestinations,
      if (state.canUpload) ..._staffDestinations,
      if (state.canManageResources) ..._adminDestinations,
    ];

    final selectedIndex = destinations.indexWhere((d) =>
        loc == d.route ||
        (d.route == Routes.resources && loc.startsWith('${Routes.resources}/')) ||
        (d.route == Routes.dashboard && loc == Routes.dashboard));

    Widget body = child;

    if (!wide) {
      body = Scaffold(
        appBar: AppBar(
          title: Text(_titleFor(loc)),
          actions: [
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => context.push(Routes.notifications),
              icon: Badge(
                isLabelVisible: state.unreadNotifications > 0,
                label: Text('${state.unreadNotifications}'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          ],
        ),
        drawer: _Drawer(state: state, destinations: destinations),
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
          onDestinationSelected: (i) => context.go(destinations[i].route),
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: d.route == Routes.notifications
                    ? Badge(
                        isLabelVisible: state.unreadNotifications > 0,
                        child: Icon(d.icon),
                      )
                    : Icon(d.icon),
                selectedIcon: Icon(d.activeIcon),
                label: d.label,
              ),
          ],
        ),
      );
    } else {
      body = Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1200,
              selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
              onDestinationSelected: (i) => context.go(destinations[i].route),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    CircleAvatar(
                      child: Text(initialsOf(profile?.fullName ?? profile?.email ?? '?')),
                    ),
                    const SizedBox(height: 8),
                    if (profile != null)
                      Text(
                        profile.role.label,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: d.route == Routes.notifications
                        ? Badge(
                            isLabelVisible: state.unreadNotifications > 0,
                            child: Icon(d.icon),
                          )
                        : Icon(d.icon),
                    selectedIcon: Icon(d.activeIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return AppStateScope(
      state: state,
      child: body,
    );
  }

  String _titleFor(String loc) {
    for (final d in [..._userDestinations, ..._staffDestinations, ..._adminDestinations]) {
      if (loc == d.route) return d.label;
    }
    if (loc.startsWith('${Routes.resources}/')) return 'Resource';
    if (loc == Routes.upload) return 'Upload Resource';
    return 'E-Resource Portal';
  }
}

class _Drawer extends StatelessWidget {
  const _Drawer({required this.state, required this.destinations});

  final AppState state;
  final List<({String route, String label, IconData icon, IconData activeIcon})>
      destinations;

  @override
  Widget build(BuildContext context) {
    final profile = state.me;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(profile?.fullName ?? '—'),
            accountEmail: Text(profile?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              child: Text(initialsOf(profile?.fullName ?? '?')),
            ),
          ),
          for (final d in destinations)
            ListTile(
              leading: Icon(d.icon),
              title: Text(d.label),
              selected: GoRouterState.of(context).matchedLocation == d.route,
              onTap: () {
                Navigator.of(context).pop();
                context.go(d.route);
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign out'),
            onTap: () async {
              Navigator.of(context).pop();
              await state.signOut();
              if (context.mounted) context.go(Routes.login);
            },
          ),
        ],
      ),
    );
  }
}

import 'package:go_router/go_router.dart';

import 'app_state.dart';
import 'core/constants.dart';
import 'screens/admin/approvals_screen.dart';
import 'screens/admin/audit_screen.dart';
import 'screens/admin/categories_screen.dart';
import 'screens/admin/reports_screen.dart';
import 'screens/admin/roles_screen.dart';
import 'screens/admin/settings_screen.dart';
import 'screens/admin/users_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/my_uploads_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/resource_detail_screen.dart';
import 'screens/resource_form_screen.dart';
import 'screens/resources_screen.dart';
import 'screens/hrms/inventory_screen.dart';
import 'screens/hrms/movements_screen.dart';
import 'screens/hrms/facilities_screen.dart';
import 'screens/hrms/dashboard_screen.dart';
import 'screens/hrms/workflows_screen.dart';
import 'shell.dart';

GoRouter buildRouter(AppState state) {
  return GoRouter(
    initialLocation: Routes.dashboard,
    redirect: (context, goState) {
      final loggedIn = state.loggedIn;
      final loc = goState.matchedLocation;
      final onAuthPage = loc == Routes.login;
      if (!loggedIn && !onAuthPage) return Routes.login;
      if (loggedIn && onAuthPage) return Routes.dashboard;
      return null;
    },
    refreshListenable: state,
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, goState) => LoginScreen(state: state),
      ),
      ShellRoute(
        builder: (context, goState, child) =>
            AppShell(state: state, child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            builder: (context, goState) => const HrmsDashboardScreen(),
          ),
          GoRoute(
            path: Routes.inventory,
            builder: (context, goState) => const InventoryScreen(),
          ),
          GoRoute(
            path: Routes.movements,
            builder: (context, goState) => const MovementsScreen(),
          ),
          GoRoute(
            path: Routes.facilities,
            builder: (context, goState) => const FacilitiesScreen(),
          ),
          GoRoute(
            path: Routes.requests,
            builder: (context, state) =>
                const HrmsWorkflowsScreen(module: HrmsModule.requests),
          ),
          GoRoute(
            path: Routes.transfers,
            builder: (context, state) =>
                const HrmsWorkflowsScreen(module: HrmsModule.transfers),
          ),
          GoRoute(
            path: Routes.procurement,
            builder: (context, state) =>
                const HrmsWorkflowsScreen(module: HrmsModule.procurement),
          ),
          GoRoute(
            path: Routes.equipment,
            builder: (context, state) =>
                const HrmsWorkflowsScreen(module: HrmsModule.equipment),
          ),
          GoRoute(
            path: Routes.maintenance,
            builder: (context, state) =>
                const HrmsWorkflowsScreen(module: HrmsModule.maintenance),
          ),
          GoRoute(
            path: Routes.hrmsReports,
            builder: (context, state) =>
                const HrmsWorkflowsScreen(module: HrmsModule.reports),
          ),
          GoRoute(
            path: Routes.hospitalUsers,
            builder: (context, state) =>
                const HrmsWorkflowsScreen(module: HrmsModule.users),
          ),
          GoRoute(
            path: Routes.resources,
            builder: (context, goState) => const ResourcesScreen(),
          ),
          GoRoute(
            path: Routes.myUploads,
            builder: (context, goState) => const MyUploadsScreen(),
          ),
          GoRoute(
            path: Routes.upload,
            builder: (context, goState) => const ResourceFormScreen(),
          ),
          GoRoute(
            path: '${Routes.resources}/:id',
            builder: (context, goState) =>
                ResourceDetailScreen(resourceId: goState.pathParameters['id']!),
          ),
          GoRoute(
            path: '${Routes.resources}/:id/edit',
            builder: (context, goState) =>
                ResourceFormScreen(resourceId: goState.pathParameters['id']),
          ),
          GoRoute(
            path: Routes.favorites,
            builder: (context, goState) => const FavoritesScreen(),
          ),
          GoRoute(
            path: Routes.notifications,
            builder: (context, goState) => const NotificationsScreen(),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (context, goState) => const ProfileScreen(),
          ),
          GoRoute(
            path: Routes.approvals,
            builder: (context, goState) => const ApprovalsScreen(),
          ),
          GoRoute(
            path: Routes.categories,
            builder: (context, goState) => const CategoriesScreen(),
          ),
          GoRoute(
            path: Routes.users,
            builder: (context, goState) => const UsersScreen(),
          ),
          GoRoute(
            path: Routes.roles,
            builder: (context, goState) => const RolesScreen(),
          ),
          GoRoute(
            path: Routes.reports,
            builder: (context, goState) => const ReportsScreen(),
          ),
          GoRoute(
            path: Routes.audit,
            builder: (context, goState) => const AuditScreen(),
          ),
          GoRoute(
            path: Routes.settings,
            builder: (context, goState) => const AdminSettingsScreen(),
          ),
        ],
      ),
    ],
  );
}

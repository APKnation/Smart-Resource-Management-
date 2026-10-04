import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/models.dart';
import 'services/admin_service.dart';
import 'services/auth_service.dart';
import 'services/resource_service.dart';

export 'services/resource_service.dart' show ResourceQuery;

/// Central app state: session, profile, role checks, favorites, notifications.
class AppState extends ChangeNotifier {
  final AuthService auth = AuthService();
  final ResourceService resources = ResourceService();
  final AdminService admin = AdminService();
  final NotificationService notifications = NotificationService();

  Profile? profile;
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSub;
  Set<String> _favoriteIds = {};
  Map<String, dynamic> _settings = {};
  int _unread = 0;

  Profile? get me => profile;
  bool get loggedIn => auth.currentSession != null;

  bool get isAdmin => profile?.role == UserRole.admin;
  bool get isLibrarian => profile?.role == UserRole.librarian;
  bool get isStaffLevel =>
      profile != null &&
      (profile!.role == UserRole.admin ||
          profile!.role == UserRole.librarian ||
          profile!.role == UserRole.staff);
  bool get canManageResources => isAdmin || isLibrarian;
  bool get canApprove => canManageResources;
  bool get canUpload => isStaffLevel;

  Set<String> get favoriteIds => _favoriteIds;
  Map<String, dynamic> get settings => _settings;
  int get unreadNotifications => _unread;

  Future<void> init() async {
    _authSub = auth.onAuthStateChange.listen((event) async {
      switch (event.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.initialSession:
          await refreshProfile();
          await refreshFavorites();
          await refreshSettings();
          await refreshUnread();
          _subscribeRealtime();
          break;
        case AuthChangeEvent.signedOut:
          profile = null;
          _favoriteIds = {};
          _unread = 0;
          _channel?.unsubscribe();
          _channel = null;
          break;
        default:
          break;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> refreshProfile() async {
    profile = await auth.ensureProfile();
    if (profile != null && !profile!.isActive) {
      await signOut();
    }
  }

  Future<void> refreshFavorites() async {
    if (!loggedIn) return;
    _favoriteIds = (await resources.favoriteIds()).toSet();
  }

  Future<void> refreshSettings() async {
    if (!loggedIn) return;
    try {
      _settings = await admin.settings();
    } catch (_) {
      _settings = {};
    }
  }

  Future<void> refreshUnread() async {
    if (!loggedIn) return;
    try {
      _unread = await notifications.unreadCount();
    } catch (_) {
      _unread = 0;
    }
    notifyListeners();
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    _channel = notifications.subscribe((n) {
      _unread += 1;
      notifyListeners();
    });
  }

  bool isFavorite(String resourceId) => _favoriteIds.contains(resourceId);

  Future<void> toggleFavorite(String resourceId) async {
    final isFav = isFavorite(resourceId);
    await resources.toggleFavorite(resourceId, !isFav);
    if (isFav) {
      _favoriteIds.remove(resourceId);
    } else {
      _favoriteIds.add(resourceId);
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    await auth.signIn(email, password);
    await refreshProfile();
    await refreshFavorites();
    await refreshSettings();
    await refreshUnread();
    _subscribeRealtime();
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    String? department,
    String? institution,
  }) async {
    await auth.register(
      email: email,
      password: password,
      fullName: fullName,
      department: department,
      institution: institution,
    );
  }

  Future<void> signOut() async {
    await auth.signOut();
    profile = null;
    _favoriteIds = {};
    _unread = 0;
    _channel?.unsubscribe();
    _channel = null;
    notifyListeners();
  }
}

/// InheritedWidget so screens can read AppState without constructor params.
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in widget tree');
    return scope!.notifier!;
  }
}

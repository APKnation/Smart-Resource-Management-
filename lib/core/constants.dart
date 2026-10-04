/// App-wide constants.
library;

class App {
  static const name = 'E-Resource Portal';
  static const version = '1.0.0+1';
}

/// Route paths used across the app.
class Routes {
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/';
  static const resources = '/resources';
  static const myUploads = '/my-uploads';
  static const upload = '/resources/new';
  static const favorites = '/favorites';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const approvals = '/admin/approvals';
  static const categories = '/admin/categories';
  static const users = '/admin/users';
  static const roles = '/admin/roles';
  static const reports = '/admin/reports';
  static const audit = '/admin/audit';
  static const settings = '/admin/settings';
}

/// Allowed upload file extensions (kept in sync with settings.allowed_file_types seed).
class FileRules {
  static const allowedExtensions = [
    'pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'txt',
    'mp4', 'mp3', 'jpg', 'jpeg', 'png', 'zip',
  ];
  static const maxFileSizeMb = 100;
}

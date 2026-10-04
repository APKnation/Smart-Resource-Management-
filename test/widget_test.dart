import 'package:flutter_test/flutter_test.dart';

import 'package:e_resource/core/theme.dart';

void main() {
  test('AppTheme light and dark themes build', () {
    expect(AppTheme.light(), isNotNull);
    expect(AppTheme.dark(), isNotNull);
  });
}

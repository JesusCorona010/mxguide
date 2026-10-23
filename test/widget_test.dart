import 'package:flutter_test/flutter_test.dart';
import 'package:mx_guide/models/app_user.dart';

void main() {
  group('AppUser', () {
    AppUser user(String name) => AppUser(id: '1', email: 'a@b.com', name: name, role: 'user');

    test('saca las iniciales del nombre', () {
      expect(user('Jesús Corona').initials, 'JC');
      expect(user('jesus').initials, 'J');
      expect(user('   ').initials, '?');
    });

    test('detecta si es admin', () {
      expect(user('Ana').isAdmin, isFalse);
      expect(
        const AppUser(id: '1', email: '', name: 'Ana', role: 'admin').isAdmin,
        isTrue,
      );
    });
  });
}

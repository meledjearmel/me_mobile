import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/push/push_target.dart';

void main() {
  group('PushTarget.fromData', () {
    test('reconnaît un contact', () {
      final target = PushTarget.fromData({'type': 'contact', 'id': '42'});

      expect(target?.type, PushResourceType.contact);
      expect(target?.id, 42);
    });

    test('reconnaît une collaboration et un avis', () {
      expect(PushTarget.fromData({'type': 'engagement', 'id': 1})?.type, PushResourceType.engagement);
      expect(PushTarget.fromData({'type': 'testimonial', 'id': 1})?.type, PushResourceType.testimonial);
    });

    test('un type inconnu renvoie null', () {
      expect(PushTarget.fromData({'type': 'autre-chose', 'id': 1}), isNull);
    });

    test('un id manquant ou non numérique renvoie null', () {
      expect(PushTarget.fromData({'type': 'contact'}), isNull);
      expect(PushTarget.fromData({'type': 'contact', 'id': 'abc'}), isNull);
    });
  });

  test('chaque type de ressource pointe vers un onglet distinct de la boîte de réception', () {
    final indexes = PushResourceType.values.map((t) => t.inboxTabIndex).toSet();

    expect(indexes.length, PushResourceType.values.length);
  });
}

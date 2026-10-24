import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/shared/widgets/status_badge.dart';
import 'package:me_mobile/shared/widgets/status_sheet.dart';
import 'package:me_mobile/shared/widgets/status_tones.dart';

void main() {
  test('contenus : brouillon secondaire, publié plein, projet archivé en contour', () {
    for (final type in ['project', 'post', 'experience', 'distinction', 'service', 'job_profile']) {
      expect(statusTone(type, 'draft'), StatusTone.secondary, reason: type);
      expect(statusTone(type, 'published'), StatusTone.filled, reason: type);
    }
    expect(statusTone('project', 'archived'), StatusTone.outline);
  });

  test('boîte de réception', () {
    expect(statusTone('contact', 'new'), StatusTone.filled);
    expect(statusTone('contact', 'read'), StatusTone.secondary);
    expect(statusTone('contact', 'replied'), StatusTone.outline);
    expect(statusTone('engagement', 'new'), StatusTone.filled);
    expect(statusTone('engagement', 'handled'), StatusTone.outline);
    for (final type in ['comment', 'testimonial']) {
      expect(statusTone(type, 'pending'), StatusTone.secondary);
      expect(statusTone(type, 'approved'), StatusTone.filled);
      expect(statusTone(type, 'rejected'), StatusTone.danger);
    }
    expect(statusTone('appointment', 'pending'), StatusTone.filled);
    expect(statusTone('appointment', 'confirmed'), StatusTone.secondary);
    expect(statusTone('appointment', 'declined'), StatusTone.outline);
    expect(statusTone('appointment', 'cancelled'), StatusTone.outline);
  });

  test('candidatures, documents et interrupteurs', () {
    expect(statusTone('job_application', 'active'), StatusTone.filled);
    expect(statusTone('job_application', 'draft'), StatusTone.secondary);
    expect(statusTone('job_application', 'archived'), StatusTone.secondary);
    expect(statusTone('proposal', 'interview'), StatusTone.filled);
    expect(statusTone('proposal', 'hired'), StatusTone.filled);
    expect(statusTone('proposal', 'sent'), StatusTone.secondary);
    expect(statusTone('proposal', 'declined'), StatusTone.outline);

    expect(statusTone('commercial_document', 'draft'), StatusTone.outline);
    expect(statusTone('commercial_document', 'issued'), StatusTone.secondary);
    expect(statusTone('commercial_document', 'accepted'), StatusTone.filled);
    expect(statusTone('commercial_document', 'paid'), StatusTone.filled);
    expect(statusTone('commercial_document', 'declined'), StatusTone.danger);
    expect(statusTone('commercial_document', 'cancelled'), StatusTone.outline);

    for (final type in toggleStatusOptions.keys) {
      expect(statusTone(type, 'active'), StatusTone.filled);
      expect(statusTone(type, 'hidden'), StatusTone.secondary);
    }
    expect(toggleStatus(true), 'active');
    expect(toggleStatus(false), 'hidden');
  });

  test('transitions autorisées, comme l\'API', () {
    const appointment = ['pending', 'confirmed', 'declined', 'cancelled'];
    expect(allowedStatuses('appointment', 'pending', appointment), ['confirmed', 'declined']);
    expect(allowedStatuses('appointment', 'confirmed', appointment), ['declined']);
    expect(allowedStatuses('appointment', 'declined', appointment), isEmpty);

    const document = ['draft', 'issued', 'accepted', 'declined', 'paid', 'cancelled'];
    expect(allowedStatuses('commercial_document', 'draft', document), ['issued']);
    expect(allowedStatuses('commercial_document', 'issued', document), ['accepted', 'declined', 'paid', 'cancelled']);
    expect(allowedStatuses('commercial_document', 'paid', document), isEmpty);
    expect(allowedStatuses('commercial_document', 'cancelled', document), isEmpty);

    expect(allowedStatuses('revision', 'pending', const ['pending', 'applied', 'rejected']), ['applied', 'rejected']);
    expect(allowedStatuses('revision', 'applied', const ['pending', 'applied', 'rejected']), isEmpty);

    expect(allowedStatuses('estimator_item', 'active', const ['active', 'hidden']), ['hidden']);
    expect(allowedStatuses('contact', 'new', const ['new', 'read', 'replied']), ['read', 'replied']);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/features/inbox/data/contact.dart';
import 'package:me_mobile/features/inbox/data/engagement.dart';
import 'package:me_mobile/features/inbox/data/testimonial.dart';

void main() {
  group('Contact', () {
    test('un sujet absent (nullable côté spec) ne fait pas planter le parsing', () {
      final contact = Contact.fromJson({
        'id': 1,
        'name': 'Jeanne',
        'email': 'j@example.com',
        'subject': null,
        'message': 'Bonjour',
        'status': 'new',
        'created_at': null,
      });

      expect(contact.subject, isNull);
      expect(contact.createdAt, isNull);
    });

    test('un statut inconnu retombe sur "Nouveau" plutôt que de planter', () {
      expect(ContactStatus.fromWire('inconnu'), ContactStatus.newMessage);
    });
  });

  group('Engagement', () {
    test('un job_profile absent devient null', () {
      final engagement = Engagement.fromJson({
        'id': 1,
        'type': 'freelance',
        'status': 'new',
        'name': 'Paul',
        'email': 'p@example.com',
        'company': null,
        'subject': 'Mission',
        'job_profile': null,
        'contract': null,
        'budget': null,
        'timeline': null,
        'message': null,
        'locale': 'en',
        'cv_sent_at': null,
        'created_at': null,
      });

      expect(engagement.jobProfile, isNull);
      expect(engagement.type, EngagementType.freelance);
      expect(engagement.locale, 'en');
    });

    test('un type inconnu devient null plutôt que de planter', () {
      expect(EngagementType.fromWire('autre'), isNull);
    });
  });

  group('Testimonial', () {
    test('is_featured absent par défaut à false', () {
      final testimonial = Testimonial.fromJson({
        'id': 1,
        'author_name': 'Alice',
        'author_email': 'a@example.com',
        'author_role': null,
        'content': {'fr': 'Bien', 'en': ''},
        'status': 'pending',
        'project': null,
        'submitted_at': '2026-09-25T10:00:00Z',
      });

      expect(testimonial.isFeatured, isFalse);
      expect(testimonial.content.display, 'Bien');
    });

    test('un projet lié est parsé avec son titre traduit', () {
      final testimonial = Testimonial.fromJson({
        'id': 1,
        'author_name': 'Alice',
        'author_email': 'a@example.com',
        'author_role': null,
        'content': {'fr': 'Bien', 'en': 'Good'},
        'status': 'approved',
        'is_featured': true,
        'project': {
          'id': 4,
          'slug': 'mon-projet',
          'title': {'fr': 'Mon projet', 'en': 'My project'},
        },
        'submitted_at': '2026-09-25T10:00:00Z',
      });

      expect(testimonial.projects.single.slug, 'mon-projet');
      expect(testimonial.projects.single.title.en, 'My project');
    });

    test('accroche, transcription et vidéo sont parsées', () {
      final testimonial = Testimonial.fromJson({
        'id': 1,
        'author_name': 'Alice',
        'author_email': 'a@example.com',
        'author_role': null,
        'content': {'fr': 'Bien', 'en': 'Good'},
        'highlight': {'fr': 'Top', 'en': 'Great'},
        'video_transcript': [],
        'video': {
          'url': 'https://armeldev.xyz/v.mp4',
          'poster_url': null,
          'duration': 65,
          'width': 720,
          'height': 1280,
          'uploaded_at': '2026-10-03T10:00:00Z',
        },
        'status': 'pending',
        'project': null,
        'submitted_at': '2026-09-25T10:00:00Z',
      });

      expect(testimonial.highlight.en, 'Great');
      expect(testimonial.videoTranscript.isEmpty, isTrue);
      expect(testimonial.video!.durationLabel, '1:05');
      expect(testimonial.video!.aspectRatio, 720 / 1280);
    });

    test('plusieurs rattachements et lien d\x27invitation', () {
      final testimonial = Testimonial.fromJson({
        'id': 1,
        'author_name': 'Alice',
        'author_email': 'a@example.com',
        'author_role': null,
        'content': {'fr': 'Bien', 'en': 'Good'},
        'status': 'approved',
        'project': {'id': 1, 'slug': 'a', 'title': {'fr': 'Projet A', 'en': ''}},
        'projects': [
          {'id': 1, 'slug': 'a', 'title': {'fr': 'Projet A', 'en': ''}},
          {'id': 2, 'slug': 'b', 'title': {'fr': 'Projet B', 'en': ''}},
        ],
        'experiences': [
          {'id': 4, 'company': 'Acme', 'role': {'fr': 'Dev', 'en': ''}},
        ],
        'educations': <dynamic>[],
        'review_invitation_id': 5,
        'submitted_at': '2026-09-25T10:00:00Z',
      });

      expect(testimonial.projects.map((p) => p.id), [1, 2]);
      expect(testimonial.reviewInvitationId, 5);
      expect(testimonial.subjectSummary, 'Projet A · Projet B · Acme');
    });

    test('sans rattachement : avis général', () {
      final testimonial = Testimonial.fromJson({
        'id': 1,
        'author_name': 'Alice',
        'author_email': 'a@example.com',
        'author_role': null,
        'content': {'fr': 'Bien', 'en': 'Good'},
        'status': 'approved',
        'submitted_at': null,
      });

      expect(testimonial.projects, isEmpty);
      expect(testimonial.subjectSummary, 'Général');
    });

    test('expérience et formation liées sont parsées', () {
      final testimonial = Testimonial.fromJson({
        'id': 1,
        'author_name': 'Alice',
        'author_email': 'a@example.com',
        'author_role': null,
        'content': {'fr': 'Bien', 'en': 'Good'},
        'status': 'approved',
        'project': null,
        'experience': {
          'id': 4,
          'company': 'ACME',
          'role': {'fr': 'Développeur', 'en': 'Developer'},
        },
        'education': {
          'id': 2,
          'institution': 'ESATIC',
          'degree': {'fr': 'Master', 'en': 'Master'},
        },
        'submitted_at': '2026-09-25T10:00:00Z',
      });

      expect(testimonial.experiences.single.company, 'ACME');
      expect(testimonial.experiences.single.role.en, 'Developer');
      expect(testimonial.educations.single.institution, 'ESATIC');
      expect(testimonial.subjectSummary, 'ACME · ESATIC');
    });

    test('une vidéo non traitée garde un format 16:9 et pas de durée', () {
      const video = TestimonialVideo(url: 'https://armeldev.xyz/v.mp4');

      expect(video.durationLabel, isNull);
      expect(video.aspectRatio, 16 / 9);
    });
  });
}

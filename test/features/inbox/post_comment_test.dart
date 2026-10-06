import 'package:flutter_test/flutter_test.dart';
import 'package:me_mobile/core/api/api_client.dart';
import 'package:me_mobile/core/push/push_target.dart';
import 'package:me_mobile/features/blog/data/post.dart';
import 'package:me_mobile/features/inbox/data/post_comment.dart';

import '../../helpers/fake_dio_adapter.dart';
import '../../helpers/memory_token_storage.dart';

const _json = {
  'id': 11,
  'author_name': 'Léa',
  'author_email': 'lea@example.com',
  'body': 'Super article !',
  'locale': 'fr',
  'status': 'pending',
  'post': {'id': 3, 'slug': 'mon-article', 'title': 'Mon article'},
  'created_at': '2026-10-04T18:00:00Z',
  'updated_at': '2026-10-04T18:00:00Z',
};

void main() {
  late FakeDioAdapter adapter;
  late PostCommentRepository repository;

  setUp(() {
    adapter = FakeDioAdapter();
    repository = PostCommentRepository(
      ApiClient(baseUrl: 'https://armeldev.xyz/api', tokens: MemoryTokenStorage(), adapter: adapter),
    );
  });

  test('fromJson lit l\'auteur, le statut et l\'article', () {
    final comment = PostComment.fromJson(_json);

    expect(comment.status, CommentStatus.pending);
    expect(comment.postId, 3);
    expect(comment.postTitle, 'Mon article');
    expect(comment.authorEmail, 'lea@example.com');
  });

  test('moderate envoie le statut en PUT', () async {
    adapter.whenRequest('PUT', '/v1/post-comments/11', statusCode: 200, body: {..._json, 'status': 'approved'});

    final updated = await repository.moderate(11, CommentStatus.approved);

    expect(adapter.requests.single.data, {'status': 'approved'});
    expect(updated.status, CommentStatus.approved);
  });

  test('notifications : commentaire vers l\'onglet 5, réactions vers l\'accueil', () {
    expect(PushTarget.fromData({'type': 'post_comment', 'id': '11'})!.type.inboxTabIndex, 4);
    final reaction = PushTarget.fromData({'type': 'post_reaction', 'id': '3'})!;
    expect(reaction.type, PushResourceType.postReaction);
    expect(reaction.type.location, '/home');
  });

  test('Post lit lectures, réactions, aperçu et commentaires en attente', () {
    final post = Post.fromJson({
      'id': 3,
      'slug': 'mon-article',
      'title': {'fr': 'Mon article', 'en': ''},
      'excerpt': [],
      'body': {'fr': '<p>x</p>', 'en': ''},
      'reading_minutes': 2,
      'is_featured': false,
      'status': 'draft',
      'published_at': null,
      'is_live': false,
      'cover_url': null,
      'tags': [],
      'views_count': 120,
      'preview_url': 'https://armeldev.xyz/fr/blog/mon-article?signature=abc',
      'reactions': {'like': 4, 'love': 1, 'fire': 0, 'idea': 2, 'think': 0},
      'pending_comments_count': 2,
      'shares': {'linkedin': 3, 'x': 0, 'whatsapp': 1, 'facebook': 0, 'email': 0, 'copy': 2, 'native': 0},
      'shares_count': 6,
      'created_at': null,
      'updated_at': null,
    });

    expect(post.viewsCount, 120);
    expect(post.reactions[PostReactionType.like], 4);
    expect(post.reactionsTotal, 7);
    expect(post.previewUrl, contains('signature'));
    expect(post.pendingCommentsCount, 2);
    expect(post.sharesCount, 6);
    expect(post.shares[PostShareNetwork.copy], 2);
  });
}

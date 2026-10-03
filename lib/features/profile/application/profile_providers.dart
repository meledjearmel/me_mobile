import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/publication_status.dart';
import '../../content/job_profiles/data/job_profile.dart';
import '../../content/job_profiles/data/job_profile_repository.dart';
import '../data/profile.dart';
import '../data/profile_repository.dart';

/// Profil unique du portfolio (§4.3). Rafraîchi après chaque modification réussie.
final profileProvider = FutureProvider<Profile>((ref) => ref.watch(profileRepositoryProvider).get());

/// Profils métier publiés, avec leurs PDF importés : seuls candidats au CV du
/// site (le site ignore un profil dépublié). Une page suffit (25).
final publishedJobProfilesProvider = FutureProvider<List<JobProfile>>((ref) async {
  final page = await ref
      .watch(jobProfileRepositoryProvider)
      .list(page: 1, status: PublicationStatus.published.wireValue);
  return [...page.items]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

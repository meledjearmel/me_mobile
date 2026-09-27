import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile.dart';
import '../data/profile_repository.dart';

/// Profil unique du portfolio (§4.3). Rafraîchi après chaque modification réussie.
final profileProvider = FutureProvider<Profile>((ref) => ref.watch(profileRepositoryProvider).get());

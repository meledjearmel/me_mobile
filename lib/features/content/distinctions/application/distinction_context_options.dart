import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../projects/data/project_repository.dart';
import '../../educations/data/education_repository.dart';
import '../../experiences/data/experience_repository.dart';
import '../data/distinction.dart';

typedef DistinctionContextOption = ({int id, String label});

/// Éléments proposés pour rattacher une distinction : toutes les expériences
/// (« entreprise — poste »), formations (« établissement — diplôme ») ou
/// projets (titre), toutes pages confondues.
final distinctionContextOptionsProvider = FutureProvider.autoDispose
    .family<List<DistinctionContextOption>, DistinctionContextType>((ref, type) async {
      Future<List<DistinctionContextOption>> all<T>(
        Future<Paginated<T>> Function(int page) fetch,
        DistinctionContextOption Function(T item) toOption,
      ) async {
        final options = <DistinctionContextOption>[];
        for (var page = 1; ; page++) {
          final result = await fetch(page);
          options.addAll(result.items.map(toOption));
          if (!result.hasMore) {
            return options;
          }
        }
      }

      return switch (type) {
        DistinctionContextType.experience => all(
          (page) => ref.read(experienceRepositoryProvider).list(page: page),
          (e) => (id: e.id, label: '${e.company} — ${e.role.display}'),
        ),
        DistinctionContextType.education => all(
          (page) => ref.read(educationRepositoryProvider).list(page: page),
          (e) => (id: e.id, label: '${e.institution} — ${e.degree.display}'),
        ),
        DistinctionContextType.project => all(
          (page) => ref.read(projectRepositoryProvider).list(page: page),
          (p) => (id: p.id, label: p.title.display),
        ),
      };
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/appointment_type.dart';
import '../data/appointment_type_repository.dart';

final appointmentTypeListProvider = AsyncNotifierProvider<AppointmentTypeListController, ListState<AppointmentType>>(
  AppointmentTypeListController.new,
);

class AppointmentTypeListController extends PaginatedListController<AppointmentType> {
  @override
  Future<Paginated<AppointmentType>> fetchPage({required int page, required ListQuery query}) =>
      ref.read(appointmentTypeRepositoryProvider).list(page: page, search: query.search);
}

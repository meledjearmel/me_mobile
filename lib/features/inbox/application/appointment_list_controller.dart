import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/paginated.dart';
import '../../../shared/pagination/list_query.dart';
import '../../../shared/pagination/paginated_list_controller.dart';
import '../data/appointment.dart';
import '../data/appointment_repository.dart';

final appointmentListProvider = AsyncNotifierProvider<AppointmentListController, ListState<Appointment>>(
  AppointmentListController.new,
);

class AppointmentListController extends PaginatedListController<Appointment> {
  @override
  Future<Paginated<Appointment>> fetchPage({required int page, required ListQuery query}) => ref
      .read(appointmentRepositoryProvider)
      .list(
        page: page,
        search: query.search,
        status: query.filters['status'] as String?,
        location: query.filters['location'] as String?,
      );
}

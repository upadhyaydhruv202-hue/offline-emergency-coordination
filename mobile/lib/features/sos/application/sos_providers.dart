import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../../../domain/entities/field_ops_boards.dart';
import '../../../domain/entities/sos_event.dart';
import '../../audit/application/audit_providers.dart';
import '../../field_ops/application/operating_context.dart';
import '../../location/application/location_providers.dart';
import '../data/sos_repository.dart';
import 'sos_service.dart';

final sosRepositoryProvider = Provider<SosRepository>(
  (ref) => SosRepository(
    events: ref.watch(sosDaoProvider),
    metadata: ref.watch(appMetadataDaoProvider),
  ),
);

/// Every distress call raised on this device: open first, most urgent first.
final sosHistoryProvider = StreamProvider<List<SosEvent>>(
  (ref) => ref.watch(sosRepositoryProvider).watchEvents(),
);

final sosBoardProvider = StreamProvider<SosBoard>(
  (ref) => ref.watch(sosRepositoryProvider).watchBoard(),
);

final sosEventProvider = StreamProvider.family<SosEvent?, String>(
  (ref, id) => ref.watch(sosRepositoryProvider).watchEvent(id),
);

final sosServiceProvider = Provider<SosService>(
  (ref) => SosService(
    repository: ref.watch(sosRepositoryProvider),
    locations: ref.watch(locationRepositoryProvider),
    audit: ref.watch(auditRepositoryProvider),
    context: ref.watch(operatingContextProvider),
  ),
);

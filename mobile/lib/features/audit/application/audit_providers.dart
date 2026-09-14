import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/database_providers.dart';
import '../../../domain/entities/audit_event.dart';
import '../data/audit_repository.dart';

final auditRepositoryProvider = Provider<AuditRepository>(
  (ref) => AuditRepository(ref.watch(auditDaoProvider)),
);

/// The device's own trail, most recent first. Surfaced on the profile screen so
/// a responder can see exactly what this handset recorded, and in what order.
final auditTrailProvider = StreamProvider<List<AuditEvent>>(
  (ref) => ref.watch(auditRepositoryProvider).watchRecent(limit: 50),
);

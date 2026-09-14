import 'hazard_severity.dart';
import 'hazard_status.dart';
import 'hazard_type.dart';

/// What the responder is currently looking for in the hazard list.
///
/// A value object rather than loose arguments, so the same filter can be held
/// in a provider, passed to the database and asserted on in a test.
class HazardQuery {
  const HazardQuery({
    this.search = '',
    this.type,
    this.severity,
    this.status,
  });

  /// Matched against the hazard code and the description.
  final String search;

  /// Null means every type.
  final HazardType? type;

  /// Null means every severity.
  final HazardSeverity? severity;

  /// Null means every status.
  final HazardStatus? status;

  String get normalisedSearch => search.trim().toLowerCase();

  bool get hasSearch => normalisedSearch.isNotEmpty;

  bool get isFiltered =>
      hasSearch || type != null || severity != null || status != null;

  HazardQuery copyWith({
    String? search,
    HazardType? type,
    bool clearType = false,
    HazardSeverity? severity,
    bool clearSeverity = false,
    HazardStatus? status,
    bool clearStatus = false,
  }) =>
      HazardQuery(
        search: search ?? this.search,
        type: clearType ? null : (type ?? this.type),
        severity: clearSeverity ? null : (severity ?? this.severity),
        status: clearStatus ? null : (status ?? this.status),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HazardQuery &&
          other.search == search &&
          other.type == type &&
          other.severity == severity &&
          other.status == status;

  @override
  int get hashCode => Object.hash(search, type, severity, status);
}

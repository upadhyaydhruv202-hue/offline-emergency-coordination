import 'triage_category.dart';
import 'victim_status.dart';

/// What the responder is currently looking for in the victim list.
///
/// A value object rather than three loose arguments, so the same filter can be
/// held in a provider, passed to the database and asserted on in a test.
class VictimQuery {
  const VictimQuery({this.search = '', this.triage, this.status});

  /// Matched against name, temporary id, injury and medical condition.
  final String search;

  /// Null means every category.
  final TriageCategory? triage;

  /// Null means every status.
  final VictimStatus? status;

  String get normalisedSearch => search.trim().toLowerCase();

  bool get hasSearch => normalisedSearch.isNotEmpty;

  bool get isFiltered => hasSearch || triage != null || status != null;

  VictimQuery copyWith({
    String? search,
    TriageCategory? triage,
    bool clearTriage = false,
    VictimStatus? status,
    bool clearStatus = false,
  }) =>
      VictimQuery(
        search: search ?? this.search,
        triage: clearTriage ? null : (triage ?? this.triage),
        status: clearStatus ? null : (status ?? this.status),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VictimQuery &&
          other.search == search &&
          other.triage == triage &&
          other.status == status;

  @override
  int get hashCode => Object.hash(search, triage, status);
}

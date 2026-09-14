import '../../core/utils/identifiers.dart';
import 'daos/app_metadata_dao.dart';
import 'tables/app_metadata.dart';

/// Mints the short, speakable codes printed on field records.
///
/// The counter is per device by construction, which is what keeps a code unique
/// across a fleet of disconnected handsets without any coordination between
/// them. A clash needs the counter and the table to have drifted apart — a
/// restore from backup would do it — so it is rare, but recording the thing in
/// front of the responder must never fail over a naming detail, hence the
/// randomised fallback.
class FieldCodeMinter {
  const FieldCodeMinter(this.metadata);

  final AppMetadataDao metadata;

  /// Codes to try before falling back to a randomised one.
  static const int _attempts = 5;

  Future<String> next({
    required String prefix,
    required String sequenceKey,
    required Future<bool> Function(String candidate) isTaken,
  }) async {
    final deviceId = await metadata.readOrCreate(
      AppMetadataKeys.deviceId,
      generateDeviceId,
    );

    var sequence = 0;
    for (var attempt = 0; attempt < _attempts; attempt++) {
      sequence = await metadata.nextSequence(sequenceKey);
      final candidate = formatFieldCode(
        prefix: prefix,
        deviceId: deviceId,
        sequence: sequence,
      );
      if (!await isTaken(candidate)) return candidate;
    }

    return formatFieldCode(
      prefix: prefix,
      deviceId: deviceId,
      sequence: sequence,
      discriminator: generateUuidV4().substring(0, 4),
    );
  }
}

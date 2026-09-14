import 'dart:math';

/// Identifier generation for records authored on a disconnected device.
///
/// The device mints its own keys. Waiting for the backend to assign one would
/// put the network in the critical path of registering a casualty, which is
/// exactly what the architecture forbids.

final Random _secure = Random.secure();

/// An RFC 4122 version 4 identifier.
///
/// Written by hand rather than pulled from a package: the field app is built
/// on a responder's laptop in a hurry, and every dependency is one more thing
/// that has to resolve before the app compiles.
String generateUuidV4([Random? random]) {
  final rng = random ?? _secure;
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .toList(growable: false);

  return '${hex.sublist(0, 4).join()}-${hex.sublist(4, 6).join()}-'
      '${hex.sublist(6, 8).join()}-${hex.sublist(8, 10).join()}-'
      '${hex.sublist(10, 16).join()}';
}

/// A random, device-local identifier.
///
/// Later slices give records an origin so that operations authored on
/// different devices can be merged without collision; a cryptographic device
/// identity is a hardening-slice concern.
String generateDeviceId([Random? random]) {
  final rng = random ?? _secure;
  final hex = List<int>.generate(8, (_) => rng.nextInt(256))
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
  return 'DRP-$hex';
}

/// A short, speakable label for a record authored on this device.
///
/// A UUID cannot be read out over a radio or written on a triage tag. This is
/// the identifier a responder actually uses in the field; the device suffix
/// keeps it unique across devices without any coordination between them.
///
/// [prefix] names the kind of record — `V` for a casualty, `INC`, `SOS`, `HZ`,
/// `TASK` — so a code heard over a radio is unambiguous on its own.
String formatFieldCode({
  required String prefix,
  required String deviceId,
  required int sequence,
  String? discriminator,
}) {
  final suffix = deviceId.length >= 4
      ? deviceId.substring(deviceId.length - 4).toUpperCase()
      : deviceId.toUpperCase().padLeft(4, '0');
  final number = sequence.toString().padLeft(3, '0');
  final base = '${prefix.toUpperCase()}-$suffix-$number';
  return discriminator == null
      ? base
      : '$base-${discriminator.toUpperCase()}';
}

/// The short label printed on a casualty's triage tag, e.g. `V-8C1F-007`.
String formatTemporaryId({
  required String deviceId,
  required int sequence,
  String? discriminator,
}) =>
    formatFieldCode(
      prefix: 'V',
      deviceId: deviceId,
      sequence: sequence,
      discriminator: discriminator,
    );

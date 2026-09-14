enum ConflictResolution {
  lastWriterWins('LAST_WRITER_WINS'),
  deviceTieBreak('DEVICE_TIE_BREAK'),
  operationTieBreak('OPERATION_TIE_BREAK'),
  merged('MERGED'),
  manualReview('MANUAL_REVIEW');

  const ConflictResolution(this.wireValue);

  final String wireValue;

  static ConflictResolution? tryFromWire(String? value) {
    if (value == null) return null;
    for (final resolution in values) {
      if (resolution.wireValue == value) return resolution;
    }
    return null;
  }
}

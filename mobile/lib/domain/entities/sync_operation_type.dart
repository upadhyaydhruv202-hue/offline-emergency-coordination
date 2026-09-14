enum SyncOperationType {
  create('CREATE'),
  update('UPDATE'),
  delete('DELETE');

  const SyncOperationType(this.wireValue);

  final String wireValue;

  static SyncOperationType? tryFromWire(String? value) {
    if (value == null) return null;
    for (final type in values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }
}

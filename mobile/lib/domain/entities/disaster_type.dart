/// The kind of event a response is mounted against.
///
/// [wireValue] is the contract with the coordination backend and must not be
/// renamed casually; the Dart identifier is what Drift persists.
enum DisasterType {
  earthquake('EARTHQUAKE', 'Earthquake'),
  flood('FLOOD', 'Flood'),
  fire('FIRE', 'Fire'),
  landslide('LANDSLIDE', 'Landslide'),
  cyclone('CYCLONE', 'Cyclone'),
  industrialAccident('INDUSTRIAL_ACCIDENT', 'Industrial accident'),
  buildingCollapse('BUILDING_COLLAPSE', 'Building collapse'),
  other('OTHER', 'Other');

  const DisasterType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static DisasterType? tryFromWire(String? value) {
    if (value == null) return null;
    for (final type in values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }
}

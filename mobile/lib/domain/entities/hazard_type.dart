/// What a responder found that the next team needs warning about.
enum HazardType {
  flood('FLOOD', 'Flood'),
  fire('FIRE', 'Fire'),
  smoke('SMOKE', 'Smoke'),
  roadBlocked('ROAD_BLOCKED', 'Road blocked'),
  buildingDamage('BUILDING_DAMAGE', 'Building damage'),
  bridgeRisk('BRIDGE_RISK', 'Bridge at risk'),
  landslide('LANDSLIDE', 'Landslide'),
  electricalHazard('ELECTRICAL_HAZARD', 'Electrical hazard'),
  chemicalHazard('CHEMICAL_HAZARD', 'Chemical hazard'),
  other('OTHER', 'Other');

  const HazardType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static HazardType? tryFromWire(String? value) {
    if (value == null) return null;
    for (final type in values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }
}

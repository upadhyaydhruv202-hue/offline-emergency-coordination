/// Coarse age banding.
///
/// A responder frequently cannot ask for an age, but can always estimate a
/// band, and the band is what drives paediatric handling and family
/// reunification. When an exact age is given the band is derived from it, so
/// the two can never disagree.
enum AgeGroup {
  infant('INFANT', 'Infant', 'under 2'),
  child('CHILD', 'Child', '2 to 12'),
  adult('ADULT', 'Adult', '13 to 64'),
  elderly('ELDERLY', 'Elderly', '65 and over'),
  unknown('UNKNOWN', 'Unknown', 'not established');

  const AgeGroup(this.wireValue, this.label, this.range);

  final String wireValue;
  final String label;
  final String range;

  static AgeGroup fromAge(int? age) {
    if (age == null || age < 0) return AgeGroup.unknown;
    if (age < 2) return AgeGroup.infant;
    if (age < 13) return AgeGroup.child;
    if (age < 65) return AgeGroup.adult;
    return AgeGroup.elderly;
  }

  static AgeGroup? tryFromWire(String? value) {
    if (value == null) return null;
    for (final group in values) {
      if (group.wireValue == value) return group;
    }
    return null;
  }
}

/// Recorded as stated or observed. `unknown` is a legitimate answer and the
/// default, not a data-quality failure.
enum Gender {
  male('MALE', 'Male'),
  female('FEMALE', 'Female'),
  other('OTHER', 'Other'),
  unknown('UNKNOWN', 'Unknown');

  const Gender(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static Gender? tryFromWire(String? value) {
    if (value == null) return null;
    for (final gender in values) {
      if (gender.wireValue == value) return gender;
    }
    return null;
  }
}

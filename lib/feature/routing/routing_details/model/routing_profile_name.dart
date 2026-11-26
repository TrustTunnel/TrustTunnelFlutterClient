/// The name of a routing profile.
final class RoutingProfileName {
  /// The stored name. This is empty for the localized default name.
  final String value;

  const RoutingProfileName._(this.value);

  /// Uses the localized default name of the built-in profile.
  const RoutingProfileName.defaultProfile() : this._('');

  /// Uses [value] as the profile name.
  ///
  /// Throws [ArgumentError] if [value] is empty or contains only whitespace.
  factory RoutingProfileName.custom(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(
        value,
        'value',
        'The profile name must contain text',
      );
    }

    return RoutingProfileName._(value);
  }

  /// Whether the profile uses the localized default name.
  bool get isDefault => value.isEmpty;

  @override
  int get hashCode => value.hashCode;

  @override
  bool operator ==(Object other) => other is RoutingProfileName && value == other.value;
}

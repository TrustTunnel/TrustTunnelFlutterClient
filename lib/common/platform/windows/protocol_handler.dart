/// Registers and removes a custom URL protocol scheme.
abstract interface class ProtocolHandler {
  /// Registers [scheme] so that `scheme://` links open the current application.
  ///
  /// Implementations must be idempotent and must reconcile conflicting
  /// registrations instead of blindly overwriting them.
  Future<void> register(String scheme);

  /// Removes the registration for [scheme] created by the current application.
  ///
  /// Implementations must not remove a registration that belongs to another
  /// executable.
  Future<void> unregister(String scheme);
}

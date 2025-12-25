import 'package:pigeon/pigeon.dart';

/// {@template pigeon_vpn_plugin_schema}
/// Pigeon schema for the VPN plugin platform API.
///
/// This file defines the platform channel contract used by the plugin.
/// Pigeon uses it to generate strongly-typed bindings for:
/// - Dart (`lib/platform_api.g.dart`)
/// - Android (Kotlin)
/// - iOS/macOS (Swift)
/// - Windows (C++)
///
/// The generated code is the actual runtime implementation. This schema is
/// the single source of truth for method signatures, data types, and error
/// payload shapes.
///
/// ## Threading model
/// Methods annotated with [TaskQueue] are executed on a platform-side task queue.
/// In this schema, VPN start/stop operations are explicitly routed to a serial
/// background thread to avoid blocking UI threads and to preserve operation order.
///
/// ## Versioning
/// Consider this API stable once published. Additive changes (new fields with
/// defaults / new enum values) are generally safer than breaking changes.
/// {@endtemplate}
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform_api.g.dart',
    dartOptions: DartOptions(),
    cppOptions: CppOptions(namespace: 'vpn_plugin'),
    cppHeaderOut: 'windows/runner/platform_api.g.h',
    cppSourceOut: 'windows/runner/platform_api.g.cpp',
    kotlinOut: 'android/src/main/kotlin/com/adguard/trusttunnel/vpn_plugin/PlatformApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'com.adguard.trusttunnel.vpn_plugin',
    ),
    swiftOptions: SwiftOptions(),
  ),
)
/// {@template i_vpn_manager}
/// Host-side VPN manager API.
///
/// `IVpnManager` is implemented on the platform (host) side and called from Dart.
/// It provides the minimal lifecycle operations required by the plugin:
/// - [start] to start the VPN engine using a prepared configuration string.
/// - [stop] to stop the VPN engine.
/// - [getCurrentState] to query the current engine state.
///
/// ## Ordering and concurrency
/// [start] and [stop] are executed on a serial background queue (see [TaskQueue]).
/// This ensures:
/// - operations are performed in the order they are invoked,
/// - platform UI threads are not blocked by long-running operations.
///
/// ## Configuration format
/// The [config] parameter is a backend configuration document (string).
/// Its exact format is defined by the backend and produced on the Dart side
/// (for example by a [ConfigurationEncoder]).
/// {@endtemplate}
@HostApi()
abstract class IVpnManager {
  /// {@template i_vpn_manager_start}
  /// Starts the VPN engine using the provided configuration document.
  ///
  /// [config] must contain a complete backend configuration text. The platform
  /// implementation is responsible for:
  /// - parsing/validating the configuration,
  /// - initiating any required permissions or service start,
  /// - transitioning the engine state accordingly.
  ///
  /// This call is executed on a serial background task queue to avoid blocking
  /// the platform UI thread.
  /// {@endtemplate}
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void start({required String serverName, required String config});

  /// {@template i_vpn_manager_stop}
  /// Stops the VPN engine.
  ///
  /// The platform implementation should stop the underlying VPN service/process
  /// and transition the engine state to [VpnManagerState.disconnected].
  ///
  /// This call is executed on a serial background task queue to avoid blocking
  /// the platform UI thread.
  /// {@endtemplate}
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void stop();

  /// {@template i_vpn_manager_get_current_state}
  /// Returns the current VPN engine state.
  ///
  /// This method is typically used to:
  /// - restore UI state after app restart,
  /// - confirm whether a start/stop request has taken effect,
  /// - diagnose platform-side lifecycle issues.
  /// {@endtemplate}
  VpnManagerState getCurrentState();
}

/// {@template vpn_manager_state}
/// Current state of the platform VPN engine.
///
/// This enum models the high-level lifecycle of the VPN service/engine as seen
/// from Dart. Implementations may have additional internal substates; they should
/// be mapped onto these public states in a consistent way.
///
/// ## Typical state flow
/// - [disconnected] → [connecting] → [connected]
/// - On transient failure: [connected] → [waitingForRecovery] → [recovering]
/// - When network is unavailable: [connecting] or [recovering] → [waitingForNetwork]
///
/// The exact transitions and timing depend on the platform implementation.
/// {@endtemplate}
enum VpnManagerState {
  disconnected,
  connecting,
  connected,
  waitingForRecovery,
  recovering,
  waitingForNetwork,
}

/// {@template platform_error_code}
/// High-level error category returned by platform implementations.
///
/// This is intended for coarse error classification suitable for UI messaging
/// and analytics. More specific errors may be provided via [PlatformFieldError].
/// {@endtemplate}
enum PlatformErrorCode {
  unknown,
}

/// {@template platform_field_error_code}
/// Error category for a specific user-visible field.
///
/// Field errors are typically used to attach validation errors to individual
/// configuration inputs (e.g. invalid IP address).
/// {@endtemplate}
enum PlatformFieldErrorCode {
  fieldWrongValue,
  alreadyExists,
}

/// {@template platform_field_name}
/// Identifies which input field a [PlatformFieldError] refers to.
///
/// The field set is intentionally limited to values that are meaningful to
/// external consumers and stable across platforms.
/// {@endtemplate}
enum PlatformFieldName {
  ipAddress,
  domain,
  serverName,
  dnsServers,
}

/// {@template platform_error_response}
/// Structured error payload returned by platform implementations.
///
/// This model supports two levels of error reporting:
/// - a top-level [code] for general classification,
/// - optional per-field validation errors in [fieldErrors].
///
/// Both fields are nullable to support platforms that only provide partial
/// error information.
/// {@endtemplate}
class PlatformErrorResponse {
  /// {@template platform_error_response_code}
  /// General error category, if available.
  /// {@endtemplate}
  final PlatformErrorCode? code;

  /// {@template platform_error_response_field_errors}
  /// Optional list of validation errors tied to individual fields.
  /// {@endtemplate}
  final List<PlatformFieldError?>? fieldErrors;

  /// {@macro platform_error_response}
  const PlatformErrorResponse({
    this.code,
    this.fieldErrors,
  });
}

/// {@template platform_field_error}
/// Validation error associated with a particular configuration field.
///
/// A field error specifies:
/// - [code] describing the kind of failure,
/// - [fieldName] identifying which field is invalid.
///
/// This structure is designed for UI clients that want to show inline
/// validation messages next to problematic fields.
/// {@endtemplate}
class PlatformFieldError {
  /// {@template platform_field_error_code_field}
  /// Category of the field error.
  /// {@endtemplate}
  final PlatformFieldErrorCode code;

  /// {@template platform_field_error_field_name}
  /// Which field the error relates to.
  /// {@endtemplate}
  final PlatformFieldName fieldName;

  /// {@macro platform_field_error}
  const PlatformFieldError({
    required this.code,
    required this.fieldName,
  });
}

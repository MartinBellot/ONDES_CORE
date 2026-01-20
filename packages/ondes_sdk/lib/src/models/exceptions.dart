/// Base exception for Ondes SDK errors.
///
/// Contains a [code] for programmatic error handling and a [message]
/// for human-readable descriptions.
class OndesException implements Exception {
  /// Error code for programmatic handling.
  ///
  /// Common codes:
  /// - `PERMISSION_DENIED`: User denied a permission request
  /// - `NOT_SUPPORTED`: Feature not available on this device
  /// - `CANCELLED`: User cancelled the action
  /// - `NETWORK_ERROR`: Network connectivity issue
  /// - `AUTH_REQUIRED`: User must be logged in
  /// - `NOT_FOUND`: Requested resource doesn't exist
  final String code;

  /// Human-readable error message.
  final String message;

  const OndesException({
    required this.code,
    required this.message,
  });

  @override
  String toString() => 'OndesException($code): $message';

  /// Permission was denied by the user
  static const permissionDenied = 'PERMISSION_DENIED';

  /// Feature not supported on this device
  static const notSupported = 'NOT_SUPPORTED';

  /// Action was cancelled by the user
  static const cancelled = 'CANCELLED';

  /// Network connectivity error
  static const networkError = 'NETWORK_ERROR';

  /// Authentication required
  static const authRequired = 'AUTH_REQUIRED';

  /// Resource not found
  static const notFound = 'NOT_FOUND';

  /// Invalid argument provided
  static const invalidArgument = 'INVALID_ARGUMENT';
}

/// Exception thrown when authentication is required.
class AuthRequiredException extends OndesException {
  const AuthRequiredException([String? message])
      : super(
          code: OndesException.authRequired,
          message: message ?? 'User must be authenticated to perform this action',
        );
}

/// Exception thrown when a permission is denied.
class PermissionDeniedException extends OndesException {
  final String? permission;

  const PermissionDeniedException({
    this.permission,
    String? message,
  }) : super(
          code: OndesException.permissionDenied,
          message: message ?? 'Permission denied${permission != null ? ': $permission' : ''}',
        );
}

/// Exception thrown when user cancels an action.
class CancelledException extends OndesException {
  const CancelledException([String? message])
      : super(
          code: OndesException.cancelled,
          message: message ?? 'Action was cancelled',
        );
}

/// Exception thrown when a resource is not found.
class NotFoundException extends OndesException {
  const NotFoundException([String? message])
      : super(
          code: OndesException.notFound,
          message: message ?? 'Resource not found',
        );
}

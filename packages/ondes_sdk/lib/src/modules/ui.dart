import '../bridge/js_bridge.dart';
import '../models/enums.dart';

/// UI module for native interface controls.
///
/// Provides toasts, alerts, confirmations, bottom sheets,
/// and app bar configuration.
///
/// ## Example
/// ```dart
/// await Ondes.ui.showToast(
///   message: "Operation successful!",
///   type: ToastType.success,
/// );
///
/// final confirmed = await Ondes.ui.showConfirm(
///   title: "Delete",
///   message: "Are you sure?",
/// );
/// ```
class OndesUI {
  final OndesJsBridge _bridge;

  OndesUI(this._bridge);

  /// Shows a toast notification.
  ///
  /// [message] The text to display.
  /// [type] The visual style (info, success, error, warning).
  Future<void> showToast({
    required String message,
    ToastType type = ToastType.info,
  }) async {
    await _bridge.call('Ondes.UI.showToast', [
      {
        'message': message,
        'type': type.name,
      }
    ]);
  }

  /// Shows an alert dialog.
  ///
  /// [title] The dialog title.
  /// [message] The dialog message.
  /// [buttonText] The button text (default: "OK").
  Future<void> showAlert({
    required String title,
    required String message,
    String buttonText = 'OK',
  }) async {
    await _bridge.call('Ondes.UI.showAlert', [
      {
        'title': title,
        'message': message,
        'buttonText': buttonText,
      }
    ]);
  }

  /// Shows a confirmation dialog.
  ///
  /// Returns `true` if the user confirms, `false` otherwise.
  ///
  /// [title] The dialog title.
  /// [message] The question to ask.
  /// [confirmText] The confirm button text (default: "Confirm").
  /// [cancelText] The cancel button text (default: "Cancel").
  Future<bool> showConfirm({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) async {
    final result = await _bridge.call<bool>('Ondes.UI.showConfirm', [
      {
        'title': title,
        'message': message,
        'confirmText': confirmText,
        'cancelText': cancelText,
      }
    ]);
    return result ?? false;
  }

  /// Shows a bottom sheet with options.
  ///
  /// Returns the selected option's value, or `null` if cancelled.
  ///
  /// [title] The bottom sheet title.
  /// [items] List of items with [label], [value], and optional [icon].
  Future<String?> showBottomSheet({
    String? title,
    required List<BottomSheetItem> items,
  }) async {
    final result = await _bridge.call<String>('Ondes.UI.showBottomSheet', [
      {
        'title': title,
        'items': items.map((i) => i.toJson()).toList(),
      }
    ]);
    return result;
  }

  /// Configures the native app bar.
  ///
  /// [title] The title to display.
  /// [visible] Whether the app bar is visible.
  /// [backgroundColor] Background color as hex string (e.g., "#FF5722").
  /// [foregroundColor] Text/icon color as hex string (e.g., "#FFFFFF").
  Future<void> configureAppBar({
    String? title,
    bool? visible,
    String? backgroundColor,
    String? foregroundColor,
  }) async {
    final options = <String, dynamic>{};
    if (title != null) options['title'] = title;
    if (visible != null) options['visible'] = visible;
    if (backgroundColor != null) options['backgroundColor'] = backgroundColor;
    if (foregroundColor != null) options['foregroundColor'] = foregroundColor;

    await _bridge.call('Ondes.UI.configureAppBar', [options]);
  }
}

/// Item for bottom sheet options.
class BottomSheetItem {
  /// Display label.
  final String label;

  /// Return value when selected.
  final String value;

  /// Optional icon name or emoji.
  final String? icon;

  const BottomSheetItem({
    required this.label,
    required this.value,
    this.icon,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'value': value,
      if (icon != null) 'icon': icon,
    };
  }
}

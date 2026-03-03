import 'package:flutter/material.dart';

/// Helper extension to ease opacity calculations while avoiding the
/// deprecated `withOpacity` API.
///
/// The Flutter SDK deprecated `withOpacity` in favor of `withValues`, but the
/// latter uses component values (alpha, red, green, blue). Instead of spamming
/// literal alpha maths everywhere, we provide a convenience method.
///
/// Usage:
/// ```dart
/// color.withOpacityValue(0.2);
/// ```
///
/// This simply maps the opacity (0.0-1.0) into an integer alpha channel.
extension ColorExtensions on Color {
  Color withOpacityValue(double opacity) =>
      withAlpha((opacity * 255).round());
}
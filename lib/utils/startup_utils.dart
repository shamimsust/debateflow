// Utility data that needs to be shared between main.dart and other
// parts of the application without introducing a circular dependency.

/// The URL that was present when the app first launched (captured in main).
///
/// Flutter Web's dev server rewrites the browser URL immediately after the
/// Dart code starts.  Reading [Uri.base] later usually returns "/" instead
/// of the desired deep link.  We capture it early in `main()` and store it
/// here so that widgets like the `Wrapper` can consult it later.
String? initialLaunchHref;
// Conditional import to abstract away dart:html so the code can compile
// on mobile without errors.

library web_utils;

import 'web_utils_stub.dart' if (dart.library.html) 'web_utils_html.dart';

export 'web_utils_stub.dart' if (dart.library.html) 'web_utils_html.dart';

/// Return the href that was present when the app first loaded.
///
/// For web this is identical to [getLocationHref], but we call it
/// at module load time to capture the original value before Flutter
/// may mutate the browser history (which happens during route handling).
final String initialHref = getLocationHref();


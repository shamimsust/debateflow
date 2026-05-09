// HTML-specific implementation that uses dart:html. Only compiled on web.
// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:web/web.dart' as web;

String getLocationHref() => web.window.location.href;

void openUrl(String url, String target) => web.window.open(url, target);

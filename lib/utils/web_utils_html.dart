// HTML-specific implementation that uses dart:html. Only compiled on web.

import 'dart:html' as html;

String getLocationHref() => html.window.location.href;

void openUrl(String url, String target) => html.window.open(url, target);

// Stub implementation for platforms where dart:html is unavailable.

String getLocationHref() => '';

/// No-op on non-web platforms.
void openUrl(String url, String target) {}

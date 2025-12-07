// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void cleanupOAuthParametersImpl() {
  try {
    final uri = Uri.parse(html.window.location.href);
    
    if (uri.queryParameters.containsKey('code') ||
        uri.queryParameters.containsKey('error') ||
        uri.queryParameters.containsKey('error_description')) {
      
      final cleanUrl = uri.replace(queryParameters: {}).toString();
      html.window.history.replaceState(null, '', cleanUrl);
    }
  } catch (e) {
    // Silently fail
  }
}


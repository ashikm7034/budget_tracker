import 'dart:convert';
import 'package:http/http.dart' as http;

/// A helper class to handle HTTP requests.
class HttpHelper {
  /// Sends a POST request to [url] and manually follows redirects (like 302) if encountered.
  /// For 301, 302, and 303 redirects, the request method is converted to GET,
  /// and the request body/content-type headers are omitted in the follow-up request,
  /// as expected by Google Apps Script and standard browser behaviors.
  static Future<http.Response> postFollowRedirects(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('POST', url);
      if (headers != null) {
        request.headers.addAll(headers);
      }
      if (body != null) {
        if (body is String) {
          request.body = body;
        } else if (body is List<int>) {
          request.bodyBytes = body;
        } else if (body is Map<String, String>) {
          request.bodyFields = body;
        }
      }
      // Disable automatic redirects so we can intercept 302 and follow them manually
      request.followRedirects = false;

      var response = await client.send(request);

      int redirectCount = 0;
      // Google Apps Script redirect statuses: 301, 302, 303, 307, 308
      while ((response.statusCode == 301 ||
              response.statusCode == 302 ||
              response.statusCode == 303 ||
              response.statusCode == 307 ||
              response.statusCode == 308) &&
          redirectCount < 5) {
        final redirectUrlStr = response.headers['location'];
        if (redirectUrlStr == null || redirectUrlStr.isEmpty) {
          break;
        }

        final redirectUri = Uri.parse(redirectUrlStr);
        redirectCount++;

        // For 301, 302, and 303 redirects of a POST, the HTTP specification
        // and browser client behavior is to switch the request method to GET
        // and drop the request body.
        final nextMethod = (response.statusCode == 307 || response.statusCode == 308) ? 'POST' : 'GET';

        final nextRequest = http.Request(nextMethod, redirectUri);

        // Copy headers/body depending on the method
        if (nextMethod == 'POST') {
          if (headers != null) {
            nextRequest.headers.addAll(headers);
          }
          if (body != null) {
            if (body is String) {
              nextRequest.body = body;
            } else if (body is List<int>) {
              nextRequest.bodyBytes = body;
            } else if (body is Map<String, String>) {
              nextRequest.bodyFields = body;
            }
          }
        } else {
          // For GET request, copy headers but omit content-type / body-specific headers
          if (headers != null) {
            headers.forEach((key, value) {
              final lowerKey = key.toLowerCase();
              if (lowerKey != 'content-type' && lowerKey != 'content-length') {
                nextRequest.headers[key] = value;
              }
            });
          }
        }

        nextRequest.followRedirects = false;
        response = await client.send(nextRequest);
      }

      return await http.Response.fromStream(response);
    } finally {
      client.close();
    }
  }
}

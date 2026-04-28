import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class GoogleMapsPlaceData {
  const GoogleMapsPlaceData({
    this.name,
    this.address,
    this.priceRange,
    this.openingHours,
    this.phone,
    this.latitude,
    this.longitude,
  });

  final String? name;
  final String? address;
  final String? priceRange;
  final String? openingHours;
  final String? phone;
  final double? latitude;
  final double? longitude;

  bool get hasAnyData {
    return name != null ||
        address != null ||
        priceRange != null ||
        openingHours != null ||
        phone != null ||
        latitude != null ||
        longitude != null;
  }

  GoogleMapsPlaceData merge(GoogleMapsPlaceData other) {
    return GoogleMapsPlaceData(
      name: _prefer(name, other.name),
      address: _prefer(address, other.address),
      priceRange: _prefer(priceRange, other.priceRange),
      openingHours: _prefer(openingHours, other.openingHours),
      phone: _prefer(phone, other.phone),
      latitude: latitude ?? other.latitude,
      longitude: longitude ?? other.longitude,
    );
  }
}

class GoogleMapsExtractionService {
  static const _timeout = Duration(seconds: 12);

  Future<GoogleMapsPlaceData> extract(String rawUrl) async {
    final normalizedUrl = _normalizeUrl(rawUrl);
    final client = http.Client();

    try {
      var currentUri = Uri.parse(normalizedUrl);
      var data = _extractFromUri(currentUri);

      final response = await client
          .get(_preferVietnamese(currentUri), headers: _headers)
          .timeout(_timeout);
      data = data.merge(_extractFromHtml(response.body, currentUri));

      final previewUri = _findPreviewUri(response.body, currentUri);
      if (previewUri != null) {
        final previewResponse = await _send(client, previewUri);
        final previewBody = await previewResponse.stream.bytesToString();
        data = data
            .merge(_extractFromUri(previewUri))
            .merge(extractFromPreviewBody(previewBody));
      }

      if (data.hasAnyData) return data;

      for (var index = 0; index < 8; index++) {
        final response = await _send(client, currentUri);

        if (_isRedirect(response.statusCode)) {
          final location = response.headers['location'];
          if (location == null || location.isEmpty) break;
          currentUri = currentUri.resolve(location);
          data = data.merge(_extractFromUri(currentUri));
          continue;
        }

        final body = await response.stream.bytesToString();
        data = data.merge(_extractFromHtml(body, currentUri));

        final previewUri = _findPreviewUri(body, currentUri);
        if (previewUri != null) {
          final previewResponse = await _send(client, previewUri);
          final previewBody = await previewResponse.stream.bytesToString();
          data = data
              .merge(_extractFromUri(previewUri))
              .merge(extractFromPreviewBody(previewBody));
        }

        break;
      }

      return data;
    } finally {
      client.close();
    }
  }

  GoogleMapsPlaceData extractFromPreviewBody(String body) {
    final text = _decodeGoogleEscapes(body);
    final strings = _quotedStrings(text);

    final coords = _extractCoordinates(text);
    final address = _findAddress(strings);
    final name = _findPlaceName(text, strings, address);

    return GoogleMapsPlaceData(
      name: name,
      address: _stripPlaceNameFromAddress(address, name),
      priceRange: _findPriceRange(strings),
      openingHours: _findOpeningHours(strings),
      phone: _findPhone(strings),
      latitude: coords.$1,
      longitude: coords.$2,
    );
  }

  Future<http.StreamedResponse> _send(http.Client client, Uri uri) {
    final request = http.Request('GET', _preferVietnamese(uri))
      ..followRedirects = false
      ..headers.addAll(_headers);

    return client.send(request).timeout(_timeout);
  }

  Map<String, String> get _headers => const {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'vi,en;q=0.8',
    'Cookie': 'CONSENT=YES+cb.20230101-11-p0.en+FX+113;',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/121.0 Mobile Safari/537.36',
  };

  GoogleMapsPlaceData _extractFromHtml(String body, Uri baseUri) {
    final previewUri = _findPreviewUri(body, baseUri);
    var data = previewUri == null
        ? const GoogleMapsPlaceData()
        : _extractFromUri(previewUri);

    final staticMapMatch = RegExp(
      r'center=([-.\d]+)%2C([-.\d]+)',
      caseSensitive: false,
    ).firstMatch(body);
    if (staticMapMatch != null) {
      data = data.merge(
        GoogleMapsPlaceData(
          latitude: double.tryParse(staticMapMatch.group(1)!),
          longitude: double.tryParse(staticMapMatch.group(2)!),
        ),
      );
    }

    return data;
  }

  GoogleMapsPlaceData _extractFromUri(Uri uri) {
    var data = const GoogleMapsPlaceData();

    final pathSegments = uri.pathSegments;
    if (pathSegments.contains('place')) {
      final placeIndex = pathSegments.indexOf('place');
      if (placeIndex + 1 < pathSegments.length) {
        data = data.merge(
          GoogleMapsPlaceData(
            name: _clean(pathSegments[placeIndex + 1].replaceAll('+', ' ')),
          ),
        );
      }
    }

    for (final segment in pathSegments) {
      if (!segment.startsWith('@')) continue;
      final parts = segment.substring(1).split(',');
      if (parts.length < 2) continue;
      data = data.merge(
        GoogleMapsPlaceData(
          latitude: double.tryParse(parts[0]),
          longitude: double.tryParse(parts[1]),
        ),
      );
    }

    for (final key in const ['q', 'query', 'destination', 'daddr']) {
      final value = uri.queryParameters[key];
      if (value == null || value.trim().isEmpty) continue;

      final coordinateMatch = RegExp(
        r'(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)',
      ).firstMatch(value);
      if (coordinateMatch != null) {
        data = data.merge(
          GoogleMapsPlaceData(
            latitude: double.tryParse(coordinateMatch.group(1)!),
            longitude: double.tryParse(coordinateMatch.group(2)!),
          ),
        );
      } else if (!value.contains(',')) {
        data = data.merge(GoogleMapsPlaceData(name: _clean(value)));
      }
    }

    final decodedUrl = Uri.decodeFull(uri.toString());
    final pbCoords = RegExp(
      r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)',
    ).firstMatch(decodedUrl);
    if (pbCoords != null) {
      data = data.merge(
        GoogleMapsPlaceData(
          latitude: double.tryParse(pbCoords.group(1)!),
          longitude: double.tryParse(pbCoords.group(2)!),
        ),
      );
    }

    return data;
  }

  Uri? _findPreviewUri(String body, Uri baseUri) {
    final match = RegExp(
      r'''href=["']([^"']*/maps/preview/place[^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(body);
    if (match == null) return null;

    final href = _decodeHtmlEntities(match.group(1)!);
    if (href.startsWith('/maps/')) {
      return Uri.parse('https://www.google.com$href');
    }
    return baseUri.resolve(href);
  }

  (double?, double?) _extractCoordinates(String text) {
    final nullCoords = RegExp(
      r'\[null,null,(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\]',
    ).firstMatch(text);
    if (nullCoords != null) {
      return (
        double.tryParse(nullCoords.group(1)!),
        double.tryParse(nullCoords.group(2)!),
      );
    }

    final cameraCoords = RegExp(
      r'\[\[\d+(?:\.\d+)?,(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\]',
    ).firstMatch(text);
    if (cameraCoords != null) {
      return (
        double.tryParse(cameraCoords.group(2)!),
        double.tryParse(cameraCoords.group(1)!),
      );
    }

    return (null, null);
  }

  String? _findPlaceName(String text, List<String> strings, String? address) {
    final exactMatch = RegExp(
      r'"([^"]+)",null,\["(?:Quán cà phê|Coffee shop|Restaurant|Cafe|Café|Bar|Store|Shop)',
      caseSensitive: false,
    ).firstMatch(text);
    if (exactMatch != null) return _clean(exactMatch.group(1));

    for (final value in strings) {
      final cleaned = _clean(value);
      if (cleaned == null) continue;
      if (address != null && address.startsWith('$cleaned,')) return cleaned;
    }

    return null;
  }

  String? _findAddress(List<String> strings) {
    final candidates = strings.map(_clean).whereType<String>().where((value) {
      final lower = value.toLowerCase();
      return value.contains(',') &&
          !lower.startsWith('http') &&
          !lower.contains('google maps') &&
          (lower.contains('vietnam') || lower.contains('việt nam'));
    }).toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final aPlusCode = RegExp(r'^[0-9A-Z]{4}\+').hasMatch(a);
      final bPlusCode = RegExp(r'^[0-9A-Z]{4}\+').hasMatch(b);
      if (aPlusCode != bPlusCode) return aPlusCode ? 1 : -1;
      return b.length.compareTo(a.length);
    });

    return candidates.first;
  }

  String? _findPhone(List<String> strings) {
    for (final value in strings) {
      final phone = _phoneMatch(value, requireInternationalPrefix: true);
      if (phone != null) return phone;
    }

    for (final value in strings) {
      final phone = _phoneMatch(value, requireInternationalPrefix: false);
      if (phone != null) return phone;
    }

    return null;
  }

  String? _findOpeningHours(List<String> strings) {
    for (final value in strings) {
      final cleaned = _clean(value);
      if (cleaned == null) continue;
      final lower = cleaned.toLowerCase();
      if (lower.startsWith('http')) continue;
      if (lower == 'open' || lower == 'closed') continue;
      if (lower.contains('xóa bỏ') ||
          lower.contains('không có ở đây') ||
          lower.contains('not here')) {
        continue;
      }
      if (lower.startsWith('mở') ||
          lower.contains('open 24 hours') ||
          lower.contains('hours')) {
        return cleaned;
      }
    }
    return null;
  }

  String? _phoneMatch(
    String value, {
    required bool requireInternationalPrefix,
  }) {
    final raw = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    final pattern = requireInternationalPrefix
        ? r'(\+\d{1,3}\s*\d[\d\s]{7,})'
        : r'(0\d[\d\s]{8,})';
    final match = RegExp(pattern).firstMatch(raw);
    if (match == null) return null;

    final phone = match.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9 || digits.length > 15) return null;
    if (phone.startsWith('84') && !phone.startsWith('+')) return '+$phone';
    return phone;
  }

  String? _findPriceRange(List<String> strings) {
    for (final value in strings) {
      final cleaned = _clean(value);
      if (cleaned == null) continue;
      if (RegExp(r'\d').hasMatch(cleaned) &&
          (cleaned.contains('₫') || cleaned.contains('đ/'))) {
        return cleaned;
      }
    }
    return null;
  }

  String? _stripPlaceNameFromAddress(String? address, String? name) {
    if (address == null || name == null) return address;
    final prefix = '$name, ';
    if (address.startsWith(prefix)) return address.substring(prefix.length);
    return address;
  }

  List<String> _quotedStrings(String text) {
    final values = <String>[];
    final matches = RegExp(r'"(?:\\.|[^"\\])*"').allMatches(text);
    for (final match in matches) {
      try {
        values.add(jsonDecode(match.group(0)!) as String);
      } catch (_) {
        values.add(match.group(0)!.substring(1, match.group(0)!.length - 1));
      }
    }
    return values;
  }

  Uri _preferVietnamese(Uri uri) {
    if (!uri.host.contains('google')) return uri;
    final params = Map<String, String>.from(uri.queryParameters);
    params['hl'] = 'vi';
    return uri.replace(queryParameters: params);
  }

  String _normalizeUrl(String rawUrl) {
    var url = rawUrl.trim();
    if (RegExp(r'(^|//)ps\.app\.goo\.gl').hasMatch(url)) {
      url = url.replaceFirst('ps.app.goo.gl', 'maps.app.goo.gl');
    }
    if (!url.startsWith(RegExp(r'https?://', caseSensitive: false))) {
      url = 'https://$url';
    }
    return url;
  }

  String _decodeGoogleEscapes(String value) {
    return value
        .replaceAll(r'\u003d', '=')
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\u0027', "'")
        .replaceAll(r'\u003c', '<')
        .replaceAll(r'\u003e', '>');
  }

  String _decodeHtmlEntities(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }
}

String? _prefer(String? current, String? next) {
  if (current != null && current.trim().isNotEmpty) return current;
  return _clean(next);
}

bool _isRedirect(int statusCode) {
  return statusCode >= 300 && statusCode < 400;
}

String? _clean(String? value) {
  if (value == null) return null;
  final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return cleaned.isEmpty ? null : cleaned;
}

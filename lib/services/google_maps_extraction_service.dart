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
    this.rating,
    this.latitude,
    this.longitude,
  });

  final String? name;
  final String? address;
  final String? priceRange;
  final String? openingHours;
  final String? phone;
  final double? rating;
  final double? latitude;
  final double? longitude;

  bool get hasAnyData {
    return name != null ||
        address != null ||
        priceRange != null ||
        openingHours != null ||
        phone != null ||
        rating != null ||
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
      rating: rating ?? other.rating,
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
      final responseUri = response.request?.url ?? currentUri;
      data = _extractFromUri(responseUri).merge(data);
      data = _extractFromHtml(response.body, responseUri).merge(data);

      final previewUri = _findPreviewUri(response.body, responseUri);
      if (previewUri != null) {
        final previewResponse = await _send(client, previewUri);
        final previewBody = await previewResponse.stream.bytesToString();
        data = extractFromPreviewBody(
          previewBody,
        ).merge(_extractFromUri(previewUri)).merge(data);
      }

      if (data.hasAnyData) return data;

      for (var index = 0; index < 8; index++) {
        final response = await _send(client, currentUri);

        if (_isRedirect(response.statusCode)) {
          final location = response.headers['location'];
          if (location == null || location.isEmpty) break;
          currentUri = currentUri.resolve(location);
          data = _extractFromUri(currentUri).merge(data);
          continue;
        }

        final body = await response.stream.bytesToString();
        data = _extractFromHtml(body, currentUri).merge(data);

        final previewUri = _findPreviewUri(body, currentUri);
        if (previewUri != null) {
          final previewResponse = await _send(client, previewUri);
          final previewBody = await previewResponse.stream.bytesToString();
          data = extractFromPreviewBody(
            previewBody,
          ).merge(_extractFromUri(previewUri)).merge(data);
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
      priceRange: _findPriceRange(text, strings),
      openingHours: _findOpeningHours(strings),
      phone: _findPhone(strings),
      rating: _findRating(text, strings),
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
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/121.0 Safari/537.36',
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
      r'"([^"]+)",null,\["(?:Quán cà phê|Cửa hàng|Nhà hàng|Coffee shop|Restaurant|Cafe|Café|Bar|Store|Shop|Park|Hotel|Mall|Cinema|Hospital|School|Gym)',
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
    final candidates = strings
        .map(_clean)
        .whereType<String>()
        .where(_isAddressCandidate)
        .where((value) {
          final lower = value.toLowerCase();
          return lower.contains('vietnam') || lower.contains('việt nam');
        })
        .toList();

    if (candidates.isEmpty) {
      candidates.addAll(
        strings
            .map(_clean)
            .whereType<String>()
            .where(_isAddressCandidate)
            .where((value) => value.split(',').length >= 3),
      );
    }

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      // Prioritize addresses that are longer (more specific)
      // but penalize those that are ONLY a Plus Code.
      final aIsOnlyPlusCode = RegExp(
        r'^[0-9A-Z]{4}\+[0-9A-Z]{2,3}$',
      ).hasMatch(a);
      final bIsOnlyPlusCode = RegExp(
        r'^[0-9A-Z]{4}\+[0-9A-Z]{2,3}$',
      ).hasMatch(b);
      if (aIsOnlyPlusCode != bIsOnlyPlusCode) return aIsOnlyPlusCode ? 1 : -1;

      final scoreCompare = _addressScore(b).compareTo(_addressScore(a));
      if (scoreCompare != 0) return scoreCompare;

      return b.length.compareTo(a.length);
    });

    return candidates.first;
  }

  bool _isAddressCandidate(String value) {
    if (value.length > 220 || value.contains('\n')) return false;
    if (!value.contains(',')) return false;

    final lower = value.toLowerCase();
    if (lower.startsWith('http')) return false;
    if (lower.contains('google maps')) return false;
    if (lower.contains('anniversary')) return false;
    if (lower.contains('sponsor')) return false;
    if (lower.contains('website:')) return false;
    if (lower.contains('email:')) return false;
    if (RegExp(
      r'\b(thg|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\b',
    ).hasMatch(lower)) {
      return false;
    }

    return _addressScore(value) > 0;
  }

  int _addressScore(String value) {
    final lower = value.toLowerCase();
    var score = 0;

    if (RegExp(r'\b\d+[a-z]?\b').hasMatch(value)) score += 2;
    if (lower.contains('đ.') ||
        lower.contains('đường') ||
        lower.contains('street') ||
        lower.contains('road')) {
      score += 3;
    }
    if (lower.contains('building') ||
        lower.contains('tòa') ||
        lower.contains('toà')) {
      score += 2;
    }
    if (lower.contains('khu đô thị') ||
        lower.contains('phường') ||
        lower.contains('quận') ||
        lower.contains('huyện') ||
        lower.contains('thành phố')) {
      score += 2;
    }
    if (lower.contains('hà nội') ||
        lower.contains('hồ chí minh') ||
        lower.contains('đà nẵng')) {
      score += 2;
    }
    if (lower.contains('vietnam') || lower.contains('việt nam')) score += 2;
    if (RegExp(r'^[0-9A-Z]{4}\+[0-9A-Z]{2,3}').hasMatch(value)) score -= 3;

    return score;
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
    String? fallback;
    for (final value in strings) {
      final cleaned = _clean(value);
      if (cleaned == null) continue;
      final lower = cleaned.toLowerCase();
      if (lower.startsWith('http')) continue;
      if (lower == 'open' || lower == 'closed') continue;
      if (cleaned.length > 120) continue;

      // Skip noise/action strings
      if (lower.contains('sửa tên') ||
          lower.contains('chỉnh sửa') ||
          lower.contains('đề xuất') ||
          lower.contains('đánh dấu') ||
          lower.contains('báo cáo') ||
          lower.contains('suggest') ||
          lower.contains('edit') ||
          lower.contains('mark ') ||
          lower.contains('report') ||
          lower.contains('xóa bỏ') ||
          lower.contains('không có ở đây') ||
          lower.contains('not here')) {
        continue;
      }

      // High confidence: contains a time range pattern
      if (RegExp(r'\d{1,2}:\d{2}\s*[-–]\s*\d{1,2}:\d{2}').hasMatch(cleaned)) {
        return cleaned;
      }

      if (_isOpeningHoursCandidate(cleaned) && fallback == null) {
        fallback = cleaned;
      }
    }
    return fallback;
  }

  bool _isOpeningHoursCandidate(String value) {
    final lower = value.toLowerCase();
    final hasTime = RegExp(r'\d{1,2}:\d{2}').hasMatch(value);
    if (hasTime) {
      return lower.contains('mở') ||
          lower.contains('đóng') ||
          lower.contains('open') ||
          lower.contains('closed') ||
          lower.contains('giờ') ||
          lower.contains('hours') ||
          _hasWeekday(value);
    }

    if (RegExp(
      r'^(mở cửa cả ngày|mở cả ngày|open 24 hours|open 24h|24 hours)$',
      caseSensitive: false,
    ).hasMatch(value)) {
      return true;
    }

    return false;
  }

  bool _hasWeekday(String value) {
    return RegExp(
      r'\b(mon|tue|wed|thu|fri|sat|sun|monday|tuesday|wednesday|thursday|friday|saturday|sunday|thứ|chủ nhật|chủ nhật)\b',
      caseSensitive: false,
    ).hasMatch(value);
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

  String? _findPriceRange(String text, List<String> strings) {
    // 1. Priority: Look for descriptive ranges (e.g., "10.000 - 50.000 ₫")
    for (final value in strings) {
      final cleaned = _clean(value);
      if (cleaned == null || cleaned.length > 80) continue;
      final lower = cleaned.toLowerCase();

      // High confidence if it contains currency symbols and a number
      final hasCurrency =
          lower.contains('₫') ||
          lower.contains('đ') ||
          lower.contains('vnd') ||
          lower.contains('vnđ') ||
          lower.contains('\$') ||
          lower.contains('€');

      if (hasCurrency && RegExp(r'\d').hasMatch(cleaned)) {
        // Exclude clear status strings or very long digit sequences
        if (lower.contains('mở cửa') ||
            lower.contains('đóng cửa') ||
            RegExp(r'\d{12}').hasMatch(cleaned)) {
          continue;
        }
        final normalized = _normalizePriceRange(cleaned);
        if (normalized != null) return normalized;
      }
    }

    // 2. Secondary: Look for simple levels like $$, ₫₫
    String? singleCurrencyFallback;
    for (final value in strings) {
      final cleaned = _clean(value);
      if (cleaned == null) continue;
      if (RegExp(r'^[\$\d₫€]{1,4}$').hasMatch(cleaned)) {
        if (RegExp(r'^\d+$').hasMatch(cleaned)) continue;
        if (RegExp(r'^[\$₫€]$').hasMatch(cleaned)) {
          singleCurrencyFallback ??= cleaned;
          continue;
        }
        return cleaned;
      }
    }

    // 3. Fallback: Structured data
    final priceLevelMatch = RegExp(
      r'\["(?:Price|Giá|Mức giá)",\s*null,\s*"?([^"\],]+)"?\]',
    ).firstMatch(text);
    if (priceLevelMatch != null) {
      final level = _clean(priceLevelMatch.group(1));
      if (level == '1') return '₫';
      if (level == '2') return '₫₫';
      if (level == '3') return '₫₫₫';
      if (level == '4') return '₫₫₫₫';
      if (level != null && level.length > 1) return level;
    }

    // 4. Final attempt: Join strings to find split price range
    final joined = strings.join(' ');
    // Restrict digits to realistic currency lengths (max 10-12 digits)
    // and ensure the total match isn't absurdly long.
    final moneyPattern = RegExp(
      r'((?:₫|đ|VND|vnđ|\$|€)?\s*\d{1,9}(?:[\.,]\d{3})*\s*[-–]\s*\d{1,9}(?:[\.,]\d{3})*\s*(?:₫|đ|VND|vnđ|\$|€|mỗi người|/người|per person|/person)?)',
      caseSensitive: false,
    );
    final match = moneyPattern.firstMatch(joined);
    if (match != null) {
      final result = _normalizePriceRange(match.group(1));
      if (result != null && result.length < 35) return result;
    }

    final rawMatch = moneyPattern.firstMatch(text);
    if (rawMatch != null) {
      final result = _normalizePriceRange(rawMatch.group(1));
      if (result != null && result.length < 35) return result;
    }

    return singleCurrencyFallback;
  }

  double? _findRating(String text, List<String> strings) {
    final structuredRating = RegExp(
      r'\[null,null,null,null,null,null,null,([1-5](?:\.\d)?)\]',
    ).firstMatch(text);
    if (structuredRating != null) {
      return double.tryParse(structuredRating.group(1)!);
    }

    for (final value in strings) {
      final cleaned = _clean(value);
      if (cleaned == null) continue;
      final ratingMatch = RegExp(
        r'(^|[^\d])([1-5](?:[\.,]\d))\s*(?:\(\d+\)|sao|stars?)',
        caseSensitive: false,
      ).firstMatch(cleaned);
      if (ratingMatch == null) continue;
      final rating = double.tryParse(
        ratingMatch.group(2)!.replaceAll(',', '.'),
      );
      if (rating != null && rating >= 1 && rating <= 5) return rating;
    }

    return null;
  }

  String? _normalizePriceRange(String? value) {
    final cleaned = _clean(value);
    if (cleaned == null) return null;

    final hasPriceShape =
        RegExp(
          r'[₫đ$€]|vnd|vnđ|mỗi người|/người|per person|/person',
          caseSensitive: false,
        ).hasMatch(cleaned) &&
        RegExp(r'\d').hasMatch(cleaned);
    if (!hasPriceShape) return null;

    final match = RegExp(
      r'((?:₫|đ|VND|vnđ|\$|€)?\s*\d{1,9}(?:[\.,]\d{3})*(?:\s*[-–]\s*\d{1,9}(?:[\.,]\d{3})*)?\s*(?:₫|đ|VND|vnđ|\$|€)?(?:\s*(?:mỗi người|/người|per person|/person))?)',
      caseSensitive: false,
    ).firstMatch(cleaned);

    return _clean(match?.group(1) ?? cleaned);
  }

  String? _stripPlaceNameFromAddress(String? address, String? name) {
    if (address == null || name == null) return address;

    // Remove if it's at the start
    final prefix = '$name, ';
    if (address.startsWith(prefix)) return address.substring(prefix.length);

    // Remove if it's inside (e.g., "PlusCode Name, Address")
    final escapedName = RegExp.escape(name);
    final pattern = RegExp(
      '([A-Z0-9]{4}\\+[A-Z0-9]{2,3})\\s+$escapedName,\\s*',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(address);
    if (match != null) {
      return address.replaceFirst(match.group(0)!, '${match.group(1)!}, ');
    }

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

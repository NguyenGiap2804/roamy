import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/utils/coordinates.dart';

enum GoogleMapsExtractionConfidence { low, medium, high }

class GoogleMapsExtractionReview {
  GoogleMapsExtractionReview({
    required this.confidence,
    required this.score,
    required List<String> issues,
    required List<String> capturedFields,
  }) : issues = List.unmodifiable(issues),
       capturedFields = List.unmodifiable(capturedFields);

  final GoogleMapsExtractionConfidence confidence;
  final double score;
  final List<String> issues;
  final List<String> capturedFields;

  bool get needsManualReview {
    return confidence != GoogleMapsExtractionConfidence.high ||
        issues.isNotEmpty;
  }
}

class GoogleMapsPlaceData {
  const GoogleMapsPlaceData({
    this.name,
    this.address,
    this.priceRange,
    this.openingHours,
    this.phone,
    this.website,
    this.imageUrl,
    this.rating,
    this.latitude,
    this.longitude,
  });

  final String? name;
  final String? address;
  final String? priceRange;
  final String? openingHours;
  final String? phone;
  final String? website;
  final String? imageUrl;
  final double? rating;
  final double? latitude;
  final double? longitude;

  GoogleMapsExtractionReview get review {
    final hasName = _clean(name) != null;
    final hasAddress = _clean(address) != null;
    final hasPriceRange = _clean(priceRange) != null;
    final hasOpeningHours = _clean(openingHours) != null;
    final hasPhone = _clean(phone) != null;
    final hasWebsite = _clean(website) != null;
    final hasImage = _clean(imageUrl) != null;
    final hasRating = rating != null && rating! >= 1 && rating! <= 5;
    final hasCoordinates = hasUsableCoordinates(latitude, longitude);

    var score = 0.0;
    if (hasName) score += 0.32;
    if (hasAddress) score += 0.24;
    if (hasCoordinates) score += 0.24;
    if (hasOpeningHours) score += 0.08;
    if (hasPhone) score += 0.06;
    if (hasWebsite) score += 0.04;
    if (hasImage) score += 0.04;
    if (hasPriceRange) score += 0.04;
    if (hasRating) score += 0.02;
    score = score.clamp(0.0, 1.0).toDouble();

    final capturedFields = <String>[];
    if (hasName) capturedFields.add('Ten');
    if (hasAddress) capturedFields.add('Dia chi');
    if (hasCoordinates) capturedFields.add('Toa do');
    if (hasOpeningHours) capturedFields.add('Gio mo cua');
    if (hasPhone) capturedFields.add('So dien thoai');
    if (hasWebsite) capturedFields.add('Website');
    if (hasImage) capturedFields.add('Hinh anh');
    if (hasPriceRange) capturedFields.add('Khoang gia');
    if (hasRating) capturedFields.add('Danh gia');

    final issues = <String>[];
    if (!hasName) {
      issues.add('Ten dia diem chua duoc trich xuat.');
    }
    if (!hasAddress) {
      issues.add('Dia chi chua du ro rang.');
    }
    if (!hasCoordinates) {
      issues.add('Chua lay duoc toa do chinh xac de mo ban do.');
    }

    final optionalFieldCount = [
      hasOpeningHours,
      hasPhone,
      hasPriceRange,
      hasRating,
    ].where((value) => value).length;
    if ((hasName || hasAddress) && optionalFieldCount == 0) {
      issues.add(
        'Link nay chi tra ve du lieu co ban. Nen doi chieu them gio mo cua, gia va lien he truoc khi luu.',
      );
    }

    final confidence = score >= 0.8
        ? GoogleMapsExtractionConfidence.high
        : score >= 0.55
        ? GoogleMapsExtractionConfidence.medium
        : GoogleMapsExtractionConfidence.low;

    return GoogleMapsExtractionReview(
      confidence: confidence,
      score: double.parse(score.toStringAsFixed(2)),
      issues: issues,
      capturedFields: capturedFields,
    );
  }

  bool get hasAnyData {
    return name != null ||
        address != null ||
        priceRange != null ||
        openingHours != null ||
        phone != null ||
        website != null ||
        imageUrl != null ||
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
      website: _prefer(website, other.website),
      imageUrl: _prefer(imageUrl, other.imageUrl),
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
      data = extractFromHtmlBody(
        response.body,
        baseUri: responseUri,
      ).merge(data);

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
        data = extractFromHtmlBody(body, baseUri: currentUri).merge(data);

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

  GoogleMapsPlaceData extractFromHtmlBody(String body, {Uri? baseUri}) {
    return _extractFromHtml(
      body,
      baseUri ?? Uri.parse('https://www.google.com/maps'),
    );
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
      website: _findWebsite(strings),
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
    final decodedBody = _decodeGoogleEscapes(_decodeHtmlEntities(body));
    var data = _extractStructuredData(
      decodedBody,
    ).merge(_extractFromUri(baseUri));

    final metadataImageUrl = _findHtmlMetadataImage(decodedBody);
    if (metadataImageUrl != null) {
      data = data.merge(GoogleMapsPlaceData(imageUrl: metadataImageUrl));
    }

    final previewUri = _findPreviewUri(body, baseUri);
    if (previewUri != null) {
      data = data.merge(_extractFromUri(previewUri));
    }

    final deepLinkUri = _findDeepLinkUri(decodedBody, baseUri);
    if (deepLinkUri != null) {
      data = data.merge(_extractFromUri(deepLinkUri));
    }

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

    for (final key in const [
      'q',
      'query',
      'destination',
      'daddr',
      'location',
    ]) {
      final value = uri.queryParameters[key];
      if (value == null || value.trim().isEmpty) continue;

      data = data.merge(_extractFromQueryValue(value));
    }

    final decodedUrl = Uri.decodeFull(uri.toString());
    final placeCoordinates = _extractPlaceCoordinatesFromUrl(decodedUrl);
    if (placeCoordinates != null) {
      data = placeCoordinates.merge(data);
    }

    return data;
  }

  GoogleMapsPlaceData _extractFromQueryValue(String value) {
    final cleaned = _clean(value);
    if (cleaned == null) return const GoogleMapsPlaceData();

    final coordinateOnlyMatch = RegExp(
      r'^\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)\s*$',
    ).firstMatch(cleaned);
    if (coordinateOnlyMatch != null) {
      return GoogleMapsPlaceData(
        latitude: double.tryParse(coordinateOnlyMatch.group(1)!),
        longitude: double.tryParse(coordinateOnlyMatch.group(2)!),
      );
    }

    if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) {
      return const GoogleMapsPlaceData();
    }

    final parts = cleaned
        .split(',')
        .map(_clean)
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return const GoogleMapsPlaceData();

    return GoogleMapsPlaceData(
      name: _sanitizePlaceName(parts.first),
      address: parts.length > 1 ? parts.sublist(1).join(', ') : null,
    );
  }

  GoogleMapsPlaceData? _extractPlaceCoordinatesFromUrl(String decodedUrl) {
    for (final pattern in [
      RegExp(r'!(?:8m2|4m2)!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)'),
      RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)'),
    ]) {
      RegExpMatch? selected;
      for (final match in pattern.allMatches(decodedUrl)) {
        selected = match;
      }
      if (selected == null) continue;

      return GoogleMapsPlaceData(
        latitude: double.tryParse(selected.group(1)!),
        longitude: double.tryParse(selected.group(2)!),
      );
    }

    return null;
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

  Uri? _findDeepLinkUri(String body, Uri baseUri) {
    final match = RegExp(
      r'''window\.ES5DGURL\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(body);
    if (match == null) return null;

    final href = _decodeHtmlEntities(_decodeGoogleEscapes(match.group(1)!));
    if (href.startsWith('/maps/')) {
      return Uri.parse('https://www.google.com$href');
    }
    return baseUri.resolve(href);
  }

  String? _findHtmlMetadataImage(String body) {
    final metaTags = RegExp(
      r'''<meta\b[^>]*>''',
      caseSensitive: false,
    ).allMatches(body);

    for (final match in metaTags) {
      final tag = match.group(0)!;
      final key =
          _htmlAttribute(tag, 'property') ?? _htmlAttribute(tag, 'name');
      if (key == null) continue;
      final normalizedKey = key.toLowerCase();
      if (normalizedKey != 'og:image' &&
          normalizedKey != 'og:image:url' &&
          normalizedKey != 'twitter:image') {
        continue;
      }

      final content = _clean(_htmlAttribute(tag, 'content'));
      if (_isHttpImageUrl(content)) return content;
    }

    return null;
  }

  String? _htmlAttribute(String tag, String attribute) {
    final match = RegExp(
      "$attribute\\s*=\\s*[\"']([^\"']+)[\"']",
      caseSensitive: false,
    ).firstMatch(tag);
    return match == null ? null : _decodeHtmlEntities(match.group(1)!);
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

  String? _findWebsite(List<String> strings) {
    for (final value in strings) {
      final cleaned = _clean(value);
      if (_isExternalWebsiteUrl(cleaned)) return cleaned;
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

  GoogleMapsPlaceData _extractStructuredData(String body) {
    final matches = RegExp(
      r'''<script[^>]+type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>''',
      caseSensitive: false,
    ).allMatches(body);

    var data = const GoogleMapsPlaceData();
    for (final match in matches) {
      data = data.merge(_extractStructuredDataBlock(match.group(1)!));
      if (data.hasAnyData) {
        return data;
      }
    }

    return data;
  }

  GoogleMapsPlaceData _extractStructuredDataBlock(String rawBlock) {
    final block = rawBlock.replaceAll(RegExp(r'<!--|-->'), '').trim();
    if (block.isEmpty) return const GoogleMapsPlaceData();

    try {
      final decoded = jsonDecode(block);
      final placeNode = _findStructuredPlaceNode(decoded);
      if (placeNode == null) return const GoogleMapsPlaceData();

      final rawPriceRange = _clean(placeNode['priceRange']?.toString());

      return GoogleMapsPlaceData(
        name: _sanitizePlaceName(placeNode['name']?.toString()),
        address: _structuredAddress(placeNode['address']),
        priceRange:
            _normalizePriceRange(rawPriceRange) ?? _clean(rawPriceRange),
        openingHours: _structuredOpeningHours(placeNode),
        phone: _clean(placeNode['telephone']?.toString()),
        website: _structuredWebsite(placeNode),
        imageUrl: _structuredImageUrl(placeNode['image']),
        rating: _structuredRating(placeNode['aggregateRating']),
        latitude:
            _structuredCoordinate(placeNode['geo'], 'latitude') ??
            _asDouble(placeNode['latitude']),
        longitude:
            _structuredCoordinate(placeNode['geo'], 'longitude') ??
            _asDouble(placeNode['longitude']),
      );
    } catch (_) {
      return const GoogleMapsPlaceData();
    }
  }

  String? _structuredImageUrl(dynamic value) {
    if (value is String) {
      final cleaned = _clean(value);
      return _isHttpImageUrl(cleaned) ? cleaned : null;
    }

    if (value is List) {
      for (final item in value) {
        final imageUrl = _structuredImageUrl(item);
        if (imageUrl != null) return imageUrl;
      }
      return null;
    }

    if (value is Map<String, dynamic>) {
      return _structuredImageUrl(value['url']) ??
          _structuredImageUrl(value['contentUrl']);
    }

    return null;
  }

  String? _structuredWebsite(Map<String, dynamic> value) {
    for (final key in const ['url', 'website', 'sameAs']) {
      final website = _structuredWebsiteValue(value[key]);
      if (website != null) return website;
    }
    return null;
  }

  String? _structuredWebsiteValue(dynamic value) {
    if (value is String) {
      final cleaned = _clean(value);
      return _isExternalWebsiteUrl(cleaned) ? cleaned : null;
    }

    if (value is List) {
      for (final item in value) {
        final website = _structuredWebsiteValue(item);
        if (website != null) return website;
      }
    }

    if (value is Map<String, dynamic>) {
      return _structuredWebsiteValue(value['url']) ??
          _structuredWebsiteValue(value['@id']);
    }

    return null;
  }

  Map<String, dynamic>? _findStructuredPlaceNode(dynamic value) {
    if (value is Map<String, dynamic>) {
      if (_isStructuredPlaceCandidate(value)) {
        return value;
      }

      final graph = _findStructuredPlaceNode(value['@graph']);
      if (graph != null) return graph;

      for (final nestedValue in value.values) {
        final nested = _findStructuredPlaceNode(nestedValue);
        if (nested != null) return nested;
      }
    }

    if (value is List) {
      for (final item in value) {
        final nested = _findStructuredPlaceNode(item);
        if (nested != null) return nested;
      }
    }

    return null;
  }

  bool _isStructuredPlaceCandidate(Map<String, dynamic> value) {
    final typeNames = _structuredTypeNames(value['@type']);
    final hasPlaceType = typeNames.any((type) {
      final lower = type.toLowerCase();
      return lower.contains('place') ||
          lower.contains('business') ||
          lower.contains('restaurant') ||
          lower.contains('cafe') ||
          lower.contains('store') ||
          lower.contains('hotel') ||
          lower.contains('museum') ||
          lower.contains('park') ||
          lower.contains('bar') ||
          lower.contains('lodging') ||
          lower.contains('touristattraction');
    });

    final hasSignals =
        value['name'] != null &&
        (value.containsKey('address') ||
            value.containsKey('geo') ||
            value.containsKey('priceRange') ||
            value.containsKey('openingHours') ||
            value.containsKey('openingHoursSpecification') ||
            value.containsKey('telephone') ||
            value.containsKey('aggregateRating'));

    return hasPlaceType || hasSignals;
  }

  List<String> _structuredTypeNames(dynamic value) {
    if (value is String) return [value];
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  String? _sanitizePlaceName(String? value) {
    final cleaned = _clean(value);
    if (cleaned == null) return null;
    if (cleaned.toLowerCase() == 'google maps') return null;
    return cleaned;
  }

  String? _structuredAddress(dynamic value) {
    if (value is String) return _clean(value);

    if (value is List) {
      final parts = value
          .map(_structuredAddress)
          .whereType<String>()
          .where((part) => part.isNotEmpty)
          .toList();
      if (parts.isEmpty) return null;
      return parts.join(', ');
    }

    if (value is Map<String, dynamic>) {
      final country = value['addressCountry'];
      final orderedParts = <String>[];

      void append(dynamic part) {
        final cleaned = _clean(part?.toString());
        if (cleaned == null || orderedParts.contains(cleaned)) return;
        orderedParts.add(cleaned);
      }

      append(value['streetAddress']);
      append(value['addressLocality']);
      append(value['addressRegion']);
      append(value['postalCode']);
      if (country is Map<String, dynamic>) {
        append(country['name']);
      } else {
        append(country);
      }

      if (orderedParts.isEmpty) return null;
      return orderedParts.join(', ');
    }

    return null;
  }

  String? _structuredOpeningHours(Map<String, dynamic> value) {
    final openingHours = value['openingHours'];
    final inline = _structuredOpeningHoursValue(openingHours);
    if (inline != null) return inline;

    final specifications = value['openingHoursSpecification'];
    if (specifications is! List) return null;

    final segments = <String>[];
    for (final spec in specifications.whereType<Map<String, dynamic>>()) {
      final opens = _clean(spec['opens']?.toString());
      final closes = _clean(spec['closes']?.toString());
      if (opens == null || closes == null) continue;

      final range = '$opens - $closes';
      final dayLabel = _structuredDayLabel(spec['dayOfWeek']);
      final segment = dayLabel == null ? range : '$dayLabel: $range';
      if (!segments.contains(segment)) {
        segments.add(segment);
      }
    }

    if (segments.isEmpty) return null;
    if (segments.length == 1) {
      final single = segments.first;
      final index = single.indexOf(': ');
      return index == -1 ? single : single.substring(index + 2);
    }
    return segments.join('; ');
  }

  String? _structuredOpeningHoursValue(dynamic value) {
    if (value is String) return _clean(value);
    if (value is List) {
      final parts = value
          .map((item) => _clean(item?.toString()))
          .whereType<String>()
          .toList();
      if (parts.isEmpty) return null;
      return parts.join(', ');
    }
    return null;
  }

  String? _structuredDayLabel(dynamic value) {
    if (value is String) {
      return _clean(value.split('/').last);
    }

    if (value is List) {
      final days = value
          .map((item) => _clean(item?.toString().split('/').last))
          .whereType<String>()
          .toList();
      if (days.isEmpty) return null;
      return days.join(', ');
    }

    return null;
  }

  double? _structuredRating(dynamic value) {
    if (value is Map<String, dynamic>) {
      return _asDouble(value['ratingValue']);
    }
    return _asDouble(value);
  }

  double? _structuredCoordinate(dynamic value, String key) {
    if (value is! Map<String, dynamic>) return null;
    return _asDouble(value[key]);
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }
}

String? _prefer(String? current, String? next) {
  if (current != null && current.trim().isNotEmpty) return current;
  return _clean(next);
}

bool _isHttpImageUrl(String? value) {
  if (value == null) return false;
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

bool _isExternalWebsiteUrl(String? value) {
  if (value == null) return false;
  final uri = Uri.tryParse(value);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return false;
  }

  final host = uri.host.toLowerCase();
  if (host.isEmpty) return false;
  if (host.contains('google.') ||
      host == 'maps.app.goo.gl' ||
      host == 'goo.gl' ||
      host.contains('gstatic.com') ||
      host.contains('googleusercontent.com')) {
    return false;
  }

  return true;
}

bool _isRedirect(int statusCode) {
  return statusCode >= 300 && statusCode < 400;
}

String? _clean(String? value) {
  if (value == null) return null;
  final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return cleaned.isEmpty ? null : cleaned;
}

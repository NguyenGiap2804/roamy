import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/place.dart';

abstract class PlaceShareGateway {
  Future<void> share({
    required XFile file,
    required String text,
    required String subject,
  });
}

class SharePlusPlaceShareGateway implements PlaceShareGateway {
  const SharePlusPlaceShareGateway();

  @override
  Future<void> share({
    required XFile file,
    required String text,
    required String subject,
  }) {
    return SharePlus.instance.share(
      ShareParams(
        files: [file],
        text: text,
        subject: subject,
      ),
    );
  }
}

class PlaceShareService {
  PlaceShareService({PlaceShareGateway? gateway})
    : _gateway = gateway ?? const SharePlusPlaceShareGateway();

  final PlaceShareGateway _gateway;

  String buildShareText(Place place) {
    final lines = <String>[
      'Roamy pick: ${place.name}',
      '${place.category} • ${place.rating.toStringAsFixed(1)} stars',
      place.address,
    ];

    if (place.hasOpeningHours) {
      lines.add('Open: ${place.openingHours}');
    }

    if (place.hasPriceRange) {
      lines.add('Price: ${place.priceRange}');
    }

    if (place.hasMapsUrl) {
      lines.add(place.mapsUrl!);
    }

    return lines.join('\n');
  }

  String buildShareSubject(Place place) {
    return 'Roamy card • ${place.name}';
  }

  String buildFileName(Place place) {
    final normalized = place.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final fallback = normalized.isEmpty ? 'saved-place' : normalized;
    return 'roamy-card-$fallback.png';
  }

  Future<File> saveCardBytes(Uint8List bytes, {required Place place}) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}${buildFileName(place)}',
    );
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<void> shareCard(Uint8List bytes, {required Place place}) async {
    final file = await saveCardBytes(bytes, place: place);
    await _gateway.share(
      file: XFile(file.path),
      text: buildShareText(place),
      subject: buildShareSubject(place),
    );
  }
}

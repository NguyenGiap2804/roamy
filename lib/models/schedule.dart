class Schedule {
  const Schedule({
    required this.id,
    required this.placeId,
    required this.date,
    required this.time,
    required this.status,
    required this.hasReminder,
    this.placeName,
    this.category,
    this.address,
    this.openingHours,
    this.mapsUrl,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String placeId;
  final DateTime date;
  final String time;
  final String status;
  final bool hasReminder;
  final String? placeName;
  final String? category;
  final String? address;
  final String? openingHours;
  final String? mapsUrl;
  final double? latitude;
  final double? longitude;

  factory Schedule.fromJson(Map<String, dynamic> json) {
    final place = json['place'];
    final categoryJson = place is Map<String, dynamic>
        ? place['category']
        : null;
    return Schedule(
      id: json['id'] as String,
      placeId: json['placeId'] as String,
      date: DateTime.parse(json['date'] as String),
      time: json['time'] as String,
      status: json['status'] as String,
      hasReminder: (json['hasReminder'] as bool?) ?? false,
      placeName: place is Map<String, dynamic>
          ? place['name'] as String?
          : json['placeName'] as String?,
      category: categoryJson is Map<String, dynamic>
          ? categoryJson['name'] as String?
          : json['category'] as String?,
      address: place is Map<String, dynamic>
          ? place['address'] as String?
          : json['address'] as String?,
      openingHours: place is Map<String, dynamic>
          ? place['openingHours'] as String?
          : json['openingHours'] as String?,
      mapsUrl: place is Map<String, dynamic>
          ? place['mapsUrl'] as String?
          : json['mapsUrl'] as String?,
      latitude: place is Map<String, dynamic> && place['latitude'] != null
          ? (place['latitude'] as num).toDouble()
          : json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: place is Map<String, dynamic> && place['longitude'] != null
          ? (place['longitude'] as num).toDouble()
          : json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'date': _dateToApi(date),
      'time': time,
      'status': status,
      'hasReminder': hasReminder,
    };
  }

  String get displayPlaceName => placeName ?? 'Saved place';
  String get displayCategory => category ?? 'Other';
  String get displayAddress => address ?? 'No address';
  String get displayOpeningHours =>
      openingHours?.trim().isNotEmpty == true ? openingHours! : time;
  bool get hasMapsUrl => mapsUrl?.trim().isNotEmpty == true;
  bool get hasCoordinates => latitude != null && longitude != null;
}

String _dateToApi(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

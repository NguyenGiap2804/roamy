import '../core/utils/coordinates.dart';

const scheduleStatusUpcoming = 'UPCOMING';
const scheduleStatusDone = 'DONE';
const scheduleStatusCancelled = 'CANCELLED';

class Schedule {
  const Schedule({
    required this.id,
    required this.date,
    required this.time,
    required this.status,
    required this.hasReminder,
    this.placeId,
    this.title,
    this.note,
    this.placeName,
    this.category,
    this.address,
    this.openingHours,
    this.mapsUrl,
    this.latitude,
    this.longitude,
    this.isPendingSync = false,
  });

  final String id;
  final String? placeId;
  final String? title;
  final String? note;
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
  final bool isPendingSync;

  factory Schedule.fromJson(Map<String, dynamic> json) {
    final place = json['place'];
    final categoryJson = place is Map<String, dynamic>
        ? place['category']
        : null;
    return Schedule(
      id: json['id'] as String,
      placeId: json['placeId'] as String?,
      title: json['title'] as String?,
      note: json['note'] as String?,
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
      isPendingSync: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'title': title,
      'note': note,
      'date': _dateToApi(date),
      'time': time,
      'status': status,
      'hasReminder': hasReminder,
      'mapsUrl': mapsUrl,
    };
  }

  Schedule copyWith({
    String? id,
    Object? placeId = _unset,
    Object? title = _unset,
    Object? note = _unset,
    DateTime? date,
    String? time,
    String? status,
    bool? hasReminder,
    Object? placeName = _unset,
    Object? category = _unset,
    Object? address = _unset,
    Object? openingHours = _unset,
    Object? mapsUrl = _unset,
    Object? latitude = _unset,
    Object? longitude = _unset,
    bool? isPendingSync,
  }) {
    return Schedule(
      id: id ?? this.id,
      placeId: identical(placeId, _unset) ? this.placeId : placeId as String?,
      title: identical(title, _unset) ? this.title : title as String?,
      note: identical(note, _unset) ? this.note : note as String?,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      hasReminder: hasReminder ?? this.hasReminder,
      placeName: identical(placeName, _unset)
          ? this.placeName
          : placeName as String?,
      category: identical(category, _unset)
          ? this.category
          : category as String?,
      address: identical(address, _unset) ? this.address : address as String?,
      openingHours: identical(openingHours, _unset)
          ? this.openingHours
          : openingHours as String?,
      mapsUrl: identical(mapsUrl, _unset) ? this.mapsUrl : mapsUrl as String?,
      latitude: identical(latitude, _unset)
          ? this.latitude
          : latitude as double?,
      longitude: identical(longitude, _unset)
          ? this.longitude
          : longitude as double?,
      isPendingSync: isPendingSync ?? this.isPendingSync,
    );
  }

  String get displayPlaceName {
    if (placeName?.trim().isNotEmpty == true) return placeName!;
    if (title?.trim().isNotEmpty == true) return title!;
    return 'Lịch trình nhanh';
  }

  String get displayCategory => category ?? 'Other';
  String get displayAddress {
    if (address?.trim().isNotEmpty == true) return address!;
    if (note?.trim().isNotEmpty == true) return note!;
    return 'Chưa có ghi chú';
  }

  String get displayOpeningHours =>
      openingHours?.trim().isNotEmpty == true ? openingHours! : time;
  bool get hasMapsUrl => mapsUrl?.trim().isNotEmpty == true;
  bool get hasCoordinates => hasUsableCoordinates(latitude, longitude);
  bool get isQuickSchedule =>
      placeId?.trim().isNotEmpty != true &&
      (title?.trim().isNotEmpty == true || note?.trim().isNotEmpty == true);
  bool get isUpcoming => status == scheduleStatusUpcoming;
  bool get isDone => status == scheduleStatusDone;
  bool get isCancelled => status == scheduleStatusCancelled;
}

const Object _unset = Object();

String _dateToApi(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

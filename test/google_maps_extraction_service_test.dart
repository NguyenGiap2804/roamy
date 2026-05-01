import 'package:flutter_test/flutter_test.dart';
import 'package:roamy/services/google_maps_extraction_service.dart';

void main() {
  test('extracts place data from Google Maps preview payload', () {
    const previewPayload = '''
)]}'
[null,null,null,null,[[3724.79587088432,105.520821,21.0008138],[0,0,0],[1024,768],13.1],null,["id","token",["ngõ 2 đường TTGDQP","Thạch Hoà","Hòa Lạc","Hà Nội, Việt Nam"],null,[null,null,null,null,null,null,null,4.8],null,null,null,null,[null,null,21.0008138,105.520821],"0x31345b0017f7c6c5:0x590832fce1b90b23","Mây Lang Thang Cafe",null,["Quán cà phê"],"Thạch Hoà, Hòa Lạc",null,null,null,"Mây Lang Thang Cafe, ngõ 2 đường TTGDQP, Thạch Hoà, Hòa Lạc, Hà Nội, Việt Nam",null,null,null,null,null,null,[[3,1,["icon","ngõ 2 đường TTGDQP, Thạch Hoà, Hòa Lạc, Hà Nội, Việt Nam"]],[5,1,["icon","Mở cả ngày"]],[6,1,["icon","+84 984 916 161"]]]]
''';

    final service = GoogleMapsExtractionService();
    final data = service.extractFromPreviewBody(previewPayload);

    expect(data.name, 'Mây Lang Thang Cafe');
    expect(
      data.address,
      'ngõ 2 đường TTGDQP, Thạch Hoà, Hòa Lạc, Hà Nội, Việt Nam',
    );
    expect(data.openingHours, 'Mở cả ngày');
    expect(data.phone, '+84 984 916 161');
    expect(data.rating, 4.8);
    expect(data.latitude, 21.0008138);
    expect(data.longitude, 105.520821);
  });

  test('extracts price range from quoted Google Maps strings', () {
    const previewPayload = '''
)]}'
[null,null,null,null,[[3724.79587088432,105.520821,21.0008138]],null,["Mây Lang Thang Cafe","10.000 – 50.000 ₫ mỗi người","Đang mở cửa · Đóng cửa vào 22:30"]]
''';

    final service = GoogleMapsExtractionService();
    final data = service.extractFromPreviewBody(previewPayload);

    expect(data.priceRange, '10.000 – 50.000 ₫ mỗi người');
  });

  test('extracts split price range with currency prefix', () {
    const previewPayload = '''
)]}'
[null,null,null,null,[[3724.79587088432,105.520821,21.0008138]],null,["Mây Lang Thang Cafe","₫","10.000 – 50.000","mỗi người"]]
''';

    final service = GoogleMapsExtractionService();
    final data = service.extractFromPreviewBody(previewPayload);

    expect(data.priceRange, '₫ 10.000 – 50.000 mỗi người');
  });

  test('extracts numeric structured price level', () {
    const previewPayload = '''
)]}'
[null,null,null,null,[[3724.79587088432,105.520821,21.0008138]],null,["Mây Lang Thang Cafe"],["Mức giá", null, 2]]
''';

    final service = GoogleMapsExtractionService();
    final data = service.extractFromPreviewBody(previewPayload);

    expect(data.priceRange, '₫₫');
  });

  test('extracts compact Vietnamese per-person price range', () {
    const previewPayload = '''
)]}'
[null,null,null,null,[[3724.79587088432,105.520821,21.0008138]],null,["December Coffee","1-100.000 đ/người"]]
''';

    final service = GoogleMapsExtractionService();
    final data = service.extractFromPreviewBody(previewPayload);

    expect(data.priceRange, '1-100.000 đ/người');
  });

  test('does not use Google Maps report actions as opening hours', () {
    const previewPayload = '''
)]}'
[null,null,null,null,[[3724.7979821614035,105.807209,21.0677121]],null,["Công ty cổ phần SY Partners (SYP)","Đánh dấu địa điểm là đã đóng cửa, không tồn tại hoặc trùng lặp","Luxury Building, 99 Đ. Võ Chí Công, Khu đô thị Tây Hồ Tây, Xuân Đỉnh, Hà Nội, Việt Nam"]]
''';

    final service = GoogleMapsExtractionService();
    final data = service.extractFromPreviewBody(previewPayload);

    expect(data.openingHours, isNull);
  });

  test('keeps closed status when it includes an opening time', () {
    const previewPayload = '''
)]}'
[null,null,null,null,[[3724.7979821614035,105.807209,21.0677121]],null,["Công ty cổ phần SY Partners (SYP)","Đã đóng cửa · Mở cửa lúc 8:30 Thứ 5"]]
''';

    final service = GoogleMapsExtractionService();
    final data = service.extractFromPreviewBody(previewPayload);

    expect(data.openingHours, 'Đã đóng cửa · Mở cửa lúc 8:30 Thứ 5');
  });

  test('prefers real address over long Google Maps post text', () {
    const previewPayload = '''
)]}'
[null,null,null,null,[[3724.7979821614035,105.807209,21.0677121]],null,["id","token",["Luxury Building, 99 Đ. Võ Chí Công","Khu đô thị Tây Hồ Tây","Xuân Đỉnh","Hà Nội, Việt Nam"],null,[null,null,null,null,null,null,null,4.8],null,null,null,null,[null,null,21.0677121,105.807209],"0x3135ab0022581a47:0x9559220c02c6007c","Công ty cổ phần SY Partners (SYP)",null,["Công ty phần mềm"],"Khu đô thị Tây Hồ Tây, Xuân Đỉnh",null,null,null,"Công ty cổ phần SY Partners (SYP), Luxury Building, 99 Đ. Võ Chí Công, Khu đô thị Tây Hồ Tây, Xuân Đỉnh, Hà Nội, Việt Nam","[SYP x FTU] SY Partners at the 55th Anniversary of Japanese Language Education and the 20th Anniversary of the Japanese Department\\n\\nOn Saturday, April 18, SY Partners had the honor of participating in this meaningful event as a co-sponsor, marking an important milestone in Vietnam. Website: https://syp.vn",[[3,1,["icon","Luxury Building, 99 Đ. Võ Chí Công, Khu đô thị Tây Hồ Tây, Xuân Đỉnh, Hà Nội, Việt Nam"]]]]
''';

    final service = GoogleMapsExtractionService();
    final data = service.extractFromPreviewBody(previewPayload);

    expect(
      data.address,
      'Luxury Building, 99 Đ. Võ Chí Công, Khu đô thị Tây Hồ Tây, Xuân Đỉnh, Hà Nội, Việt Nam',
    );
  });
  test('extracts structured place details from HTML JSON-LD', () {
    const html = '''
<html>
  <head>
    <script type="application/ld+json">
      {
        "@context": "https://schema.org",
        "@type": "CafeOrCoffeeShop",
        "name": "The Cofftea",
        "address": {
          "@type": "PostalAddress",
          "streetAddress": "123 Pho Hue",
          "addressLocality": "Ha Noi",
          "addressCountry": "Viet Nam"
        },
        "priceRange": "100.000-200.000 VND/person",
        "openingHours": ["Mon-Sun 08:00-22:00"],
        "telephone": "+84 123 456 789",
        "aggregateRating": {
          "@type": "AggregateRating",
          "ratingValue": "4.6"
        },
        "geo": {
          "@type": "GeoCoordinates",
          "latitude": 21.0123,
          "longitude": 105.85
        }
      }
    </script>
  </head>
</html>
''';

    final service = GoogleMapsExtractionService();
    final data = service.extractFromHtmlBody(
      html,
      baseUri: Uri.parse('https://www.google.com/maps/place/The+Cofftea'),
    );

    expect(data.name, 'The Cofftea');
    expect(data.address, '123 Pho Hue, Ha Noi, Viet Nam');
    expect(data.priceRange, '100.000-200.000 VND/person');
    expect(data.openingHours, 'Mon-Sun 08:00-22:00');
    expect(data.phone, '+84 123 456 789');
    expect(data.rating, 4.6);
    expect(data.latitude, 21.0123);
    expect(data.longitude, 105.85);
  });

  test('falls back to ES5 deep link when preview link is missing', () {
    const html = '''
<html>
  <head>
    <script>
      window.ES5DGURL='/maps/place/The+Cofftea/@21.0151283,105.5181395,16z/data=!4m7!3m6!1s0x0:0x0';
    </script>
  </head>
</html>
''';

    final service = GoogleMapsExtractionService();
    final data = service.extractFromHtmlBody(
      html,
      baseUri: Uri.parse('https://www.google.com/maps/search/?api=1'),
    );

    expect(data.name, 'The Cofftea');
    expect(data.latitude, 21.0151283);
    expect(data.longitude, 105.5181395);
  });

  test('marks complete extracted place data as high confidence', () {
    const data = GoogleMapsPlaceData(
      name: 'The Cofftea',
      address: '123 Pho Hue, Ha Noi, Viet Nam',
      priceRange: '100.000-200.000 VND/person',
      openingHours: '08:00 - 22:00',
      phone: '+84 123 456 789',
      rating: 4.6,
      latitude: 21.0123,
      longitude: 105.85,
    );

    final review = data.review;

    expect(review.confidence, GoogleMapsExtractionConfidence.high);
    expect(review.needsManualReview, isFalse);
    expect(review.issues, isEmpty);
    expect(
      review.capturedFields,
      containsAll(<String>['Ten', 'Dia chi', 'Toa do', 'Gio mo cua']),
    );
  });

  test('still asks for manual review when only core fields are extracted', () {
    const data = GoogleMapsPlaceData(
      name: 'The Cofftea',
      address: '123 Pho Hue, Ha Noi, Viet Nam',
      latitude: 21.0123,
      longitude: 105.85,
    );

    final review = data.review;

    expect(review.confidence, GoogleMapsExtractionConfidence.high);
    expect(review.needsManualReview, isTrue);
    expect(
      review.issues,
      contains(
        'Link nay chi tra ve du lieu co ban. Nen doi chieu them gio mo cua, gia va lien he truoc khi luu.',
      ),
    );
  });
}

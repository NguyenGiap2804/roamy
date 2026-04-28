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
    expect(data.latitude, 21.0008138);
    expect(data.longitude, 105.520821);
  });
}

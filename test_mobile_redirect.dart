import 'dart:io';

void main() async {
  final url = 'https://maps.app.goo.gl/vtyp87TxY2ShPR6v5';
  final client = HttpClient();
  
  var request = await client.getUrl(Uri.parse(url));
  request.followRedirects = false;
  var response = await request.close();
  
  print('Status: ${response.statusCode}');
  print('Location: ${response.headers.value('location')}');
}

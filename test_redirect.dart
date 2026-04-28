import 'dart:io';

void main() async {
  final url = 'https://maps.app.goo.gl/vtyp87TxY2ShPR6v5';
  final client = HttpClient();
  
  var finalUrl = url;
  var request = await client.getUrl(Uri.parse(finalUrl));
  request.followRedirects = false;
  var response = await request.close();
  
  for (var i = 0; i < 10; i++) {
    if (response.isRedirect) {
      final location = response.headers.value('location');
      if (location != null) {
        finalUrl = Uri.parse(finalUrl).resolve(location).toString();
      }
      request = await client.getUrl(Uri.parse(finalUrl));
      request.followRedirects = false;
      response = await request.close();
    } else {
      break;
    }
  }
  
  print('Final URL: $finalUrl');
}

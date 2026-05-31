import 'dart:convert';
import 'dart:io';

void main() async {
  final apiKey = 'AIzaSyAA3rgg7CCR_hpD6ocpcq-NcnGcvGzdF2Q';
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
  
  final request = await HttpClient().getUrl(url);
  final response = await request.close();
  
  final body = await response.transform(utf8.decoder).join();
  print('Status code: ${response.statusCode}');
  print('Response: $body');
}

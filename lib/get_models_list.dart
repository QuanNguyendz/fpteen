import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=AIzaSyA9qvShw-HBqI-5YG_SOXRagZbtu_jMvOA');
  final request = await HttpClient().getUrl(url);
  final response = await request.close();
  final stringData = await response.transform(utf8.decoder).join();
  final data = jsonDecode(stringData);
  final models = data['models'] as List;
  for (var m in models) {
    var methods = m['supportedGenerationMethods'] as List?;
    if (methods != null && methods.contains('generateContent')) {
      print(m['name']);
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final query = 'Barangay 73, Caloocan';
  final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json');
  final response = await http.get(url, headers: {'User-Agent': 'kury3nte/1.0'});
  print('Response for $query: ${response.body}');
}

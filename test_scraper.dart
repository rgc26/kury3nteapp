import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'dart:convert';

void main() async {
  print('Starting scraper test...');
  
  final proxies = [
    {'url': 'https://thingproxy.freeboard.io/fetch/', 'isJson': false},
    {'url': 'https://cors-anywhere.herokuapp.com/', 'isJson': false},
    {'url': 'https://yacdn.org/proxy/', 'isJson': false},
  ];

  final targetUrl = 'https://company.meralco.com.ph/news-and-advisories/maintenance-schedule';

  String? html;
  
  if (false) {
    try {
      final response = await http.get(Uri.parse(targetUrl));
      if (response.statusCode == 200) {
        print('Direct fetch successful! Length: ${response.body.length}');
        html = response.body;
      } else {
        print('Direct fetch failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Direct fetch failed: $e');
    }
  }

  if (html == null) {
    for (final proxy in proxies) {
      try {
        final isJson = proxy['isJson'] as bool;
        final proxyUrl = isJson
            ? '${proxy['url']}${Uri.encodeComponent(targetUrl)}'
            : '${proxy['url']}$targetUrl';

        print('Trying proxy: ${proxy['url']}');
        final response = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          if (isJson) {
            final jsonData = json.decode(response.body);
            html = jsonData[proxy['contentKey']] as String? ?? '';
          } else {
            html = response.body;
          }
          print('Proxy fetch successful! Length: ${html?.length}');
          print('First 300 chars: ${html?.substring(0, html!.length > 300 ? 300 : html.length)}');
          if (html!.length > 1000) break; // only break if it's a real page
        } else {
          print('Proxy returned status ${response.statusCode}');
        }
      } catch (e) {
        print('Proxy failed: $e');
      }
    }
  }

  if (html == null || html.isEmpty) {
    print('All fetches failed.');
    return;
  }

  print('Parsing HTML...');
  final document = parse(html);
  final links = document.querySelectorAll('a[href*="maintenance-schedule/"]');
  print('Found ${links.length} links.');
  
  for (var link in links) {
    print('Link text: ${link.text.trim()}, Href: ${link.attributes['href']}');
  }
}

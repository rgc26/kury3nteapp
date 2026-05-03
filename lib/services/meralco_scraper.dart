import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import '../models/meralco_schedule.dart';

/// Scrapes real Meralco maintenance schedules and alert areas from
/// company.meralco.com.ph using a CORS proxy for browser access.
class MeralcoScraper {
  static const String _corsProxy = 'https://api.allorigins.win/get?url=';
  static const String _maintenanceUrl =
      'https://company.meralco.com.ph/news-and-advisories/maintenance-schedule';
  static const String _alertUrl =
      'https://company.meralco.com.ph/news-and-advisories/yellow-and-red-alert-locations';

  /// Fetches and parses real maintenance schedules from Meralco website
  Future<List<MeralcoSchedule>> fetchMaintenanceSchedules() async {
    try {
      final encodedUrl = Uri.encodeComponent(_maintenanceUrl);
      final response = await http.get(
        Uri.parse('$_corsProxy$encodedUrl'),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final htmlContent = jsonData['contents'] as String? ?? '';
        return _parseScheduleHtml(htmlContent);
      }
    } catch (e) {
      print('Error fetching maintenance schedules: $e');
    }
    return [];
  }

  /// Fetches and parses real Red/Yellow alert areas from Meralco website
  Future<List<AlertArea>> fetchAlertAreas() async {
    try {
      final encodedUrl = Uri.encodeComponent(_alertUrl);
      final response = await http.get(
        Uri.parse('$_corsProxy$encodedUrl'),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final htmlContent = jsonData['contents'] as String? ?? '';
        return _parseAlertHtml(htmlContent);
      }
    } catch (e) {
      print('Error fetching alert areas: $e');
    }
    return [];
  }

  /// Parses Meralco maintenance schedule HTML into structured data
  List<MeralcoSchedule> _parseScheduleHtml(String html) {
    final schedules = <MeralcoSchedule>[];
    final document = parse(html);
    
    // Target all links that go to a maintenance schedule detail page
    final links = document.querySelectorAll('a[href*="maintenance-schedule/"]');
    
    // Keep track of added URLs to avoid duplicates
    final seenUrls = <String>{};

    for (var link in links) {
      final detailUrl = link.attributes['href'] ?? '';
      if (detailUrl.isEmpty || seenUrls.contains(detailUrl)) continue;
      
      final titleText = link.text.trim();
      if (titleText.isEmpty || !titleText.contains(' - ')) continue;

      seenUrls.add(detailUrl);

      // Find the closest container to extract more details (time, reason)
      // Usually .views-row or .item or just a parent div
      var container = link.parent;
      while (container != null && 
             !container.classes.contains('views-row') && 
             !container.classes.contains('item') &&
             container.localName != 'div') {
        container = container.parent;
      }

      final content = container?.text ?? '';
      
      // Parse date and location
      final parts = titleText.split(' - ');
      final date = parts[0].trim();
      final location = parts.sublist(1).join(' - ').trim();

      String timeRange = '';
      String reason = '';
      String affectedAreas = '';

      // Pattern for "BETWEEN 9:00 AM AND 2:00 PM"
      final timeRegex = RegExp(r'BETWEEN\s+\d+[:\d]*\s*[AP]M\s+AND\s+\d+[:\d]*\s*[AP]M', caseSensitive: false);
      final timeMatch = timeRegex.firstMatch(content);
      if (timeMatch != null) {
        timeRange = timeMatch.group(0) ?? '';
      }

      // Pattern for "REASON: ..."
      final reasonRegex = RegExp(r'REASON:\s*(.+?)(?:$|\n|\.)', caseSensitive: false);
      final reasonMatch = reasonRegex.firstMatch(content);
      if (reasonMatch != null) {
        reason = reasonMatch.group(1)?.trim() ?? '';
      }

      // affected areas
      final bodyField = container?.querySelector('.views-field-body');
      if (bodyField != null) {
        affectedAreas = bodyField.text.trim();
      } else {
        affectedAreas = content
            .replaceAll(titleText, '')
            .replaceAll(timeRange, '')
            .replaceAll(RegExp(r'REASON:.*', caseSensitive: false), '')
            .replaceAll(RegExp(r'View all.*', caseSensitive: false), '')
            .trim();
      }

      if (affectedAreas.length > 500) {
        affectedAreas = '${affectedAreas.substring(0, 500)}...';
      }

      schedules.add(MeralcoSchedule(
        date: date,
        location: location,
        timeRange: timeRange.isNotEmpty ? timeRange : 'See details',
        affectedAreas: affectedAreas.isNotEmpty ? affectedAreas : 'Check details for areas',
        reason: reason.isNotEmpty ? reason : 'Scheduled maintenance',
        detailUrl: detailUrl.startsWith('http') ? detailUrl : 'https://company.meralco.com.ph$detailUrl',
      ));
    }

    return schedules;
  }

  /// Parses Meralco Red/Yellow alert HTML into structured AlertArea data
  List<AlertArea> _parseAlertHtml(String html) {
    final areas = <AlertArea>[];
    final document = parse(html);
    
    // Find all province toggles
    final provinceLinks = document.querySelectorAll('a.toggle.text-default');
    
    for (var provinceLink in provinceLinks) {
      final provinceName = provinceLink.text.trim();
      if (provinceName.isEmpty) continue;

      // The content is usually in the next element (toggle-content)
      final content = provinceLink.nextElementSibling;
      if (content == null) continue;

      // Cities are h4 tags
      final cityHeaders = content.querySelectorAll('h4');
      
      for (var cityHeader in cityHeaders) {
        final cityName = cityHeader.text.trim();
        if (cityName.isEmpty) continue;

        // Barangays are in the next element (ul/li)
        final nextElem = cityHeader.nextElementSibling;
        final List<String> barangays = [];
        
        if (nextElem != null && nextElem.localName == 'ul') {
          final items = nextElem.querySelectorAll('li');
          for (var li in items) {
            // Remove the arrow icon if present
            String b = li.text.replaceAll('→', '').trim();
            if (b.isNotEmpty) barangays.add(b);
          }
        }

        if (barangays.isNotEmpty) {
          areas.add(AlertArea(
            province: provinceName,
            city: cityName,
            barangays: barangays,
            alertLevel: AlertLevel.yellow,
          ));
        }
      }
    }

    return areas;
  }
}


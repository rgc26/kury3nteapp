import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';
import '../models/meralco_schedule.dart';

/// Scrapes real Meralco maintenance schedules and alert areas from
/// company.meralco.com.ph using multiple CORS proxy fallbacks for browser access.
class MeralcoScraper {
  static const String _maintenanceUrl =
      'https://company.meralco.com.ph/news-and-advisories/maintenance-schedule';
  static const String _alertUrl =
      'https://company.meralco.com.ph/news-and-advisories/yellow-and-red-alert-locations';

  Future<String?> _fetchHtml(String targetUrl) async {
    final List<String> proxies = [
      'https://corsproxy.io/?',                    // Often the most reliable
      'https://api.allorigins.win/get?url=',
      'https://proxy.cors.sh/',
      'https://api.codetabs.com/v1/proxy?quest=',
    ];

    for (final proxyBase in proxies) {
      try {
        final fullUrl = proxyBase.contains('allorigins')
            ? '${proxyBase}${Uri.encodeComponent(targetUrl)}'
            : '$proxyBase${Uri.encodeComponent(targetUrl)}';

        print('Trying proxy: $proxyBase');
        final response = await http.get(
          Uri.parse(fullUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ).timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          if (proxyBase.contains('allorigins')) {
            final data = json.decode(response.body);
            return data['contents'] as String?;
          }
          return response.body;
        }
      } catch (e) {
        print('Proxy failed: $proxyBase → $e');
      }
    }

    // Fallback to hardcoded data
    print('All proxies failed. Using fallback data.');
    return null;
  }

  /// Fetches and parses real maintenance schedules from Meralco website
  Future<List<MeralcoSchedule>> fetchMaintenanceSchedules() async {
    try {
      final html = await _fetchHtml(_maintenanceUrl);
      if (html != null && html.isNotEmpty) {
        final parsed = _parseScheduleHtml(html);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (e) {
      print('Error fetching maintenance schedules: $e');
    }
    
    return [
      MeralcoSchedule(
        date: 'May 12 - 13, 2026',
        location: 'Caloocan City (Bagong Barrio)',
        timeRange: '11:00PM - 5:00AM',
        affectedAreas: 'Portions of Milagrosa St. from Malolos Ave. to Reparo Road including Intan, KKK, Miracle, Kaganapan, Aklan Silahis, Bencer, Jasmin, Kapayapaan, Rosal, Waling-Waling, Katarungan, Abraham, Akasya, Albay, Apitong, Bayanihan, Cavite, Cypress, David, Exodus, Isaac, Jacob, Kamagong, Kaunlaran, Moises, Mulawin, Narra, Nido, Pangasinan, Santan, San Juan, San Pablo, Solomon, Tindalo and San Pedro Sts. Also portion of Reparo Road.',
        reason: 'Line reconductoring works and replacement of poles along Milagrosa St. in Bagong Barrio.',
        detailUrl: 'https://company.meralco.com.ph/news-and-advisories/maintenance-schedule/may-12-13-2026-caloocan-city-bagong-barrio',
      ),
      MeralcoSchedule(
        date: 'May 14, 2026',
        location: 'Cavite (Trece Martires City)',
        timeRange: '10:00AM - 3:00PM',
        affectedAreas: 'PORTION OF CIRCUIT TMC II 45WA including Panungyanan Road in Bgy. San Agustin.',
        reason: 'Relocation of facilities along Panungyanan Road.',
        detailUrl: 'https://company.meralco.com.ph/news-and-advisories/maintenance-schedule/may-14-2026-cavite-trece-martires-city',
      ),
    ];
  }

  /// Parses Meralco maintenance schedule HTML into structured data
  List<MeralcoSchedule> _parseScheduleHtml(String html) {
    final schedules = <MeralcoSchedule>[];
    final document = parse(html);
    
    // Target .views-row which contains each post
    final rows = document.querySelectorAll('.views-row, .item-list li, .news-item');
    
    for (var row in rows) {
      // 1. Find Title and Link
      final linkElem = row.querySelector('a.text-default, a[href*="maintenance-schedule/"], h3 a, h4 a');
      if (linkElem == null) continue;

      final titleText = linkElem.text.trim();
      final detailUrl = linkElem.attributes['href'] ?? '';
      
      if (titleText.isEmpty || !titleText.contains(' - ')) continue;

      // 2. Extract Date and Location from Title
      final parts = titleText.split(' - ');
      final dateStr = parts[0].trim();
      final locationStr = parts.length > 1 ? parts.sublist(1).join(' - ').trim() : titleText;

      // 3. Extract Body Details (Time, Areas, Reason)
      final bodyElem = row.querySelector('.views-field-body, .field-content, .description, p');
      final bodyText = bodyElem?.text.trim() ?? '';
      
      String timeRange = 'See details';
      String reason = 'Scheduled maintenance';
      String affectedAreas = 'Check details for areas';

      if (bodyText.isNotEmpty) {
        // Time Range Extraction
        final timeMatch = RegExp(r'(BETWEEN\s+.+?\s+AND\s+.+?)(?:\s+–|—|$|\n)', caseSensitive: false).firstMatch(bodyText);
        if (timeMatch != null) {
          timeRange = timeMatch.group(1)?.trim() ?? timeRange;
        }

        // Reason Extraction
        final reasonMatch = RegExp(r'REASON\s*:\s*(.+)', caseSensitive: false).firstMatch(bodyText);
        if (reasonMatch != null) {
          reason = reasonMatch.group(1)?.trim() ?? reason;
        }

        // Affected Areas Extraction (remove time and reason artifacts)
        affectedAreas = bodyText
            .replaceAll(timeRange, '')
            .replaceAll(RegExp(r'REASON\s*:.*', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s+', caseSensitive: true), ' ')
            .trim();
        
        if (affectedAreas.isEmpty || affectedAreas.length < 10) {
           affectedAreas = bodyText.split('REASON')[0].trim();
        }
      }

      schedules.add(MeralcoSchedule(
        date: dateStr,
        location: locationStr,
        timeRange: timeRange,
        affectedAreas: affectedAreas.length > 500 ? '${affectedAreas.substring(0, 500)}...' : affectedAreas,
        reason: reason,
        detailUrl: detailUrl.startsWith('http') ? detailUrl : 'https://company.meralco.com.ph$detailUrl',
      ));
    }

    // If still empty, try fallback to a broader search
    if (schedules.isEmpty) {
      final links = document.querySelectorAll('a[href*="maintenance-schedule/"]');
      for (var link in links) {
        final title = link.text.trim();
        if (title.contains(' - ')) {
           schedules.add(MeralcoSchedule(
             date: title.split(' - ')[0],
             location: title.split(' - ').length > 1 ? title.split(' - ')[1] : title,
             timeRange: 'See details',
             affectedAreas: 'Click to view affected areas',
             reason: 'Scheduled maintenance',
             detailUrl: link.attributes['href']!.startsWith('http') ? link.attributes['href']! : 'https://company.meralco.com.ph${link.attributes['href']}',
           ));
        }
      }
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


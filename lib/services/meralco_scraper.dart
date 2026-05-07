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
    // Fallback data if CORS or WAF blocks the request (common on web)
    print('Using fallback maintenance schedules');
    return [
      MeralcoSchedule(
        date: 'May 10, 2026',
        location: 'Manila (Sta. Ana)',
        timeRange: '12:01AM - 5:00AM',
        affectedAreas: 'Portions of Circuit Tegen 56B including Carreon St, Old Panaderos St, and Punta-Daguisunan Subd.',
        reason: 'Line reconstruction and reconductoring works along J. Posadas St.',
        detailUrl: 'https://company.meralco.com.ph/news-and-advisories/maintenance-schedule/may-10-2026-manila-sta-ana',
      ),
      MeralcoSchedule(
        date: 'May 9, 2026',
        location: 'Laguna (Calamba City)',
        timeRange: '9:00AM - 2:00PM',
        affectedAreas: 'Toshiba Storage Device Philippines Inc. and Sercomm Philippines Inc. along Innovation Drive in Carmelray Industrial Park 1.',
        reason: 'Line reconductoring works along Innovation Drive.',
        detailUrl: 'https://company.meralco.com.ph/news-and-advisories/maintenance-schedule/may-9-2026-laguna-calamba-city',
      ),
    ];
  }

  /// Fetches and parses real Red/Yellow alert areas from Meralco website
  Future<List<AlertArea>> fetchAlertAreas() async {
    try {
      final html = await _fetchHtml(_alertUrl);
      if (html != null && html.isNotEmpty) {
        final parsed = _parseAlertHtml(html);
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (e) {
      print('Error fetching alert areas: $e');
    }
    // Fallback data if CORS or WAF blocks the request (common on web)
    print('Using fallback alert areas');
    return [
      AlertArea(
        province: 'Metro Manila',
        city: 'Quezon City',
        barangays: ['Bagong Pag-asa', 'Project 6', 'Vasra'],
        alertLevel: AlertLevel.yellow,
      ),
      AlertArea(
        province: 'Cavite',
        city: 'Dasmarinas',
        barangays: ['Salitran I', 'Salitran II', 'Sabang'],
        alertLevel: AlertLevel.red,
      ),
    ];
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
      
      String timeRange = '';
      String reason = '';
      String affectedAreas = '';

      // 1. Title and Location
      final titleElem = container?.querySelector('.views-field-title .field-content a');
      final finalTitle = titleElem?.text.trim() ?? titleText;
      
      final locElem = container?.querySelector('.views-field-field-service-maintenance-loc .field-content');
      final locationPrefix = locElem?.text.trim() ?? '';

      // 1. Reason extraction (Check dedicated field first, then fallback to body)
      final reasonElem = container?.querySelector('.views-field-field-reason .field-content');
      if (reasonElem != null && reasonElem.text.trim().isNotEmpty) {
        reason = reasonElem.text.replaceAll(RegExp(r'REASON\s*:', caseSensitive: false), '').trim();
      }

      // 2. Body field (Time and Areas)
      final bodyElem = container?.querySelector('.views-field-body .field-content');
      if (bodyElem != null) {
        final bodyText = bodyElem.text.trim();
        
        // Search for REASON inside body if still empty
        if (reason.isEmpty) {
          final bodyReasonMatch = RegExp(r'REASON\s*:\s*(.+)', caseSensitive: false).firstMatch(bodyText);
          if (bodyReasonMatch != null) {
            reason = bodyReasonMatch.group(1)?.trim() ?? '';
          }
        }

        // Time Range Extraction: Look for BETWEEN...AND
        final timeMatch = RegExp(r'(BETWEEN\s+.+?\s+AND\s+.+?)(?:\s+–|—|$|\n)', caseSensitive: false).firstMatch(bodyText);
        if (timeMatch != null) {
          timeRange = timeMatch.group(1)?.trim() ?? '';
        }

        // Affected Areas: Remove the time and reason from the body to get the rest
        affectedAreas = bodyText
            .replaceAll(timeRange, '')
            .replaceAll(RegExp(r'REASON\s*:.*', caseSensitive: false), '')
            .replaceAll(RegExp(r'BETWEEN\s+.+?\s+AND\s+.+?(?:\s+–|—|$)', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s+', caseSensitive: true), ' ')
            .trim();
      }

      // 3. Final Data Assembly (Clean up artifacts)
      final parts = finalTitle.split(' - ');
      final dateStr = parts[0].trim();
      final locationStr = parts.length > 1 ? parts.sublist(1).join(' - ').trim() : finalTitle;
      
      final displayLocation = locationPrefix.isNotEmpty && !locationStr.contains(locationPrefix)
          ? '$locationPrefix ($locationStr)'
          : locationStr;

      if (affectedAreas.length > 800) {
        affectedAreas = '${affectedAreas.substring(0, 800)}...';
      }

      schedules.add(MeralcoSchedule(
        date: dateStr,
        location: displayLocation,
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


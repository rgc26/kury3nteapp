import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';
import '../data/energy_tips.dart';

/// AI service for generating personalized energy-saving tips using OpenRouter.
/// Falls back to pre-built tips when no API key is available.
class AiService {
  String? _apiKey;
  final String _baseUrl = 'https://openrouter.ai/api/v1';
  
  // Use the most common free alias for Gemini 2.0 Flash
  final String _defaultModel = 'google/gemini-2.0-flash:free';

  AiService() {
    // 1. Try Environment Variable first (Safe for Production/Vercel)
    const envVarKey = String.fromEnvironment('OPENROUTER_API_KEY');
    
    // 2. Try DotEnv fallback (Convenient for Local Dev)
    String? dotEnvKey;
    try {
      if (dotenv.isInitialized) {
        dotEnvKey = dotenv.maybeGet('OPENROUTER_API_KEY');
      }
    } catch (_) {}

    // 3. Use whichever source provides a key
    final finalKey = (envVarKey.isNotEmpty) ? envVarKey : (dotEnvKey ?? '');

    if (finalKey.isNotEmpty) {
      configure(finalKey);
      debugPrint('AiService: OpenRouter API key loaded successfully (${finalKey.substring(0, 8)}...)');
    } else {
      debugPrint('AiService: WARNING - No OpenRouter API key found! Set it in Settings or .env file.');
    }
  }

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  void configure(String apiKey) {
    _apiKey = apiKey;
  }

  /// Generate personalized energy-saving tips based on appliance profile
  Future<String> generateTips({
    required List<Map<String, dynamic>> applianceProfile,
    required double totalDailyKwh,
    required double estimatedMonthlyBill,
  }) async {
    if (!isConfigured) {
      return _getFallbackTips(applianceProfile);
    }

    try {
      final prompt = '''
As an energy expert in the Philippines, provide 4-6 very short and practical energy-saving tips in Taglish (Tagalog-English mix) based on this appliance profile:
${applianceProfile.map((a) => '- ${a['name']}: ${a['wattage']}W, ${a['hoursPerDay']} hours/day').join('\n')}

Strict constraints:
- Language: Taglish (Filipino context).
- Format: Bullet points ONLY.
- Length: Maximum 2 short sentences per tip.
- Focus: Highest impact savings for these specific appliances.
- Tone: Direct and helpful.

Total daily consumption: ${totalDailyKwh.toStringAsFixed(2)} kWh.
Estimated monthly bill: ₱${estimatedMonthlyBill.toStringAsFixed(0)}.
''';

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://kuryente.app', // Required for OpenRouter rankings
          'X-Title': 'Kuryente App',
        },
        body: jsonEncode({
          'model': _defaultModel,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.1,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content']?.toString().trim() ?? _getFallbackTips(applianceProfile);
      } else {
        debugPrint('OpenRouter Error: ${response.body}');
        return _getFallbackTips(applianceProfile);
      }
    } catch (e) {
      debugPrint('AiService generateTips Error: $e');
      return _getFallbackTips(applianceProfile);
    }
  }

  /// Analyze an image of an appliance and suggest name, wattage, and icon.
  /// Returns {'data': result} on success or {'error': message} on failure.
  Future<Map<String, dynamic>> analyzeApplianceImage(List<int> imageBytes) async {
    if (!isConfigured) {
      return {'error': 'AI not configured. API key missing.'};
    }

    if (imageBytes.isEmpty) {
      return {'error': 'Image is empty. Try taking the photo again.'};
    }

    try {
      final base64Image = base64Encode(imageBytes);
      
      // Detect MIME type
      String mimeType = 'image/jpeg';
      if (imageBytes.length > 4) {
        if (imageBytes[0] == 137 && imageBytes[1] == 80 && imageBytes[2] == 78 && imageBytes[3] == 71) {
          mimeType = 'image/png';
        } else if (imageBytes[0] == 82 && imageBytes[1] == 73 && imageBytes[2] == 70 && imageBytes[3] == 70) {
          mimeType = 'image/webp';
        }
      }

      final prompt = '''
You are a Universal Home Appliance Scanner for an energy audit app in the Philippines.
Your goal is to identify ANY household appliance from an image and estimate its power consumption.

Instructions:
1. Identify the appliance name (be specific, e.g., "Inverter Refrigerator", "6-Blade Clip Fan", "Gaming PC").
2. Estimate the typical wattage based on common Philippine household standards.
3. Categorize it into one of these standard icon_keys:
   - "ac", "tv", "ref", "fan", "wash", "cook", "pc", "light", "iron", "water", "other"

Return ONLY a JSON object:
{
  "name": "Full Name",
  "wattage": 000, 
  "icon_key": "category_from_list"
}
''';

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://kuryente.app',
          'X-Title': 'Kuryente App',
        },
        body: jsonEncode({
          'model': _defaultModel,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:$mimeType;base64,$base64Image',
                  }
                }
              ]
            }
          ],
          'temperature': 0.4,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String text = data['choices'][0]['message']['content'] ?? '';
        
        // Aggressive JSON extraction
        final int start = text.indexOf('{');
        final int end = text.lastIndexOf('}');
        if (start == -1 || end == -1) {
          return {'error': 'AI could not identify the appliance.'};
        }
        
        final String jsonStr = text.substring(start, end + 1);
        final Map<String, dynamic> parsed = jsonDecode(jsonStr);
        
        return {
          'data': {
            'name': parsed['name'] ?? 'Unknown Appliance',
            'wattage': (parsed['wattage'] is int) ? parsed['wattage'] : int.tryParse(parsed['wattage']?.toString() ?? '0') ?? 100,
            'icon_key': parsed['icon_key'] ?? 'other',
          }
        };
      } else {
        return {'error': 'API Error: ${response.statusCode}'};
      }
    } catch (e) {
      debugPrint('AiService analyzeApplianceImage Error: $e');
      return {'error': 'AI Error: $e'};
    }
  }

  /// Fallback tips when AI is unavailable
  String _getFallbackTips(List<Map<String, dynamic>> applianceProfile) {
    final applianceNames = applianceProfile
        .map((a) => (a['name'] as String).toLowerCase())
        .toList();

    final relevantTips = energySavingTips.where((tip) {
      final tipAppliance = tip['appliance'] ?? '';
      if (tipAppliance == 'general') return true;
      return applianceNames.any((name) => name.contains(tipAppliance) || tipAppliance.contains(name));
    }).take(5).toList();

    if (relevantTips.isEmpty) {
      return energySavingTips.take(5).map((t) => '🔋 ${t['title']}\n${t['tip']}\n💰 Potential savings: ${t['savings']}\n').join('\n');
    }

    return relevantTips.map((t) => '🔋 ${t['title']}\n${t['tip']}\n💰 Potential savings: ${t['savings']}\n').join('\n');
  }
}

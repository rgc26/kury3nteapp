import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:typed_data';
import '../data/energy_tips.dart';

/// Gemini AI service for generating personalized energy-saving tips.
/// Falls back to pre-built tips when no API key is available.
class GeminiService {
  GenerativeModel? _model;
  GenerativeModel? _visionModel;
  String? _apiKey;

  GeminiService() {
    // 1. Try Environment Variable first (Safe for Production/Vercel)
    const envVarKey = String.fromEnvironment('GEMINI_API_KEY');
    
    // 2. Try DotEnv fallback (Convenient for Local Dev)
    String? dotEnvKey;
    try {
      if (dotenv.isInitialized) {
        dotEnvKey = dotenv.maybeGet('GEMINI_API_KEY');
      }
    } catch (_) {}

    // 3. Use whichever source provides a key (no hardcoded fallback)
    final finalKey = (envVarKey.isNotEmpty) ? envVarKey : (dotEnvKey ?? '');

    if (finalKey.isNotEmpty) {
      configure(finalKey);
      debugPrint('GeminiService: API key loaded successfully (${finalKey.substring(0, 8)}...)');
    } else {
      debugPrint('GeminiService: WARNING - No API key found! Set it in Settings or .env file.');
    }
  }

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  void configure(String apiKey) {
    _apiKey = apiKey;
    // Text model with low temperature for tips
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        topP: 0.95,
        topK: 40,
      ),
    );
    // Vision model with higher temperature for image recognition
    _visionModel = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.4,
      ),
    );
  }

  /// Generate personalized energy-saving tips based on appliance profile
  Future<String> generateTips({
    required List<Map<String, dynamic>> applianceProfile,
    required double totalDailyKwh,
    required double estimatedMonthlyBill,
  }) async {
    if (!isConfigured || _model == null) {
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

      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text ?? _getFallbackTips(applianceProfile);
    } catch (e) {
      return _getFallbackTips(applianceProfile);
    }
  }

  /// Analyze an image of an appliance and suggest name, wattage, and icon.
  /// Returns {'data': result} on success or {'error': message} on failure.
  Future<Map<String, dynamic>> analyzeApplianceImage(List<int> imageBytes, {String? filePath}) async {
    if (!isConfigured || _visionModel == null) {
      return {'error': 'AI not configured. API key missing.'};
    }

    if (imageBytes.isEmpty) {
      return {'error': 'Image is empty. Try taking the photo again.'};
    }

    try {
      final prompt = '''
You are an expert Home Appliance Scanner for an energy audit app in the Philippines.
Analyze this image and identify the appliance accurately.

Categories and typical Wattage hints:
- "pc": Laptops (30-65W), Desktop PC (150-300W), Monitor (20-40W).
- "fan": 
    * Clip Fans/Small Wall Fans (12-25W)
    * Desk Fans (35-50W)
    * Stand Fans (50-75W)
    * Ceiling Fans (50-100W)
- "tv": LED TV (30-100W depending on size).
- "ref": Refrigerator (100-200W), Inverter Ref (lower avg).
- "ac": Window AC (700-1500W), Split-type AC (800-2000W).
- "cook": Rice cooker (400-800W), Microwave (700-1200W), Induction Cooker (1000-2000W).
- "wash": Washing machine (300-500W), Spin Dryer (150-300W).

Return ONLY a JSON object:
{
  "name": "Specific Name (e.g., 6-Blade Clip Fan)",
  "wattage": 15, 
  "icon_key": "fan"
}
''';

      // Auto-detect MIME type from file bytes
      String mimeType = 'image/jpeg';
      if (imageBytes.length > 4) {
        // PNG starts with 137 80 78 71
        if (imageBytes[0] == 137 && imageBytes[1] == 80 && imageBytes[2] == 78 && imageBytes[3] == 71) {
          mimeType = 'image/png';
        }
        // WebP starts with RIFF....WEBP
        if (imageBytes[0] == 82 && imageBytes[1] == 73 && imageBytes[2] == 70 && imageBytes[3] == 70) {
          mimeType = 'image/webp';
        }
      }

      debugPrint('Gemini: Sending image (${imageBytes.length} bytes, $mimeType)');

      final response = await _visionModel!.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart(mimeType, Uint8List.fromList(imageBytes)),
        ])
      ]);

      final text = response.text;
      debugPrint('Gemini Raw Response: $text');
      if (text == null || text.isEmpty) {
        return {'error': 'AI returned empty response. Try a clearer photo.'};
      }

      // Aggressive JSON extraction: Find first { and last }
      final int start = text.indexOf('{');
      final int end = text.lastIndexOf('}');
      if (start == -1 || end == -1) {
        return {'error': 'AI could not identify. Response: ${text.substring(0, text.length.clamp(0, 100))}'};
      }
      
      final String jsonStr = text.substring(start, end + 1);
      debugPrint('Gemini Extracted JSON: $jsonStr');
      final Map<String, dynamic> parsed = jsonDecode(jsonStr);
      
      return {
        'data': {
          'name': parsed['name'] ?? 'Unknown Appliance',
          'wattage': (parsed['wattage'] is int) ? parsed['wattage'] : int.tryParse(parsed['wattage']?.toString() ?? '0') ?? 100,
          'icon_key': parsed['icon_key'] ?? 'other',
        }
      };
    } catch (e) {
      debugPrint('Gemini Analysis Error: $e');
      return {'error': 'AI Error: ${e.toString().substring(0, e.toString().length.clamp(0, 150))}'};
    }
  }


  /// Fallback tips when Gemini is unavailable
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

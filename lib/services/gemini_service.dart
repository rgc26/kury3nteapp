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

    final finalKey = (envVarKey.isNotEmpty) ? envVarKey : dotEnvKey;

    if (finalKey != null && finalKey.isNotEmpty) {
      configure(finalKey);
    }
  }

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  void configure(String apiKey) {
    _apiKey = apiKey;
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
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
  Future<Map<String, dynamic>?> analyzeApplianceImage(List<int> imageBytes) async {
    if (!isConfigured || _model == null) return null;

    try {
      final prompt = '''
Analyze this image of a home appliance. Return a JSON object with:
"name": A concise name for the appliance (e.g., "Inverter Split-Type AC").
"wattage": Typical wattage (int).
"icon_key": One of these keys ONLY: "ac", "tv", "ref", "fan", "wash", "cook", "pc", "other".

Response MUST be ONLY the JSON object.
''';

      debugPrint('Gemini: Starting image analysis... (Bytes: ${imageBytes.length})');
      if (imageBytes.isEmpty) {
        debugPrint('Gemini Error: Image bytes are empty');
        return null;
      }

      final response = await _model!.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', Uint8List.fromList(imageBytes)),
        ])
      ]);

      final text = response.text;
      debugPrint('Gemini Raw Response: $text');
      if (text == null || text.isEmpty) return null;

      // Aggressive JSON extraction: Find first { and last }
      final int start = text.indexOf('{');
      final int end = text.lastIndexOf('}');
      if (start == -1 || end == -1) {
        debugPrint('Gemini Error: No JSON object found in response');
        return null;
      }
      
      final String jsonStr = text.substring(start, end + 1);
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      
      return {
        'name': data['name'] ?? 'Unknown Appliance',
        'wattage': (data['wattage'] is int) ? data['wattage'] : int.tryParse(data['wattage']?.toString() ?? '0') ?? 0,
        'icon_key': data['icon_key'] ?? 'other',
      };
    } catch (e) {
      debugPrint('Gemini Analysis Error: $e');
      return null;
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

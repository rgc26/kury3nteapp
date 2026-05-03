import 'package:google_generative_ai/google_generative_ai.dart';
import '../data/energy_tips.dart';

/// Gemini AI service for generating personalized energy-saving tips.
/// Falls back to pre-built tips when no API key is available.
class GeminiService {
  GenerativeModel? _model;
  String? _apiKey;

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  void configure(String apiKey) {
    _apiKey = apiKey;
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
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
Ikaw ay isang energy consultant para sa isang Filipino household na naka-experience ng energy crisis.

APPLIANCE PROFILE:
${applianceProfile.map((a) => '- ${a['name']}: ${a['wattage']}W, ${a['hoursPerDay']} hours/day').join('\n')}

Total Daily Consumption: ${totalDailyKwh.toStringAsFixed(2)} kWh
Estimated Monthly Bill: ₱${estimatedMonthlyBill.toStringAsFixed(2)}

Please provide 5 SPECIFIC, ACTIONABLE energy-saving tips in TAGLISH (Filipino-English mix) based on this exact appliance profile. Format each tip as:

🔋 [TIP TITLE]
[2-3 sentence explanation in Taglish with specific savings estimate]

Focus on the highest-consuming appliances first. Include peso savings estimates where possible. Be practical and consider the Philippine context (brownouts, hot climate, typical Filipino household).
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text ?? _getFallbackTips(applianceProfile);
    } catch (e) {
      return _getFallbackTips(applianceProfile);
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

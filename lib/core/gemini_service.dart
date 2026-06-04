import 'package:google_generative_ai/google_generative_ai.dart';
import 'auth_state.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  GenerativeModel? _model;

  bool get isConfigured => AuthState().geminiApiKey.isNotEmpty;

  Future<String> generateFinancialAdvice(String userQuery, Map<String, dynamic> contextData) async {
    final apiKey = AuthState().geminiApiKey;
    if (apiKey.isEmpty) {
      return "⚠️ Gemini API Key is not set in Settings! Please configure your API key to enable live AI coaching.";
    }

    try {
      // Build a comprehensive context system prompt
      final summary = contextData['summary'] ?? {};
      final double balance = (summary['currentBalance'] as num?)?.toDouble() ?? 0.0;
      final double totalExpenses = (summary['totalExpenses'] as num?)?.toDouble() ?? 0.0;
      final double totalIncome = (summary['totalIncome'] as num?)?.toDouble() ?? 0.0;
      final double totalSavings = (summary['totalSavings'] as num?)?.toDouble() ?? 0.0;
      final double pendingBorrowed = (summary['pendingBorrowed'] as num?)?.toDouble() ?? 0.0;
      final double pendingReceivables = (summary['pendingReceivables'] as num?)?.toDouble() ?? 0.0;
      final double dailyLimit = (summary['dailyLimit'] as num?)?.toDouble() ?? 0.0;

      final goals = contextData['goals'] as List? ?? [];
      final expenses = contextData['expenses'] as List? ?? [];

      final goalsText = goals.map((g) {
        return "- ${g['goalName']}: Saved ${AuthState().currency}${g['currentAmount']} of ${AuthState().currency}${g['targetAmount']} (Due: ${g['deadline']})";
      }).join('\n');

      final expensesText = expenses.take(30).map((e) {
        return "- ${e['date']}: ${AuthState().currency}${e['amount']} on ${e['note'] ?? e['category']} [Category: ${e['category']}, Classification: ${e['needOrWant'] ?? e['classification']}]";
      }).join('\n');

      final systemInstruction = """
You are MoneyMate AI Coach, a premium, friendly, and expert personal finance assistant designed with Apple-style elegance, clarity, and precision.
Your answers should be direct, clean, and beautifully structured (using markdown bullet points, tables, bold text).
Use the user's custom currency symbol: "${AuthState().currency}" for all monetary values.

Here is the live financial context of the user:
- Username: ${AuthState().userName}
- Monthly Income: ${AuthState().currency}${totalIncome.toStringAsFixed(0)}
- Current Cash/Bank Balance: ${AuthState().currency}${balance.toStringAsFixed(0)}
- Total Monthly Expenses: ${AuthState().currency}${totalExpenses.toStringAsFixed(0)}
- Total Savings: ${AuthState().currency}${totalSavings.toStringAsFixed(0)}
- Money Owed to Others (Borrowed): ${AuthState().currency}${pendingBorrowed.toStringAsFixed(0)}
- Money Owed to User (Receivables): ${AuthState().currency}${pendingReceivables.toStringAsFixed(0)}
- Configured Daily Limit: ${AuthState().currency}${dailyLimit.toStringAsFixed(0)} / day
- Emergency Threshold: ${AuthState().currency}${AuthState().emergencyThreshold.toStringAsFixed(0)}

Active Savings Goals:
${goalsText.isEmpty ? 'No goals logged.' : goalsText}

Recent Transactions (last 30):
${expensesText.isEmpty ? 'No transactions logged.' : expensesText}

Ensure you base all financial reasoning, affordability math, and savings advice strictly on the live data provided above.
If the user asks to log/track an expense (e.g., "spent 50 on snacks"), do not execute the transaction yourself. Instead, acknowledge the request, give them a smart financial tip on that category, and kindly inform them you've logged it (it will be intercepted and logged by the client shell).
Always keep your advice concise, practical, and highly relevant. Keep responses within 2-3 short paragraphs maximum.
""";

      _model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        systemInstruction: Content.system(systemInstruction),
      );

      final response = await _model!.generateContent([Content.text(userQuery)]);
      return response.text ?? "No advice generated.";
    } catch (e) {
      return "Error generating AI advice: $e";
    }
  }
}

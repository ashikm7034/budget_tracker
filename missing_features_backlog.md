# MoneyMate AI - Missing Features Backlog

This document tracks the features from the original vision and development roadmap that are currently missing, mock-stubbed, or partially implemented. Use this as a checklist for future development sprints.

---

## 🚀 High Priority

### 1. Gemini AI Core Integration (STEP 12)
* **Goal**: Replace the client-side rules-based parser with real Gemini LLM intelligence.
* **Implementation Plan**:
  * Add the `google_generative_ai` package to `pubspec.yaml`.
  * Set up secure API key configuration (e.g., using `flutter_dotenv` or passing via Dart environment variables).
  * Build a centralized `GeminiService` class to initialize the model (`gemini-1.5-flash`).
  * Implement context building prompts that feed the user's recent transactions (Expenses, Income, Goals, Debts) to Gemini.
* **Files to Modify/Create**:
  * [NEW] `lib/core/gemini_service.dart`
  * [MODIFY] `pubspec.yaml`
  * [MODIFY] `lib/features/coach/ai_coach_screen.dart`

### 2. Live AI Coach Chat Integration (STEP 13)
* **Goal**: Connect the AI Chat UI to the real Gemini model to answer dynamic queries (e.g., *"How much did I spend on food this week?"*, *"Can I afford ₹250 headphones?"*).
* **Implementation Plan**:
  * Pass the loaded `_dashboardData` as system instruction context to the generative model.
  * Wire up the user input field to send queries to the model and streams/replies back.
  * Add formatting for markdown tables and text options returned by the model.
* **Files to Modify**:
  * [MODIFY] `lib/features/coach/ai_coach_screen.dart`

---

## 📅 Medium Priority

### 3. User Settings Screen (STEP 10)
* **Goal**: Provide a profile dashboard to manage limits and configurations.
* **Implementation Plan**:
  * Create a Settings screen containing inputs for:
    * Monthly Income (updates the main budget database).
    * Daily budget limit.
    * Emergency mode threshold.
  * Save updates locally using `SharedPreferences` and sync them to the Google Sheet backend (`User Settings` tab).
* **Files to Create**:
  * [NEW] `lib/features/settings/settings_screen.dart`
  * [MODIFY] `lib/features/dashboard/navigation_shell.dart` (Add to navigation tabs or profile icon trigger)

### 4. Income Tracker Screen (STEP 6) [COMPLETED]
* **Goal**: Build a dedicated interface to log money additions.
* **Implementation Plan**:
  * Build a list view showing history of income. [COMPLETED]
  * Create an "Add Income" transaction dialog with fields: [COMPLETED]
    * Amount.
    * Source (Salary, Pocket Money, Gift, Other).
    * Note and Date.
  * Connect submitting actions to `ApiService.request('syncData', ...)` inside the `income` table. [COMPLETED]
* **Files Created**:
  * `lib/features/income/income_tracker_screen.dart`
  * `lib/features/income/add_income_screen.dart`

### 5. Offline Persistent Database Cache & Sync (STEP 11)
* **Goal**: Prevent data loss when running the app offline or restarting.
* **Implementation Plan**:
  * Integrate a lightweight local database like Hive, Isar, or SQLite.
  * Intercept all `ApiService` sync requests to store data locally first.
  * Set up a sync queue that triggers whenever connectivity is restored, sending local queue mutations to the Apps Script endpoint.
* **Files to Modify/Create**:
  * [NEW] `lib/core/local_db.dart`
  * [MODIFY] `lib/core/api_service.dart`

---

## 🎨 Low Priority / Enhancements

### 6. Spending Prediction & Forecasting (STEP 17)
* **Goal**: AI-driven monthly forecasting.
* **Implementation Plan**:
  * Feed past monthly expenses to Gemini and ask it to project the final balance at the end of the current month.
  * Calculate estimated completion dates for active savings goals.
* **Files to Modify/Create**:
  * [NEW] `lib/features/reports/predictions_tab.dart`

### 7. Emergency Low-Balance Mode (STEP 18)
* **Goal**: Automated alerts for thin cash reserves.
* **Implementation Plan**:
  * Monitor active balance against the emergency threshold set in User Settings.
  * Display alert banners on the dashboard with AI recommendations on saving and paused goals.
* **Files to Modify**:
  * [MODIFY] `lib/features/dashboard/dashboard_screen.dart`

### 8. Gemini Voice Assistant (STEP 23)
* **Goal**: Add hands-free transaction logging.
* **Implementation Plan**:
  * Capture audio streams using `speech_to_text`.
  * Pass the raw transcript to Gemini with a parsing prompt: *"Extract category, amount, and note from this text: 'spent 50 rupees on snacks'"*.
  * Automatically log the parsed expense to the tracker database.
* **Files to Modify**:
  * [MODIFY] `lib/features/coach/ai_coach_screen.dart`

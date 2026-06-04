class AppConfig {
  // Replace this with your deployed Google Apps Script Web App URL
  static const String backendUrl = "";

  static bool get isConfigured =>
      backendUrl.isNotEmpty &&
      backendUrl.startsWith("https://script.google.com");
}

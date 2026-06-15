class ApiConstants {
  ApiConstants._();

  // Replace with your API base URL in production or via --dart-define.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tightwad-fried-starfish.ngrok-free.dev',
  );
}

class ApiConstants {
  ApiConstants._();

  // Default is a personal ngrok tunnel used for local demos — it changes
  // whenever the tunnel restarts. Override per environment, e.g.:
  //   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
  // See service_matchmaking_mobile/README.md > Configuration.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tightwad-fried-starfish.ngrok-free.dev',
  );
}

/// Centralized configuration for the Aura app.
///
/// Change [baseUrl] to match your backend server address:
/// - Android emulator: 'http://10.0.2.2:8000'
/// - iOS simulator:    'http://localhost:8000'
/// - Physical device:  'http://YOUR_LOCAL_IP:8000'
class AppConfig {
  // Active backend server address (Live Ngrok tunnel for physical device & emulator)
  static const String baseUrl = 'https://staining-slashing-tinfoil.ngrok-free.dev';

  static Map<String, String> get headers => {
    'Bypass-Tunnel-Reminder': 'true',
    'ngrok-skip-browser-warning': 'true',
    'User-Agent': 'AuraApp/1.0',
  };

  static Map<String, String> get jsonHeaders => {
    'Bypass-Tunnel-Reminder': 'true',
    'ngrok-skip-browser-warning': 'true',
    'Content-Type': 'application/json',
    'User-Agent': 'AuraApp/1.0',
  };
}

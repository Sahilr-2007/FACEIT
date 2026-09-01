/// Centralized configuration for the Aura app.
///
/// Change [baseUrl] to match your backend server address:
/// - Android emulator: 'http://10.0.2.2:8000'
/// - iOS simulator:    'http://localhost:8000'
/// - Physical device:  'http://YOUR_LOCAL_IP:8000'
class AppConfig {
  // --- Active Ngrok Cloud Tunnel (Works globally on Cellular Data & ANY Wi-Fi Network) ---
  static const String baseUrl = 'https://staining-slashing-tinfoil.ngrok-free.dev';

  // --- Presets for local testing environments ---
  // Local Server:            'http://10.0.2.2:8000'
  // iOS Simulator:          'http://localhost:8000'
}

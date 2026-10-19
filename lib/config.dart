// Where the Roomly backend lives.
//
// Android emulator:  http://10.0.2.2:8000  (the default below; 10.0.2.2 means "this computer")
// Real phone:        http://YOUR-COMPUTER-IP:8000  (phone and computer on the same Wi-Fi)
// Change it without editing code:  flutter run --dart-define=API_BASE=http://192.168.1.5:8000
const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://10.0.2.2:8000');

// Photos are saved with the address the backend knows itself by (often localhost).
// Swap that for the address this phone can actually reach.
String fixUrl(String url) {
  final u = Uri.tryParse(url);
  final b = Uri.parse(apiBase);
  if (u == null || !u.hasAuthority) return url;
  return u.replace(scheme: b.scheme, host: b.host, port: b.port).toString();
}

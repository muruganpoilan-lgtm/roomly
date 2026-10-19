# Roomly app (Flutter)

The guest app for Roomly: search, property page with photos and rooms, reserve with the 10-minute hold,
and My bookings. It talks to the same backend as the website, so the backend in `../roomly/backend` must be running.

## One-time setup (Windows PowerShell)

1. Install Flutter: https://docs.flutter.dev/get-started/install (Flutter 3.24 or newer) and run `flutter doctor`.
2. Make a project shell, then copy this app's files over it:
   ```powershell
   flutter create roomly_app
   Copy-Item -Recurse -Force .\lib\* .\roomly_app\lib\
   Copy-Item -Force .\pubspec.yaml .\roomly_app\pubspec.yaml
   cd roomly_app
   flutter pub get
   ```
   (Run the first three lines from the folder that holds this README.)
3. Allow plain-http connections to your computer while developing. In
   `roomly_app\android\app\src\main\AndroidManifest.xml`, change the `<application` line to
   `<application android:usesCleartextTraffic="true"` and add, just above `<application`:
   `<uses-permission android:name="android.permission.INTERNET"/>`

## Run it
Start the backend first (`uvicorn app.main:app --reload --host 0.0.0.0`), then:
```powershell
flutter run                                              # Android emulator (uses http://10.0.2.2:8000)
flutter run --dart-define=API_BASE=http://192.168.1.5:8000   # real phone: your computer's Wi-Fi address
```
`--host 0.0.0.0` lets a real phone reach the backend. Allow Python through Windows Firewall if asked.

## What is in it
- Home: search slip (city, dates, guests) and the hills-to-sea city list
- Results: type chips, sort by price or rating
- Property: photo pager, amenities, rooms, change dates, Reserve (asks for login first)
- Bookings: 10-minute hold countdown, test confirm, release, cancel
- Account: log in, sign up, log out

Paying: when the backend has Razorpay keys, a held booking shows **Pay ₹...** and opens Razorpay's payment sheet
(uses the `razorpay_flutter` package, which `flutter pub get` fetches). Without keys it shows the test confirm button.
Refunds on cancellation follow the rule in the website README.

Owner and admin tools (adding properties, rooms, photos, dates) stay on the website.

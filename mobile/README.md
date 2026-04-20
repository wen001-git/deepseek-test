# shortvideoai mobile app

## Development

Install dependencies:

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
flutter pub get
```

Run static analysis:

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
flutter analyze
```

## Backend URL configuration

The app uses `--dart-define` for the backend base URL.

Production default:

- `https://video-creation-0fjy.onrender.com`

Examples:

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
```

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://video-creation-0fjy.onrender.com
```

## Android release signing

Release builds require a real upload keystore.

1. Generate a keystore:

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile/android
keytool -genkey -v -keystore app/keystore.jks \
  -alias upload \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

2. Create `android/key.properties` from the template:

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
cp android/key.properties.template android/key.properties
```

3. Fill in:

- `storeFile`
- `storePassword`
- `keyAlias`
- `keyPassword`

If `android/key.properties` is missing, `flutter build appbundle --release` now fails by design.

## Release build

Build a signed Android App Bundle:

```bash
cd /Users/Zhuanz/Claude/deepseek-test/mobile
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://video-creation-0fjy.onrender.com
```

Expected output:

- `build/app/outputs/bundle/release/app-release.aab`

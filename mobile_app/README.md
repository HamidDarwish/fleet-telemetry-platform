# mobile_app (Flutter)

اپ فقط فرانت‌اند است: دیتا را از بک‌اند می‌گیرد، با WebSocket زنده به‌روز می‌شود و هیچ قانون کاری ندارد.

## راه‌اندازی

این پوشه فقط `lib/` و `pubspec.yaml` را دارد. پوشهٔ `android/` را Flutter می‌سازد:

```
cd mobile_app
flutter create . --project-name fleet_app --platforms android
flutter pub get
```

> اگر `flutter create` فایل `lib/main.dart` را با نمونهٔ خودش عوض کرد، همین پروژه را دوباره کاپی کن.

### 1) آدرس بک‌اند

فایل `lib/config.dart`:

| کجا اجرا می‌شود | مقدار `host` |
|---|---|
| Android Emulator | `10.0.2.2:8080` (پیش‌فرض) |
| موبایل واقعی | `192.168.x.x:8080` (IP کمپیوتر؛ هر دو در یک Wi‑Fi) |

### 2) مانیفست اندروید

فایل `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>

    <application
        android:usesCleartextTraffic="true"
        ... >
```

یعنی: خط `uses-permission` را بالای `<application>` اضافه کن و `android:usesCleartextTraffic="true"` را داخل تگ `<application>` بگذار (برای HTTP لوکال لازم است).

### 3) اجرا

```
flutter run
```

## صفحه‌ها به تفکیک نقش

| نقش | تب‌ها |
|---|---|
| ADMIN | Dashboard, Map, Vehicles, Alerts, Admin (کنترل شبیه‌ساز) |
| MANAGER | Dashboard, Map, Vehicles, Alerts, Work orders |
| TECHNICIAN | Work orders, Alerts |
| DRIVER | Map, Vehicles, Alerts (فقط موتر خودش) |

## ساختار

```
lib/
  config.dart              آدرس بک‌اند
  main.dart                شروع برنامه، تصمیم بین ورود و صفحهٔ اصلی
  models/models.dart       مدل‌ها
  services/                REST (api_service) و WebSocket (live_service)
  providers/app_state.dart حالت برنامه و دیتای زنده
  screens/                 صفحه‌ها
  widgets/common.dart      رنگ‌ها و ویجت‌های مشترک
```

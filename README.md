# پلتفرم تلمتری ناوگان و نگهداری پیشگیرانه

**Connected Fleet Telemetry and Preventive Maintenance Platform**

یک سیستم نظارت بر موترها با **اپ موبایل Flutter** (فرانت‌اند) و **Spring Boot** (بک‌اند). چون موتر یا دستگاه واقعی در دسترس نیست، دیتای تلمتری از یک **شبیه‌ساز داخلی** می‌آید. همه‌چیز لوکال اجرا می‌شود.

مشخصات کامل در پوشهٔ `docs/` است (SRS نسخهٔ 2.0، انگلیسی و دری).

## ساختار پوشه‌ها

| پوشه | بخش | تکنالوژی | وظیفه |
|---|---|---|---|
| `docs/` | سند‌ها | Word | SRS نسخهٔ 2.0 به دو زبان (`..._EN.docx` و `..._FA.docx`) |
| `database/` | دیتابیس (اختیاری) | PostgreSQL 16 + Docker Compose | فقط اگر PostgreSQL می‌خواهی. به‌صورت پیش‌فرض بک‌اند از H2 داخلی استفاده می‌کند و به این پوشه نیازی نیست |
| `backend/` | بک‌اند | Java 17, Spring Boot 3.3 | REST API، WebSocket، JWT و نقش‌ها، قوانین کاری |
| `backend/src/main/java/com/fleet/simulator/` | شبیه‌ساز | Spring (بخشی از بک‌اند) | موترهای مجازی روی مسیرها؛ دیتا را از همان `TelemetryService` عبور می‌دهد که دستگاه واقعی می‌دهد |
| `mobile_app/` | فرانت‌اند | Flutter (Android) | همهٔ صفحه‌ها؛ هیچ قانون کاری ندارد |

### داخل `backend/src/main/java/com/fleet/`

| پوشه | محتوا |
|---|---|
| `model/` | Entityها و Enumها (User, Vehicle, TelemetryRecord, Alert, MaintenanceRule, WorkOrder, Geofence) |
| `repository/` | Spring Data JPA |
| `dto/` | همهٔ درخواست‌ها و پاسخ‌های API در `Dtos.java` |
| `security/` | `JwtService` و `JwtAuthFilter` |
| `config/` | امنیت، WebSocket، مدیریت خطا، داده‌های اولیهٔ دمو |
| `service/` | منطق کاری: دریافت تلمتری، هشدار، نگهداری پیشگیرانه، فرمان کار، geofence، داشبورد |
| `simulator/` | `SimulatorService` و `Routes` (مسیرهای نمونه در کابل) |
| `controller/` | endpointهای REST |
| `util/` | محاسبهٔ فاصله و جهت (`GeoUtils`) |

### داخل `mobile_app/lib/`

| پوشه | محتوا |
|---|---|
| `config.dart` | **تنها جای آدرس بک‌اند** |
| `models/` | مدل‌های دیتا |
| `services/` | `api_service.dart` (REST) و `live_service.dart` (WebSocket) |
| `providers/` | `app_state.dart` (حالت برنامه، دیتای زنده) |
| `screens/` | ورود، داشبورد، نقشه، موترها، هشدارها، فرمان‌های کار، ادمین |
| `widgets/` | ویجت‌ها و رنگ‌های مشترک |

## پیش‌نیازها

- JDK 17 یا بالاتر و Maven 3.9+
- Docker Desktop (**اختیاری**، فقط برای PostgreSQL؛ بدون آن بک‌اند با H2 کار می‌کند)
- Flutter SDK 3.22+ و یک Android Emulator یا موبایل واقعی

## ترتیب اجرا

**1) دیتابیس** (دو راه؛ یکی را انتخاب کن)

- **بدون Docker و بدون نصب (پیش‌فرض):** کاری لازم نیست. در `application.properties` خط `spring.profiles.active=h2` فعال است و بک‌اند دیتابیس H2 را در فایل `backend/data/fleetdb.mv.db` می‌سازد. دیتا بعد از خاموش کردن می‌ماند. برای شروع از صفر، بک‌اند را متوقف کن و پوشهٔ `backend/data` را پاک کن.
- **PostgreSQL:** خط `spring.profiles.active=h2` را پاک کن و دیتابیس را با Docker بالا بیاور:
  ```
  cd database
  docker compose up -d
  ```
  یا PostgreSQL را خودت نصب کن و دیتابیس `fleetdb` با کاربر `fleet` و رمز `fleet123` بساز.

**2) بک‌اند** (پورت 8080)
```
cd backend
mvn spring-boot:run
```
بار اول، Hibernate جدول‌ها را می‌سازد و `DataInitializer` کاربران، 6 موتر، قوانین نگهداری و یک geofence نمونه را می‌ریزد. شبیه‌ساز خودکار شروع می‌شود (`fleet.simulator.auto-start=true`).

**3) اپ موبایل**: مراحل در `mobile_app/README.md`.

## حساب‌های دمو

| نقش | ایمیل | رمز |
|---|---|---|
| مدیر سیستم | admin@fleet.local | admin123 |
| مدیر ناوگان | manager@fleet.local | manager123 |
| تخنیکر | tech@fleet.local | tech123 |
| راننده (موتر KBL-1001) | driver@fleet.local | driver123 |

## چی در دمو دیده می‌شود

- موتر `KBL-1001` تقریباً به سرویس تبدیل تیل می‌رسد (4990 از 5000 کیلومتر)؛ بعد از چند دقیقه هشدار «due» و یک فرمان کار خودکار می‌سازد.
- با احتمال 1٪ در هر پیام، شبیه‌ساز خطا تزریق می‌کند: داغ شدن انجن، سرعت زیاد، کم بودن سوخت، کد خطای `P0217`.
- مسیر شمال‌شرقی کمی از geofence نمونه بیرون می‌رود و هشدار ورود/خروج می‌سازد.
- اگر شبیه‌ساز را متوقف کنی، بعد از 60 ثانیه موترها «آفلاین» می‌شوند.
- برای دیدن تغییر سریع‌تر: `fleet.simulator.speed-multiplier` و `fleet.simulator.fault-probability` در `backend/src/main/resources/application.properties`.

## تست سریع API (بدون اپ)

```
# ورود و گرفتن توکن
curl -X POST http://localhost:8080/api/auth/login -H "Content-Type: application/json" \
     -d '{"email":"admin@fleet.local","password":"admin123"}'

# لیست موترها (توکن را جایگزین کن)
curl http://localhost:8080/api/vehicles -H "Authorization: Bearer TOKEN"

# وضعیت و کنترل شبیه‌ساز
curl http://localhost:8080/api/simulator/status -H "Authorization: Bearer TOKEN"
curl -X POST http://localhost:8080/api/simulator/stop -H "Authorization: Bearer TOKEN"
```

## وضعیت پیاده‌سازی

**پیاده شده**
- ورود با JWT و کنترل دسترسی بر اساس نقش (جدول ضمیمهٔ C در SRS)
- مدیریت موتر و راننده (API)، دریافت تلمتری تکی و دسته‌ای، پاک شدن خودکار دیتای قدیمی
- شبیه‌ساز با مسیر، خطای تزریقی و کنترل شروع/توقف
- نقشهٔ زنده با WebSocket، داشبورد، تشخیص آفلاین
- هشدارها با سرکوب تکرار (cooldown)، تایید و فلتر
- قوانین نگهداری مبتنی بر مسافت و زمان، هشدار 90٪، فرمان کار خودکار و شروع دوبارهٔ قانون بعد از تکمیل
- فرمان کار با روند وضعیت، تعیین تخنیکر، یادداشت، قطعات و هزینه
- geofence دایره‌ای و هشدار ورود/خروج (API)
- گزارش خلاصهٔ مسافت و هزینه (API)

**هنوز نیست** (در SRS هست، برای مرحلهٔ بعد)
- خروجی PDF و Excel گزارش‌ها
- اعلان اندروید خارج از اپ (`flutter_local_notifications`)؛ فعلاً اعلان داخل اپ (SnackBar) است
- صفحه‌های اپ برای ساختن موتر/کاربر/قانون/geofence و نمایش مسیر طی‌شده (endpointها در بک‌اند آماده‌اند)
- قانون نگهداری از نوع «آستانهٔ سنسور» به‌صورت قابل ویرایش؛ آستانه‌ها فعلاً در `application.properties` هستند
- احراز هویت کانال WebSocket (فعلاً باز است؛ فقط برای توسعهٔ لوکال)
- تست‌های خودکار

## نکتهٔ مهم دربارهٔ تایید کد

کود در محیط ساخت این پروژه **کامپایل و اجرا نشده** (Maven، Flutter و انترنت Maven Central در دسترس نبود). فقط بررسی ساختاری (syntax) فایل‌های Java انجام شد. بار اول که اجرا می‌کنی، ممکن است چند خطای کوچک (نسخهٔ پکیج، import) ظاهر شود؛ متن خطا را بفرست تا درست شود.

## مشکلات رایج

| مشکل | علت و راه‌حل |
|---|---|
| بک‌اند بالا نمی‌آید: `Connection refused` | پروفایل h2 فعال نیست و PostgreSQL هم روشن نیست. `spring.profiles.active=h2` را در `application.properties` بگذار |
| اپ می‌گوید «Cannot reach the server» | آدرس در `mobile_app/lib/config.dart` اشتباه است، یا مانیفست اندروید `INTERNET` / `usesCleartextTraffic` ندارد |
| موبایل واقعی وصل نمی‌شود | کمپیوتر و موبایل باید در یک Wi‑Fi باشند؛ پورت 8080 را در Firewall باز کن |
| اپ لاگین می‌شود ولی نقشه خالی است | شبیه‌ساز خاموش است (تب Admin) یا هنوز پیام نفرستاده (چند ثانیه صبر کن) |

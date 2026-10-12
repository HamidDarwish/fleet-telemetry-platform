# backend (Spring Boot)

```
mvn spring-boot:run          # اجرا روی http://localhost:8080
mvn -DskipTests package      # ساختن jar در target/
```

دیتابیس پیش‌فرض H2 است (فایل `data/fleetdb.mv.db`، بدون نصب). برای PostgreSQL خط `spring.profiles.active=h2` را از `application.properties` پاک کن.

تنظیمات همه در `src/main/resources/application.properties` است: دیتابیس، JWT، شبیه‌ساز، آستانهٔ هشدارها، مدت نگهداری دیتا.

## endpointهای اصلی

| مسیر | هدف | نقش‌ها |
|---|---|---|
| `POST /api/auth/login` | ورود | عمومی |
| `GET/POST/PUT /api/users` | کاربران | ADMIN |
| `GET/POST/PUT /api/vehicles`, `GET /api/vehicles/{id}/telemetry?minutes=30` | موترها و تاریخچه | همه (راننده فقط موتر خودش)؛ نوشتن: ADMIN, MANAGER |
| `POST /api/telemetry`, `/api/telemetry/batch` | دریافت تلمتری | ADMIN |
| `GET /api/alerts`, `PUT /api/alerts/{id}/ack` | هشدارها | همه (فلتر بر اساس نقش) |
| `GET/POST/PUT /api/maintenance-rules` | قوانین نگهداری | خواندن: ADMIN, MANAGER؛ نوشتن: MANAGER |
| `GET/POST/PUT /api/work-orders`, `GET /api/work-orders/technicians` | فرمان‌های کار | MANAGER, TECHNICIAN |
| `GET/POST/PUT/DELETE /api/geofences` | geofence | MANAGER |
| `GET /api/dashboard`, `GET /api/reports/summary?days=7` | داشبورد و گزارش | ADMIN, MANAGER |
| `POST /api/simulator/start`, `/stop`, `GET /status` | شبیه‌ساز | ADMIN |

**WebSocket (STOMP):** `ws://HOST:8080/ws` ← topicهای `/topic/telemetry` و `/topic/alerts`.

## شبیه‌ساز

کود در `src/main/java/com/fleet/simulator/`. شبیه‌ساز مستقیم `TelemetryService.ingest()` را صدا می‌زند، همان سرویسی که `POST /api/telemetry` هم استفاده می‌کند. به همین دلیل بعداً می‌شود آن را به برنامهٔ جدا (که به API پست می‌کند) یا دستگاه واقعی تبدیل کرد، بدون تغییر بقیهٔ سیستم.

# database (اختیاری)

این پوشه فقط وقتی لازم است که **PostgreSQL** می‌خواهی. به‌صورت پیش‌فرض بک‌اند از دیتابیس **H2** داخلی استفاده می‌کند (بدون نصب و بدون Docker).
برای استفاده از PostgreSQL، در `backend/src/main/resources/application.properties` خط `spring.profiles.active=h2` را پاک کن.

```
docker compose up -d     # شروع
docker compose down      # توقف (دیتا می‌ماند)
docker compose down -v   # توقف و پاک کردن کامل دیتا
```

| تنظیم | مقدار |
|---|---|
| دیتابیس | `fleetdb` |
| کاربر / رمز | `fleet` / `fleet123` |
| پورت | `5432` |

جدول‌ها را بک‌اند خودش می‌سازد (`spring.jpa.hibernate.ddl-auto=update`)؛ فایل SQL جداگانه لازم نیست.
اگر این مقدارها را عوض کردی، `backend/src/main/resources/application.properties` را هم عوض کن.

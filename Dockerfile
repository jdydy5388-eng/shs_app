# syntax=docker/dockerfile:1

FROM dart:stable AS runtime

WORKDIR /app

# نسخ ملفات الاعتمادات أولاً للاستفادة من كاش Docker
COPY server/pubspec.* ./
RUN dart pub get

# نسخ بقية ملفات الخادم
COPY server/ ./

# تأكد من تنزيل الاعتمادات مرة أخرى (للموديلات المحلّية)
RUN dart pub get --offline

# Render يحدد المنفذ من خلال متغير البيئة PORT
ENV PORT=8080
EXPOSE 8080

CMD ["dart", "run", "lib/main.dart"]


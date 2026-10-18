# 2214 · Jazit Hanoar

App Flutter (Android / iOS / web) para los javerim de Jazit. Backend: Firebase (Auth + Firestore). Fotos y videos: Cloudinary.

## Roles
Janij · Boguer · Madrij · Hanagá (solo asignable desde la base de datos).

## Actualización automática (Android, sin tiendas)
Al abrir la app compara su número de build con `version.json` de este repo. Si hay uno mayor, ofrece descargar `releases/2214.apk` e instalarlo (Android pide confirmación).

Para publicar una versión nueva:

    .\publicar.ps1 -Version 1.0.1 -Notas "Qué cambió"

Importante: el APK siempre se firma con la misma clave de esta PC. Si cambia, Android rechaza la actualización.

## Desarrollo
    flutter pub get
    flutter run -d chrome

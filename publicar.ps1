# Publica una nueva versión de la app para Android (actualización automática).
# Uso:  .\publicar.ps1 -Version 1.0.1 -Notas "Qué cambió"
param(
  [Parameter(Mandatory)][string]$Version,
  [string]$Notas = "",
  [switch]$Obligatoria
)
$ErrorActionPreference = 'Stop'
$env:PUB_CACHE = 'D:\dev\pub-cache'; $env:GRADLE_USER_HOME = 'D:\dev\gradle'

# 1) build number = el actual + 1
$m = Get-Content version.json -Raw | ConvertFrom-Json
$build = [int]$m.build + 1

# 2) actualizar pubspec y compilar
(Get-Content pubspec.yaml) -replace '^version: .*', "version: $Version+$build" | Set-Content pubspec.yaml
flutter build apk --release
Copy-Item build\app\outputs\flutter-apk\app-release.apk releases\2214.apk -Force

# 3) actualizar version.json y subir
@{ version = $Version; build = $build; apk = $m.apk; notas = $Notas; obligatoria = [bool]$Obligatoria } |
  ConvertTo-Json | Set-Content version.json -Encoding utf8
git add -A
git commit -m "Versión $Version ($build)"
git push origin main
Write-Host "Listo: los celulares con la app van a ver la actualización al abrirla."

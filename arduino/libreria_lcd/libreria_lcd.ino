/* Ejemplo de sketch para el protocolo de la app (9600 baudios, una línea por mensaje).
   Hardware supuesto: Arduino Uno + LCD 16x2 con módulo I2C (0x27) + zumbador en pin 8.
   Librería: "LiquidCrystal I2C". AJUSTA dirección/pines a tu montaje.

   La app manda SIEMPRE una linea  arriba|abajo  (fila 1 | fila 2 de la pantalla):
     Cuentos de la se|18.50     TOTAL|40.00     GRACIAS|40.00     NO ENCONTRADO|
   Si la fila de abajo es un numero se le antepone "$".
   El Arduino responde: READY (al arrancar), OK (por cada línea), ERR:LCD (si no hay pantalla) */
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

const uint8_t LCD_ADDR = 0x27;
const uint8_t PIN_BUZZER = 8;
LiquidCrystal_I2C lcd(LCD_ADDR, 16, 2);
bool lcdOk = false;
String linea;

void mostrar(const String &a, const String &b) {
  if (!lcdOk) return;
  lcd.clear();
  lcd.setCursor(0, 0); lcd.print(a.substring(0, 16));
  lcd.setCursor(0, 1); lcd.print(b.substring(0, 16));
}

// Devuelve el campo n (0 = comando) de una línea separada por '|'
String campo(const String &s, int n) {
  int ini = 0;
  for (int i = 0; i < n; i++) { ini = s.indexOf('|', ini); if (ini < 0) return ""; ini++; }
  int fin = s.indexOf('|', ini);
  return fin < 0 ? s.substring(ini) : s.substring(ini, fin);
}

bool esNumero(const String &s) {
  if (s.length() == 0) return false;
  for (unsigned i = 0; i < s.length(); i++)
    if (!isDigit(s[i]) && s[i] != '.') return false;
  return true;
}

void procesar(const String &s) {
  String arriba = campo(s, 0);
  String abajo = campo(s, 1);
  if (esNumero(abajo)) abajo = "$" + abajo;
  mostrar(arriba, abajo);
  tone(PIN_BUZZER, arriba == "GRACIAS" ? 1500 : 2000, 80);
  Serial.println(lcdOk ? "OK" : "ERR:LCD");
}

void setup() {
  Serial.begin(9600);
  pinMode(PIN_BUZZER, OUTPUT);
  Wire.begin();
  Wire.beginTransmission(LCD_ADDR);
  lcdOk = (Wire.endTransmission() == 0);
  if (lcdOk) { lcd.init(); lcd.backlight(); mostrar("Libreria", "Lista"); }
  Serial.println("READY");
  if (!lcdOk) Serial.println("ERR:LCD");
}

void loop() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == '\n') { linea.trim(); if (linea.length()) procesar(linea); linea = ""; }
    else if (linea.length() < 80) linea += c;
  }
}

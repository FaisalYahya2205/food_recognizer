# NutriSnap

Aplikasi Flutter untuk klasifikasi makanan on-device dengan LiteRT (TensorFlow Lite), live camera, Gemini AI nutrition, dan referensi resep TheMealDB.

## Identitas

- **Package:** `nutrisnap_app`
- **Bundle ID:** `com.dicoding.nutrisnap`
- **Nama app:** NutriSnap

## Menjalankan

```bash
flutter pub get
flutter run
```

## Fitur

- Live camera stream + klasifikasi makanan
- Upload foto dari kamera / galeri dengan crop
- Detail prediksi + nutrisi (Gemini) + resep (TheMealDB)
- Model ML: bundled asset dengan fallback Firebase Storage / Firebase ML

## Konfigurasi opsional

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

# Colpad Savings ⚡

Pencatat tabungan pribadi offline-first untuk Android, dibuat dengan Flutter.

## MVP saat ini
- Dashboard saldo aset, kas, alokasi, uang masuk, dan uang keluar.
- Penyimpanan transaksi lokal menggunakan SQLite melalui Drift.
- Pencatatan uang masuk, pengeluaran, setoran, dan penarikan tabungan.
- Validasi saldo kas/alokasi dan operasi tulis transaksional.
- Riwayat 100 transaksi terbaru dengan pencarian.
- Grafik aset dari transaksi aktual, privasi saldo, tema terang/gelap.
- Tampilan dan format tanggal/mata uang Indonesia.

Target tabungan, planner, tantangan, backup, notifikasi, dan statistik lanjutan belum tersedia pada MVP ini.

## Build APK
1. Open **Actions**.
2. Select **Build Android APK**.
3. Click **Run workflow** or push a commit to `main`.
4. After a successful run, download `colpad-android-apk` from Artifacts.

Workflow menghasilkan platform Android dan APK dengan Flutter stable pada GitHub-hosted runner. Android SDK lokal tidak diperlukan.

## Pengembangan lokal
Lingkungan memerlukan Flutter stable dengan Dart SDK `>=3.6.0 <4.0.0`.

```sh
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --release
```

## Compatibility and release notes
- Target SDK 36 is configured for Android 16-era compatibility.
- Minimum SDK 24 means Android 7.0 or newer, subject to device compatibility.
- Test the APK on real devices before distribution.
- Configure and protect a release signing key before publishing to an app store.

Crafted by Colpad ⚡

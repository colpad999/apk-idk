# Colpad Savings ⚡

Pencatat tabungan pribadi offline-first untuk Android, dibuat dengan Flutter.

## Fitur
- Design system Neo-Brutalism dengan tema terang/gelap, komponen outline tebal, dan bayangan keras.
- Dashboard saldo kas/alokasi, pemasukan, pengeluaran, aksi cepat, target prioritas, grafik mingguan, dan sumber pemasukan.
- Transaksi lokal melalui Drift/SQLite: pemasukan, pengeluaran, setoran, dan penarikan; nominal memakai integer Rupiah.
- Anggaran bulanan per kategori yang dihitung dari pengeluaran aktual tanpa mengurangi saldo lagi.
- Target tabungan dan riwayat alokasi yang terhubung secara atomik dengan transaksi.
- Simulasi tabungan harian, mingguan, atau bulanan dengan skenario Hemat, Normal, dan Agresif.
- Navigasi Home, Budget, Goals, Activity, dan More; pencarian riwayat, penyamaran saldo, dan format Indonesia.
- Migrasi database versi 1 ke versi 3 mempertahankan transaksi lama.

Kalender keuangan, biaya berulang, jurnal, tantangan, celengan, achievement, wishlist, pengingat, backup/restore, dan ekspor CSV belum tersedia.

## Build APK
1. Open **Actions**.
2. Select **Build Android APK**.
3. Click **Run workflow** or push a commit to `main`.
4. After a successful run, download `colpad-android-apk` from Artifacts.

Workflow menghasilkan platform Android dan APK dengan Flutter stable pada GitHub-hosted runner. Android SDK lokal tidak diperlukan.

## Pengembangan dan build lokal
Lingkungan memerlukan Flutter stable dengan Dart SDK `>=3.6.0 <4.0.0`. Repository menyimpan source dan workflow membuat wrapper Android sementara; karena itu build release yang direkomendasikan adalah melalui GitHub Actions.

```sh
flutter pub get
dart format .
flutter analyze
flutter test
```

## Compatibility and release notes
- Target SDK 36 is configured for Android 16-era compatibility.
- Minimum SDK 24 means Android 7.0 or newer, subject to device compatibility.
- Test the APK on real devices before distribution.
- Configure and protect a release signing key before publishing to an app store.

Crafted by Colpad ⚡

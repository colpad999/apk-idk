# Colpad Savings ⚡

Aplikasi Android offline-first untuk mencatat keuangan dan kebiasaan, dibangun dengan Flutter. UI menggunakan Neo-Brutalism terang dengan pilihan Neo Green, Neo Blue, Neo Orange, dan Neo Purple di menu More. Ini belum merupakan Life Tracker lengkap.

## Fitur yang tersedia

- Dashboard saldo, pemasukan, pengeluaran, alokasi tujuan, aktivitas dan statistik keuangan; pencarian pusat fitur.
- Transaksi pemasukan/pengeluaran dan setoran/penarikan tujuan, pilihan tanggal dan konfirmasi; anggaran berdasarkan pengeluaran aktual.
- Tujuan tabungan dengan foto tersimpan lokal, riwayat alokasi, dan simulasi tabungan.
- Habit dengan jadwal harian, hari tertentu atau target mingguan, jeda, riwayat kalender per habit, streak dan beberapa pengingat notifikasi biasa.
- Check-in habit berkali-kali dengan waktu, catatan, edit dan hapus. Check-in terpisah dari status selesai.
- Counter habit opsional dengan target bulat dan satuan, progres harian, penyesuaian dan riwayat; target yang tercapai diperhitungkan dalam streak. Check-in tetap terpisah.
- Virtual Money Jar memakai alokasi tujuan yang sama, bukan saldo tambahan.
- Kalender keuangan berdasarkan seluruh transaksi tiap bulan dan Money Journal lokal untuk catatan.
- Saving Challenge menggunakan alokasi bersih tujuan selama periode challenge tanpa membuat saldo baru.
- Pengaturan suara Android dan pengingat per habit.
- Wishlist lokal dengan harga perkiraan, catatan dan status terbeli; tidak mengubah saldo. Foto wishlist dipilih melalui pemilih sistem dan disimpan sebagai salinan JPEG terkompresi.
- Kalender aktivitas bulanan untuk habit terjadwal, jurnal dan mood dengan ringkasan mingguan/bulanan.
- Pencapaian habit berbasis riwayat dan ringkasan mood mingguan/bulanan (bukan diagnosis).
- Jurnal harian dan mood lokal dengan riwayat, edit dan hapus; bukan diagnosis.
- Backup/restore JSON tervalidasi termasuk foto tujuan yang tersedia, dan ekspor CSV transaksi (CSV bukan backup penuh).

**Alarm habit (Android):** aktifkan mode alarm di Suara & Pengingat. Notifikasi menyediakan MATIKAN dan SNOOZE 10 menit. Perilaku perangkat dan pembatasan Android belum diuji; lihat [status alarm](docs/alarm-status.md).

## Teknologi dan struktur

Flutter/Dart, Riverpod, Drift/SQLite, flutter_local_notifications, timezone, image picker dan file picker. `lib/data` berisi database dan repository; `lib/domain` logika statistik; `lib/services` backup, foto dan notifikasi; `lib/features` halaman; `lib/app` konfigurasi aplikasi dan provider; `test` pengujian; `android` konfigurasi native.

## Menjalankan dan membangun

Instal Flutter stable (CI menggunakan 3.47.9), Android SDK, dan JDK 17. Dengan perangkat atau emulator yang sudah terhubung:

```sh
flutter pub get
flutter run
# validasi
dart format .
flutter analyze
flutter test
```

Untuk build release lokal, pastikan Gradle wrapper tersedia (`flutter create` dapat membuat wrapper di direktori sementara; salin `gradlew`, `gradlew.bat`, dan `gradle-wrapper.jar` ke `android/` tanpa menimpa konfigurasi proyek), lalu jalankan `flutter build apk --release`. Alternatif: jalankan workflow **Build Android APK** di GitHub Actions dan unduh artefak `colpad-android-apk`. Build saat ini menggunakan debug signing; konfigurasikan kunci release sendiri sebelum distribusi.

## Backup dan privasi

Backup mencakup transaksi, anggaran, tujuan, habit, check-in, counter, wishlist, challenge, money journal, penyelesaian, jadwal pengingat, jeda, jurnal, mood, pengaturan, serta foto tujuan dan wishlist yang tersedia. Foto yang hilang dilaporkan. File divalidasi dan dibatasi 50 MB. Restore hanya diperbolehkan ke database kosong dan dijalankan dalam transaksi; jangan menghapus data aktif untuk melakukan restore tanpa memastikan backup aman. Backup JSON tidak terenkripsi: simpan secara pribadi. CSV hanya berisi ledger, bukan semua data.

## Izin dan batas Android

Minimum Android 7 (SDK 24), target SDK 36. `POST_NOTIFICATIONS` diperlukan untuk notifikasi pada Android 13+, dan `RECEIVE_BOOT_COMPLETED` untuk menjadwalkan ulang notifikasi setelah reboot. Pengingat bersifat inexact dan dapat ditunda oleh sistem; force-stop dan kebijakan perangkat dapat menghambatnya. Aplikasi tidak meminta izin exact alarm atau full-screen intent karena alarm manual-stop belum diimplementasikan. Foto dipilih melalui photo picker, tanpa izin penyimpanan luas. Uji pada perangkat nyata sebelum distribusi.

### Profil, impor, dan riwayat alarm
Profil lokal menyimpan nama dan catatan opsional dalam pengaturan dan termasuk backup. Import Data membuka pemulihan backup JSON Colpad yang tervalidasi, hanya pada database kosong; impor CSV belum didukung. Riwayat menampilkan 200 peristiwa terakhir dari mode alarm Android sejak fitur ini dipasang (bukan notifikasi biasa). Log tersimpan lokal terpisah, tidak ikut backup dan tidak membuktikan suara terdengar.

Pilihan tema di More → Pengaturan: Neo Green (hijau–kuning), Neo Blue (biru–oranye), Neo Orange (oranye–biru), dan Neo Purple (ungu–hijau). Setiap tema memakai dua warna cerah serta warna netral untuk teks dan latar.

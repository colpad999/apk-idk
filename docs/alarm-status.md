# Alarm habit Android

Mode alarm bersifat opt-in di Suara & Pengingat, memakai jadwal pengingat habit yang sudah ada. Saat terpicu, layanan foreground memainkan suara alarm sistem berulang dan/atau getaran sesuai pengaturan pengingat; notifikasi menyediakan **MATIKAN** dan **SNOOZE 10 MENIT**. Beberapa alarm bersamaan dihentikan/ditunda bersama. Mode dan jadwal native disimpan pada perangkat; mode tidak ikut backup, sehingga perlu diaktifkan lagi setelah restore.

Izin notifikasi diperlukan agar tombol terlihat. Izin alarm presisi opsional: tanpa izin, Android dapat menunda alarm. Jadwal dipulihkan saat reboot, pembaruan aplikasi, dan perubahan waktu/zona; habit dengan tanggal akhir tetap menggunakan jendela 90 hari yang diperpanjang saat aplikasi aktif. Android dapat membatasi foreground service, suara, DND, penghematan daya dan alarm latar belakang; force-stop dapat mencegah alarm sampai aplikasi dibuka lagi. Tidak ada bypass DND atau jaminan ketepatan. Bila sistem menolak foreground service, notifikasi tombol dapat muncul tanpa suara.

**Belum diuji pada perangkat/emulator:** verifikasi izin, audio berulang, MATIKAN, snooze, beberapa alarm, reboot, perubahan zona waktu, force-stop, mode senyap dan pembatasan baterai sebelum mengandalkannya.

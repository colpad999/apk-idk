# Status alarm manual-stop

Belum diimplementasikan. Pengingat habit saat ini adalah notifikasi lokal biasa,
bukan alarm yang terus berbunyi, dan tidak menyediakan layar alarm manual-stop.
Aplikasi tidak meminta izin exact alarm atau full-screen intent untuk habit.

Penyelesaian alarm memerlukan desain dan implementasi Android tersendiri:
penyimpanan jadwal/kejadian yang tahan proses mati, AlarmManager dengan izin
khusus bila tersedia, receiver yang idempoten, foreground service untuk audio
berulang dan getaran, audio focus, tindakan berhenti/snooze yang aman, serta
rekonsiliasi saat reboot, perubahan waktu dan zona waktu. Izin notifikasi,
foreground-service, exact alarm dan full-screen intent harus disesuaikan dengan
versi Android dan kebijakan distribusi; DND tidak boleh dilewati tanpa otorisasi.

Force-stop, perangkat OEM, penghematan baterai, izin, dan kebijakan OS dapat
mencegah atau menunda alarm. Tidak ada klaim bahwa alarm akan berbunyi tepat
waktu atau terus berbunyi pada semua perangkat. Pengujian nyata pada emulator
atau perangkat Android (termasuk audio, stop, snooze, reboot, force-stop, dan
perubahan zona waktu) adalah syarat sebelum fitur ini bisa dinyatakan selesai.

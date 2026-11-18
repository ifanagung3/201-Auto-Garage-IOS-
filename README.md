# 201 Auto Garage iOS

Aplikasi iOS native berbasis SwiftUI untuk 201 Auto Garage. Alur pelanggan mencakup masuk/pendaftaran akun dan pemulihan kata sandi, pemesanan servis, pemantauan status dan riwayat servis, pengelolaan profil/alamat/kendaraan, promo, pengaturan, bantuan, serta informasi aplikasi. Akun admin memiliki layar untuk mengelola booking, progres servis, estimasi biaya, pelanggan, promo, dan dasbor.

Tampilan iOS menggunakan palet warna dan logo yang sama dengan aplikasi Android, dengan tata letak serta kontrol yang disesuaikan agar tetap terasa natural di iPhone.

## Penyiapan Firebase

1. Tambahkan aplikasi iOS ke proyek Firebase yang sama dengan aplikasi Android. Gunakan bundle ID `com.autogarage.autogarage201`.
2. Unduh `GoogleService-Info.plist` untuk aplikasi tersebut dan tambahkan ke target `AutoGarage` di Xcode. Jangan masukkan kredensial ke commit jika kebijakan repositori menganggap berkas ini bersifat privat.
3. Di Build Settings target, ganti nilai placeholder `GOOGLE_REVERSED_CLIENT_ID` dengan nilai `REVERSED_CLIENT_ID` dari plist tersebut pada konfigurasi Debug dan Release. Nilai ini mengaktifkan skema URL callback Google Sign-In. Placeholder bawaan memungkinkan build lokal tanpa konfigurasi tetap dapat dipasang; Google Sign-In memerlukan nilai yang sebenarnya.
4. Aktifkan Email/Password dan Google di Firebase Authentication, lalu buat database Firestore.
5. Tetapkan `"role": "admin"` pada dokumen `users/{uid}` untuk akun admin yang berwenang. Pendaftaran baru menggunakan peran `"user"`.
6. Tinjau `firestore.rules` sesuai kebijakan deployment Anda, lalu deploy dengan Firebase CLI: `firebase deploy --only firestore:rules`. Rules mengizinkan pelanggan mengakses profil, kendaraan, alamat, dan booking miliknya sendiri; hanya admin yang dapat mengelola status booking, estimasi, dan promo. Tetapkan peran admin melalui proses tepercaya, misalnya Firebase Console.

Aplikasi ini menggunakan proyek Firebase dan koleksi Firestore yang sama dengan Android: profil di `users/{uid}`, kendaraan di koleksi root `vehicles` (dengan `userId`), alamat tersimpan di `users/{uid}/addresses`, booking di `bookings`, promo di `promos`, dan notifikasi per pengguna di `notifications`.

- Setelah mendaftar, pelanggan mengisi detail profil (nama, telepon, alamat) dan menambahkan kendaraan pertama sebelum masuk ke dasbor pelanggan. Data kendaraan dan perubahan `profileCompleted` disimpan bersama.
- Field profil pengguna mencakup `uid`, `name`, `email`, `phone`, `address`, `role`, dan `profileCompleted`.
- Dokumen kendaraan mencakup `userId`, `brand`, `model`, `platNumber`, `year`, dan `kilometer`.
- Dokumen alamat mencakup `label`, `fullAddress`, dan `createdAt`.
- Dokumen booking menggunakan skema Android: `userId`, `userName`, `userPhone`, `vehicleName`, `vehiclePlat`, `vehicleYear`, `vehicleKm`, `serviceName`, `serviceOption` (opsional), `bookingDate`, `bookingTime`, `estimatedCost`, `status`, `currentStep`, `totalSteps`, `notes`, dan `createdAt`. Pembatalan oleh pelanggan mengubah status menjadi `Dibatalkan`; admin dapat memperbarui status/progres dan estimasi biaya.
- Dokumen promo mencakup `title`, `description`, `code`, `discount`, `expiry`, `isActive`, dan `createdAt`.
- Dokumen notifikasi menggunakan `userId`, `title`, `message`, `category`, `isRead`, dan `createdAt`. Aplikasi iOS menampilkan notifikasi dari Firestore; pengiriman push jarak jauh memerlukan penyiapan Firebase Cloud Messaging/APNs secara terpisah.

Estimator servis mengadaptasi model fallback Random Forest dari Android dan berjalan secara lokal di perangkat. Hasilnya hanya perkiraan, bukan penawaran harga servis yang telah dikonfirmasi. Pendaftaran menggunakan email/kata sandi dilanjutkan dengan penyiapan profil dan kendaraan; aplikasi iOS tidak mengirim email verifikasi atau OTP. Preferensi notifikasi dan tema tampilan yang dipilih disimpan secara lokal di perangkat.

Konfigurasi proyek Firebase produksi sengaja tidak disertakan. Tanpa konfigurasi tersebut, autentikasi dan operasi Firestore produksi akan menampilkan pesan kesalahan penyiapan secara eksplisit. Firebase Emulator lokal yang terisolasi dapat dijalankan tanpa kredensial produksi.

## Firebase Emulator Lokal

iOS mendukung proyek pengembangan terisolasi dan port emulator yang sama dengan salinan Android lokal: `demo-autogarage`, dengan Authentication pada port `9099` dan Firestore pada port `8080`. Mode emulator tidak membaca atau menulis data Firebase produksi dan tidak memerlukan `GoogleService-Info.plist`. Di Xcode, edit skema `AutoGarage`, buka **Run > Arguments**, lalu tambahkan `--use-firebase-emulators` pada **Arguments Passed On Launch**. Perintah `bash scripts/firebase-local.sh` pada salinan Android menjalankan emulator Auth/Firestore yang sama dan mendukung pengujian akun, kendaraan, dan booking bersama. Untuk menguji alamat tersimpan di iOS, jalankan Firebase CLI dari direktori proyek iOS ini agar CLI menggunakan `firestore.rules` milik proyek ini:

```sh
firebase emulators:start --only auth,firestore --project demo-autogarage
```

Rules iOS mempertahankan koleksi dan kontrak booking Android, serta mengizinkan subkoleksi alamat tersimpan iOS. Rules Android saat ini belum mencakup subkoleksi tersebut, sehingga operasi alamat akan ditolak jika emulator dijalankan melalui skrip Android. Emulator UI tersedia di http://127.0.0.1:4000.

Host emulator bawaan adalah `127.0.0.1`, sesuai untuk iOS Simulator. Untuk menghubungkan perangkat pengembangan lain, tetapkan `FIREBASE_EMULATOR_HOST` ke host yang dapat dijangkau perangkat tersebut dan konfigurasi emulator agar mendengarkan pada antarmuka itu. Mode emulator memerlukan konfigurasi build Debug dan tidak disertakan dalam build Release. Google Sign-In dinonaktifkan dalam mode lokal; gunakan akun emulator dengan email/kata sandi. Aplikasi menampilkan banner `LOKAL` saat menggunakan proyek demo.

## Build

Buka `201AutoGarage.xcodeproj` di Xcode, tunggu Swift Package Manager menyelesaikan dependensi Firebase dan Google Sign-In, tambahkan konfigurasi Firebase di atas, lalu jalankan skema `AutoGarage` pada perangkat atau simulator dengan iOS 17 atau versi lebih baru.

Target aplikasi menetapkan versi `1.0` dan build `1` melalui `MARKETING_VERSION` dan `CURRENT_PROJECT_VERSION`. Perbarui Build Settings tersebut saat menyiapkan rilis baru; metadata bundle aplikasi mengambil nilainya dari `Info.plist`.

Di macOS, periksa metadata bundle, skema URL callback, dan pengaturan kompilasi emulator Debug/Release dengan `python3 scripts/check-project-config.py`. Untuk memeriksa hasil build yang sudah ada, tambahkan `--built-app /path/to/AutoGarage.app --configuration Debug` (atau `Release`). Pemeriksaan ini menggunakan pengaturan proyek lokal; pemeriksaan ini tidak memvalidasi signing, Firebase aktif, atau penggantian Build Settings dari luar proyek.

Jalankan `python3 scripts/test-store.py` di macOS dengan Xcode terpasang untuk menguji secara deterministik provisioning pendaftaran, pengiriman booking berulang, dan respons tertunda setelah pergantian akun. Runner mengompilasi store dan model produksi dengan test double SDK yang dikendalikan di direktori sementara. Runner tidak terhubung ke Firebase dan tidak memvalidasi Firestore rules; gunakan penyiapan Emulator di atas untuk pengujian integrasi.

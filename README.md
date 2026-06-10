# laporan_keuangan_rt

Lapoaran keuangan RT 3 RW 21, Bukit Permai, Sumbersari, Jember. Sumber data: https://bit.ly/rt3rw21.
Flow:
1. Aplikasi bakal melihat dan menampilkan data dari CSV yang ditentukan
2. Ketika login dan user tersebut memiliki privilege untuk mengubah data, maka pengguna dapat melakukan perubahan data. Data akan disimpan di lokal. Ketika user menekan tombol "Simpan", aplikasi akan "mengubah" csv target, dan kemudian akan melakukan sync lagi dengan data lokal.

## Menjalankan project
flutter devices            # list what you can run on
flutter run -d windows     # desktop (fast dev — what we're using)
flutter run -d emulator-34 # an Android emulator (you have several)
flutter build apk          # produce an installable Android APK


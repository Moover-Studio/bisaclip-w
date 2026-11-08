# BisaClip untuk Windows (bisaclip-w)

Ubah video panjang jadi clip vertikal siap upload (TikTok, Reels, Shorts). AI mencari momen terbaik, memotong, membuat subtitle, judul, hook dan caption, lalu kamu tinggal merapikannya di editor. Semua berjalan di laptop sendiri.

Ini versi **Windows 10/11** dari BisaClip, berjalan di **XAMPP for Windows**. Semua tool (ffmpeg, yt-dlp, whisper, Python) dipasang otomatis oleh installer ke dalam folder aplikasi.

---

## Yang dibutuhkan

| | |
|---|---|
| Windows | Windows 10 (22H2) atau Windows 11, 64-bit |
| RAM | Minimal 8 GB, disarankan 16 GB |
| Ruang disk | ±15 GB kosong |
| XAMPP | [XAMPP for Windows](https://www.apachefriends.org/download.html) (PHP 8.2 ke atas), dipasang di `C:\xampp` |
| Git | Git for Windows. Pasang lewat terminal: `winget install --id Git.Git -e --source winget`. Git Bash dipakai BisaClip untuk menjalankan ffmpeg dan Python. |
| GPU | Opsional. GPU **NVIDIA** membuat transkrip lebih cepat dan mengaktifkan AI upscale 2K. Perbarui driver NVIDIA dulu. |
| Internet | Untuk instalasi, unduh video, dan layanan AI |

---

## Instalasi (sekali per laptop)

### 1. Pasang XAMPP dan Git

1. Unduh dan pasang **XAMPP for Windows** di `C:\xampp` (pilihan bawaan sudah cukup).
2. Buka PowerShell, lalu pasang Git dengan `winget install --id Git.Git -e --source winget`.
3. Tutup lalu buka lagi PowerShell, supaya perintah `git` dikenali.

### 2. Clone ke folder htdocs

```powershell
cd C:\xampp\htdocs
git clone https://github.com/Moover-Studio/bisaclip-w.git
```

Folder harus berada di dalam `C:\xampp\htdocs`, supaya aplikasinya bisa dibuka di `http://localhost/bisaclip-w/`.

### 3. (Opsional) File library tim

Kalau admin memberikan **`bisaclip-library.tar.gz`**, taruh di folder **Downloads**. File ini berisi musik, SFX, preset, dan API key Gemini bawaan tim.

Tanpa file ini, musik, SFX, dan preset mulai kosong, dan API key Gemini diisi sendiri di **Pengaturan → API key**. Key gratis bisa dibuat di [aistudio.google.com/apikey](https://aistudio.google.com/apikey).

### 4. Jalankan installer

Buka `C:\xampp\htdocs\bisaclip-w`, lalu klik dua kali **Install BisaClip.bat**.

- *"Windows protected your PC"*: klik **More info** → **Run anyway**.
- Tunggu sampai muncul **"Selesai!"** (pertama kali 15–30 menit). Di akhir ada cek sistem, dan semua baris wajib harus ✓.

Yang dipasang otomatis:
- **Ke dalam `storage\bin`:** ffmpeg, yt-dlp, deno, dan whisper.
- **Python 3.12 + OpenCV:** dipasang ke `storage\venv`, plus PyTorch kalau ada NVIDIA.
- **Model AI, font Arial Black, dan library tim** (kalau file library ada).
- **Ikon di Desktop:** **BisaClip**, **Hasil BisaClip**, dan **Update BisaClip**.

### 5. Nyalakan Apache

Buka **XAMPP Control Panel**, lalu klik **Start** di baris **Apache**. Setelah itu klik dua kali ikon **BisaClip** di Desktop, yang membuka `http://localhost/bisaclip-w/`.

---

## Memakai sehari-hari

1. Buka **XAMPP Control Panel**, lalu **Start** Apache.
2. Klik ikon **BisaClip** di Desktop.
3. Video hasil render ada di ikon **Hasil BisaClip**, yaitu folder `downloads`.

Kompresi clip otomatis **H.264** supaya bisa diputar dan diedit di Windows. Pengaturannya ada di **Pengaturan → Kompresi**.

---

## Update ke versi terbaru

Klik dua kali ikon **Update BisaClip** di Desktop, atau file **Update BisaClip.bat** di folder aplikasi. Selesai.

Ini padanan `bash install/update-mac.sh` di Mac. Yang dikerjakan:

1. **Cek proses berjalan.** Kalau masih ada unduh, analisa, atau render yang berjalan, kamu ditanya dulu.
2. **Cadangkan pengaturan.** Preset, daftar musik, API key, dan pengaturan disalin ke `%USERPROFILE%\BisaClip-backup\` (10 cadangan terakhir).
3. **Ambil kode terbaru dari GitHub.** Daftar **"Yang baru"** ditampilkan.
4. **Pasang kebutuhan baru kalau ada.** yt-dlp juga diperbarui supaya download YouTube tetap lancar, lalu sistem dicek.

Yang **tidak** disentuh: preset, musik, SFX, API key, room, project, dan hasil render. Semuanya ada di `storage`, `previews`, dan `downloads`, yang tidak dilacak git.

Hal lain yang perlu diketahui:
- **Perubahan kode di laptop tidak hilang.** Kalau ada, perubahan itu disimpan dulu (`git stash list`), lalu kode disamakan dengan GitHub.
- **Library tim terbaru** (musik, SFX, preset baru dari admin): taruh `bisaclip-library.tar.gz` di Downloads, lalu jalankan `"Update BisaClip.bat" -WithLibrary` dari Command Prompt di folder aplikasi. Bisa juga dengan klik **Install BisaClip.bat**.
- **Restart Apache tidak perlu.** Perubahan langsung aktif. Cukup muat ulang halaman BisaClip di browser.

Lewat terminal juga bisa:

```powershell
cd C:\xampp\htdocs\bisaclip-w
.\"Update BisaClip.bat"
```

---

## Kalau ada masalah

| Masalah | Solusi |
|---|---|
| `localhost/bisaclip-w` tidak terbuka | Apache belum jalan. Buka XAMPP Control Panel, lalu **Start** Apache. Kalau port 80 bentrok (Skype/IIS), matikan aplikasi itu. |
| Proses gagal dengan pesan "bash" / "Git" | Git for Windows belum terpasang. Pasang Git, lalu jalankan installer lagi. |
| Download YouTube mulai gagal | Jalankan **Install BisaClip.bat** lagi (yt-dlp diperbarui). |
| Render lambat / cek sistem menulis "encoder software" | Normal tanpa GPU NVIDIA. Kalau punya NVIDIA, perbarui drivernya lalu jalankan installer lagi. |
| Cek komponen | PowerShell: `C:\xampp\php\php.exe C:\xampp\htdocs\bisaclip-w\install\doctor.php` |
| Lihat log proses | `storage\worker.log` |

**Jangan pernah menempel API key** di issue, screenshot, atau chat. File `bisaclip-library.tar.gz` berisi key tim: jangan dibagikan ke luar tim dan jangan di-commit.

---

## Untuk admin

- **Pengembangan:** dilakukan di BisaClip Mac, lalu kodenya disalin ke repo ini.
- **Pemanggilan perintah:** semua perintah memakai `sh_arg()`, `sh_out()`, dan `sh_exec()` di `config.php`.
  - Di Mac/Linux, ketiganya sama persis dengan `escapeshellarg()`, `shell_exec()`, dan `exec()`.
  - Di Windows, perintah dijalankan lewat Git Bash.
- **Path file di filter ffmpeg:** bungkus dengan `ff_path()`, karena `C:` harus di-escape.
- **File library:** dibuat di BisaClip Mac dengan `bash install/export-library.sh`. Bagikan lewat Google Drive atau flashdisk, bukan lewat git.

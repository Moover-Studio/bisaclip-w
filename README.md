# BisaClip untuk Windows (bisaclip-w)

Ubah video panjang jadi clip vertikal siap upload (TikTok, Reels, Shorts). AI mencari momen terbaik, memotong, membuat subtitle, judul, hook dan caption, lalu kamu tinggal merapikannya di editor. Semua berjalan di laptop sendiri.

Ini versi **Windows 10/11** dari BisaClip. Aplikasinya berjalan di **WSL2** (Linux bawaan Windows), tapi tetap dibuka di browser Windows biasa: `http://localhost/bisaclip/`. Semua langkah teknis dikerjakan otomatis oleh installer.

---

## Yang dibutuhkan

| | |
|---|---|
| Windows | Windows 10 (22H2) atau Windows 11, 64-bit |
| RAM | Minimal 8 GB, disarankan 16 GB |
| Ruang disk | ±25 GB kosong di drive C: |
| GPU | Opsional. GPU **NVIDIA** membuat render & transkrip jauh lebih cepat dan mengaktifkan AI upscale 2K. Perbarui dulu **driver NVIDIA di Windows** (Game Ready / Studio). |
| Git | [Git for Windows](https://git-scm.com/download/win), dengan pilihan bawaan saat instalasi |
| Internet | Untuk instalasi, unduh video, dan layanan AI |

---

## Instalasi (sekali per laptop, ±20–40 menit)

### 1. Clone repository

Buka **Command Prompt** atau **PowerShell**, lalu jalankan:

```bat
cd C:\
git clone https://github.com/<organisasi>/bisaclip-w.git BisaClip
```

Ganti `<organisasi>` dengan alamat repository tim. Folder bebas, asalkan ada di drive **C:**. Jangan di drive jaringan atau di dalam OneDrive.

### 2. (Opsional) Siapkan file library tim

Kalau admin memberikan file **`bisaclip-library.tar.gz`**, taruh di folder `C:\BisaClip` atau di **Downloads**. File ini berisi musik, SFX, preset, dan API key Gemini bawaan tim.

Tanpa file ini, BisaClip tetap jalan, tetapi:
- musik, SFX, dan preset mulai kosong;
- API key Gemini harus diisi sendiri di **Pengaturan → API key**. Key gratis bisa dibuat di [aistudio.google.com/apikey](https://aistudio.google.com/apikey).

### 3. Jalankan installer

Buka folder `C:\BisaClip`, lalu klik dua kali **Install BisaClip.bat**.

- *"Windows protected your PC"*: klik **More info** → **Run anyway**.
- Jendela izin Administrator: klik **Yes**.
- Diminta **restart**: restart laptop, lalu klik dua kali **Install BisaClip.bat** lagi. Installer melanjutkan dari bagian yang belum selesai.

Tunggu sampai muncul **"Selesai!"**. Di akhir ada cek sistem, dan semua baris wajib harus ✓.

Yang dipasang otomatis:
- WSL2 + Ubuntu 24.04.
- Apache + PHP.
- ffmpeg.
- yt-dlp + deno.
- whisper.cpp (versi GPU kalau ada NVIDIA).
- Python + OpenCV, plus PyTorch untuk AI upscale kalau ada NVIDIA.
- Model AI.
- Library tim (kalau ada).
- Dua ikon di Desktop.

Untuk sengaja melewati CUDA, jalankan dari Command Prompt di folder BisaClip: `"Install BisaClip.bat" -NoCuda`.

---

## Memakai sehari-hari

- Klik dua kali ikon **BisaClip** di Desktop. Browser terbuka ke `http://localhost/bisaclip/`.
- **Biarkan jendela hitamnya terbuka** (boleh di-minimize) selama memakai BisaClip. Menutupnya akan mematikan BisaClip.
- Video hasil bisa diunduh dari aplikasi, atau dibuka lewat ikon **Hasil BisaClip** di Desktop. Folder ini hanya bisa dibuka saat BisaClip menyala.
- Kompresi clip otomatis **H.264**, supaya bisa diputar dan diedit di Windows. Pengaturannya ada di **Pengaturan → Kompresi**.

Panduan pemakaian lengkap ada di dalam aplikasi: tombol **"Baru pakai BisaClip?"** di Beranda.

---

## Update ke versi terbaru

```bat
cd C:\BisaClip
git pull
```

Lalu klik dua kali **Install BisaClip.bat** lagi. Hanya kode yang diganti. Yang tidak disentuh: preset, musik, SFX, API key, room, project, dan hasil render. Pengaturan juga dicadangkan dulu ke `/root/BisaClip-backup/` di Ubuntu.

> Aplikasi yang berjalan ada di dalam Ubuntu (`/var/www/bisaclip`), bukan di `C:\BisaClip`. Folder clone hanya sumber kode, jadi perubahan baru aktif setelah installer dijalankan lagi.

---

## Kualitas dibanding versi Mac

| Bagian | Mac | Windows |
|---|---|---|
| Encode video | Apple VideoToolbox | NVIDIA NVENC kualitas tertinggi. Tanpa NVIDIA: x264/x265, kualitas sama, lebih lambat |
| AI upscale 2K | Apple super-resolution | Real-ESRGAN (GPU NVIDIA). Tanpa NVIDIA: scaling biasa |
| Subtitle & font | ffmpeg + libass | Sama |
| Transkrip | whisper.cpp | Sama (CUDA atau CPU) |
| Deteksi wajah & split screen | OpenCV YuNet | Sama, model yang sama persis |

---

## Kalau ada masalah

| Masalah | Solusi |
|---|---|
| "Ubuntu tidak bisa dijalankan" / error `0x80370102` | Virtualisasi mati. Cek **Task Manager → Performance → CPU → Virtualization**. Kalau *Disabled*, aktifkan di BIOS (Intel VT-x / AMD SVM), lalu restart. |
| Installer berhenti di tengah | Jalankan **Install BisaClip.bat** lagi. Bagian yang sudah selesai dilewati. |
| `localhost/bisaclip` tidak bisa dibuka | Tutup jendela BisaClip, jalankan `wsl --shutdown` di PowerShell, lalu klik ikon BisaClip lagi. |
| "Akses hanya dari laptop ini" | Buka lewat `http://localhost/bisaclip/`, bukan alamat IP. |
| Render lambat / cek sistem menulis "encoder software" | GPU NVIDIA tidak terbaca. Perbarui driver NVIDIA di Windows, jalankan `wsl --shutdown`, lalu jalankan installer lagi. |
| Download YouTube mulai gagal | Jalankan installer lagi (yt-dlp ikut diperbarui). |
| Drive C: cepat penuh | Buka **Pengaturan → Manajemen storage**, lalu hapus video sumber dan render lama. |
| Pasang library tim setelah instalasi | Taruh `bisaclip-library.tar.gz` di Downloads, lalu jalankan **Install BisaClip.bat** lagi. |
| Cek komponen | PowerShell: `wsl -d Ubuntu-24.04 -u root -- sudo -u www-data php /var/www/bisaclip/install/doctor.php` |

**Jangan pernah menempel API key** di issue, screenshot, atau chat. File `bisaclip-library.tar.gz` juga berisi key tim, jadi jangan dibagikan ke luar tim dan jangan di-commit (sudah di-ignore oleh `.gitignore`).

---

## Untuk admin

- **Sumber kode:** repo ini disalin dari BisaClip (Mac). Fitur baru dikembangkan di repo Mac, lalu disalin ke sini.
- **File library:** dibuat di BisaClip Mac dengan `bash install/export-library.sh`. Tambahkan `--with-models` kalau ingin model AI (±550 MB) ikut dibawa, supaya laptop tidak perlu mengunduhnya. Bagikan file itu lewat Google Drive atau flashdisk, **bukan** lewat git.

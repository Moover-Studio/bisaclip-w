# Installer BisaClip untuk Windows 10 (22H2) / 11, lewat WSL2 + Ubuntu 24.04.
# Dijalankan oleh "Install BisaClip.bat" di folder hasil git clone (atau di folder paket ZIP).
# Aman dijalankan ulang, dan dipakai juga untuk UPDATE (setelah git pull): hanya kode yang diganti, data tidak disentuh.
# Opsi: -NoCuda  lewati CUDA (whisper & AI upscale tanpa GPU NVIDIA)
# Catatan: file ini sengaja hanya berisi karakter ASCII (Windows PowerShell 5.1 membaca file tanpa BOM sebagai ANSI).
param([switch]$NoCuda)

$ErrorActionPreference = 'Continue'
$Distro = 'Ubuntu-24.04'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$env:WSL_UTF8 = '1'   # output wsl.exe dalam UTF-8, bukan UTF-16

function Say([string]$m) { Write-Host ''; Write-Host "==> $m" -ForegroundColor Cyan }
function Ok([string]$m) { Write-Host "    [OK] $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Host "    [!]  $m" -ForegroundColor Yellow }
function Fail([string]$m) { Write-Host ''; Write-Host "GAGAL: $m" -ForegroundColor Red; exit 1 }
function Clean([object]$o) { return (($o | Out-String) -replace "`0", '').Trim() }
function Has-Distro {
    $l = Clean (& wsl.exe -l -q 2>$null)
    return [bool](($l -split "`r?`n" | ForEach-Object { $_.Trim() }) -contains $Distro)
}
function To-Wsl([string]$p) { return Clean (& wsl.exe -d $Distro -u root -e wslpath -a "$p") }

Write-Host ''
Write-Host '  BisaClip - Installer Windows' -ForegroundColor White
Write-Host '  Biarkan jendela ini terbuka sampai selesai (20-40 menit, sebagian besar menunggu unduhan).'

# ---------- 1. Sumber kode: folder git clone (install\windows di dalamnya) atau folder paket ZIP ----------
$RepoDir = (Resolve-Path "$Here\..\..").Path
if (Test-Path "$RepoDir\config.php") {
    $Src = $RepoDir
} elseif (Test-Path "$Here\bisaclip-app.tar.gz") {
    $Src = $Here
} else {
    Fail 'File aplikasi tidak lengkap. Clone ulang repository, atau ekstrak dulu ZIP-nya (klik kanan > Extract All).'
}
if (-not (Test-Path "$Here\install-in-wsl.sh")) { Fail "install-in-wsl.sh tidak ada di $Here" }

# File library opsional (musik, SFX, preset, key bawaan tim), dibuat admin di BisaClip Mac (install/export-library.sh)
$Lib = $null
foreach ($c in @("$Src\bisaclip-library.tar.gz", "$RepoDir\bisaclip-library.tar.gz",
                 "$env:USERPROFILE\Downloads\bisaclip-library.tar.gz", "$env:USERPROFILE\Desktop\bisaclip-library.tar.gz",
                 ([Environment]::GetFolderPath('Desktop') + '\bisaclip-library.tar.gz'))) {
    if (Test-Path $c) { $Lib = $c; break }
}

# ---------- 2. Windows & WSL2 ----------
Say 'Memeriksa Windows...'
$build = [Environment]::OSVersion.Version.Build
if ($build -lt 19045) { Fail "Windows terlalu lama (build $build). Butuh Windows 10 22H2 (build 19045) atau Windows 11. Jalankan Windows Update dulu." }
if (-not (Test-Path "$env:WINDIR\System32\wsl.exe")) { Fail 'wsl.exe tidak ditemukan. Jalankan Windows Update sampai terbaru, lalu coba lagi.' }
Ok "Windows build $build"

Say "Memeriksa WSL2 + $Distro..."
if (-not (Has-Distro)) {
    Warn "$Distro belum terpasang. Memasang sekarang (butuh internet; kalau muncul jendela izin Administrator, klik Yes)..."
    & wsl.exe --update 2>$null | Out-Null
    & wsl.exe --set-default-version 2 2>$null | Out-Null
    & wsl.exe --install -d $Distro --no-launch
    if (-not (Has-Distro)) {
        # Format distro lama (Store / appx): daftarkan lewat launcher-nya, dengan user root (tanpa pertanyaan username)
        $launcher = Get-Command ubuntu2404.exe -ErrorAction SilentlyContinue
        if ($launcher) { & $launcher.Source install --root | Out-Null }
    }
    if (-not (Has-Distro)) {
        Write-Host ''
        Write-Host '  WSL baru diaktifkan dan Windows perlu RESTART.' -ForegroundColor Yellow
        Write-Host '  Restart laptop, lalu klik dua kali "Install BisaClip.bat" lagi untuk melanjutkan.' -ForegroundColor Yellow
        exit 3
    }
}
$ver = Clean (& wsl.exe -l -v 2>$null)
foreach ($line in ($ver -split "`r?`n")) {
    if ($line -match ("\s" + [regex]::Escape($Distro) + "\s.*\s1\s*$")) {
        Warn "$Distro masih WSL1, mengubah ke WSL2 (beberapa menit)..."
        & wsl.exe --set-version $Distro 2
    }
}
& wsl.exe -d $Distro -u root -e true
if ($LASTEXITCODE -ne 0) {
    Fail ("Ubuntu tidak bisa dijalankan. Biasanya karena Virtualization mati di BIOS (cek Task Manager > Performance > CPU > Virtualization: Enabled). " +
        'Aktifkan di BIOS, atau aktifkan fitur Windows "Virtual Machine Platform", restart, lalu coba lagi.')
}
Ok "$Distro (WSL2) siap"

# ---------- 3. Pasang / update BisaClip di dalam Ubuntu ----------
$wSrc = To-Wsl $Src
$wHere = To-Wsl $Here
if (-not $wSrc.StartsWith('/') -or -not $wHere.StartsWith('/')) {
    Fail "Folder tidak bisa dibaca dari Ubuntu: $Src. Pindahkan folder BisaClip ke drive C: (mis. C:\BisaClip), lalu coba lagi."
}
$wslArgs = @('-d', $Distro, '-u', 'root', '-e', 'bash', "$wHere/install-in-wsl.sh", $wSrc)
if ($Lib) { $wslArgs += ('--lib=' + (To-Wsl $Lib)); Ok "Library: $Lib" } else { Warn 'File bisaclip-library.tar.gz tidak ditemukan: musik, SFX & preset mulai kosong (bisa dipasang nanti).' }
if ($NoCuda) { $wslArgs += '--no-cuda' }
& wsl.exe @wslArgs
if ($LASTEXITCODE -ne 0) { Fail 'Instalasi di Ubuntu berhenti karena error (lihat pesan di atas). Periksa internet, lalu jalankan installer ini lagi: bagian yang sudah selesai akan dilewati.' }

# ---------- 4. Ikon di Desktop ----------
Say 'Membuat ikon di Desktop...'
$desk = [Environment]::GetFolderPath('Desktop')
$bat = if (Test-Path "$Here\BisaClip.bat") { "$Here\BisaClip.bat" } else { "$RepoDir\install\BisaClip.bat" }
Copy-Item -Force $bat "$desk\BisaClip.bat"
try {
    $sh = New-Object -ComObject WScript.Shell
    $lnk = $sh.CreateShortcut("$desk\Hasil BisaClip.lnk")
    $lnk.TargetPath = "\\wsl$\$Distro\var\www\bisaclip\downloads"
    $lnk.Save()
    Ok '"BisaClip" (menyalakan aplikasi) dan "Hasil BisaClip" (folder video hasil)'
} catch {
    Ok '"BisaClip" (menyalakan aplikasi)'
}

Write-Host ''
Write-Host '  Selesai! BisaClip sedang dinyalakan dan browser akan terbuka: http://localhost/bisaclip/' -ForegroundColor Green
Write-Host '  Lain kali: klik dua kali ikon "BisaClip" di Desktop, dan biarkan jendela hitamnya terbuka selama dipakai.'
Start-Process -FilePath "$desk\BisaClip.bat"
exit 0

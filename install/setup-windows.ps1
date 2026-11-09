# Pasang semua kebutuhan BisaClip di Windows 10/11 dengan XAMPP for Windows (tanpa WSL).
# Dijalankan oleh "Install BisaClip.bat" di folder aplikasi (mis. C:\xampp\htdocs\bisaclip-w).
# Aman dijalankan ulang (juga setelah git pull): yang sudah ada dilewati, yt-dlp selalu diperbarui, data tidak disentuh.
# Opsi: -NoCuda     jangan pakai GPU NVIDIA untuk whisper & AI upscale.
#       -NoLibrary  lewati pemasangan file library tim (dipakai oleh install\update-windows.ps1)
# Catatan: file ini sengaja hanya berisi karakter ASCII (Windows PowerShell 5.1 membaca file tanpa BOM sebagai ANSI).
param([switch]$NoCuda, [switch]$NoLibrary)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$App = (Resolve-Path "$PSScriptRoot\..").Path
$Bin = "$App\storage\bin"
$Models = "$App\storage\models"
$Tmp = Join-Path $env:TEMP ('bisaclip-setup-' + [guid]::NewGuid().ToString('N').Substring(0, 8))

function Say([string]$m) { Write-Host ''; Write-Host "==> $m" -ForegroundColor Cyan }
function Ok([string]$m) { Write-Host "    [OK] $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Host "    [!]  $m" -ForegroundColor Yellow }
function Fail([string]$m) { Write-Host ''; Write-Host "GAGAL: $m" -ForegroundColor Red; exit 1 }
# Unduh dengan curl.exe bawaan Windows (lebih cepat dari Invoke-WebRequest, bisa dilanjutkan)
function Fetch([string]$url, [string]$dest, [switch]$Quiet) {
    $part = "$dest.part"
    $a = @('-fL', '--retry', '3', '-o', $part, $url)
    if ($Quiet) { $a = @('-s') + $a } else { $a = @('--progress-bar', '-C', '-') + $a }
    & curl.exe @a
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $part)) { Remove-Item -Force $part -ErrorAction SilentlyContinue; return $false }
    Move-Item -Force $part $dest
    return $true
}

Write-Host ''
Write-Host '  BisaClip - Setup Windows (XAMPP)' -ForegroundColor White
Write-Host '  Biarkan jendela ini terbuka sampai selesai (pertama kali 15-30 menit, sebagian besar menunggu unduhan).'
New-Item -ItemType Directory -Force -Path $Bin, $Models, $Tmp, "$App\storage\tmp", "$App\downloads", "$App\previews", "$App\avatars" | Out-Null

# ---------- 1. XAMPP (PHP) ----------
Say 'Memeriksa XAMPP...'
$Php = $null
$m = [regex]::Match($App, '^(.*)\\htdocs\\')
foreach ($c in @($(if ($m.Success) { $m.Groups[1].Value + '\php\php.exe' }), 'C:\xampp\php\php.exe')) {
    if ($c -and (Test-Path $c)) { $Php = $c; break }
}
if (-not $Php) { Fail 'XAMPP belum terpasang. Pasang XAMPP for Windows (apachefriends.org) di C:\xampp, lalu jalankan ini lagi.' }
# -n = tanpa php.ini, supaya warning dari php.ini tidak tercampur di output
$phpVer = ((& $Php -n -r 'echo PHP_VERSION;' 2>$null) | Select-Object -Last 1)
if (-not $phpVer -or [version]($phpVer -replace '[^0-9.].*$', '') -lt [version]'8.1') { Fail "PHP $phpVer terlalu lama / tidak terbaca. Pasang XAMPP versi terbaru (PHP 8.2 ke atas)." }
Ok "PHP $phpVer ($Php)"

# ---------- php.ini ----------
# XAMPP tertentu (versi zip / PHP diganti manual) TIDAK punya php.ini, hanya php.ini-development & -production,
# sehingga PHP jalan tanpa ekstensi (curl, mbstring, ...). Dibuat dari php.ini-development.
# Diproses per baris (file Windows ber-CRLF): extension_dir ke folder ext XAMPP, ekstensi dinyalakan tepat satu kali.
$Exts = @('curl', 'mbstring', 'openssl', 'fileinfo', 'gd')
$PhpDir = Split-Path $Php
$PhpIni = Join-Path $PhpDir 'php.ini'
$ExtDir = Join-Path $PhpDir 'ext'
$ExtChanged = $false
$enc = [Text.Encoding]::GetEncoding(28591)
try {
    if (Test-Path $PhpIni) {
        $orig = [IO.File]::ReadAllText($PhpIni, $enc)
    } else {
        $tpl = @("$PhpDir\php.ini-development", "$PhpDir\php.ini-production") | Where-Object { Test-Path $_ } | Select-Object -First 1
        $orig = ''
        $base = if ($tpl) { [IO.File]::ReadAllText($tpl, $enc) } else { "[PHP]" }
        $base = $base.TrimEnd() + "`r`n`r`n; --- BisaClip ---`r`nmemory_limit=1024M`r`nupload_max_filesize=4G`r`npost_max_size=4G`r`nmax_execution_time=0`r`ndate.timezone=Asia/Jakarta`r`n"
    }
    $lines = New-Object System.Collections.Generic.List[string]
    $src = if ($orig) { $orig } else { $base }
    foreach ($l in ($src -split "\r?\n")) { $lines.Add($l) }

    # extension_dir: pakai yang ada kalau valid, selain itu arahkan ke folder ext XAMPP (bawaan PHP Windows C:\php\ext salah)
    $edOk = $false; $edIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*extension_dir\s*=\s*"?([^";]*)"?') {
            $cur = $Matches[1].Trim()
            $abs = if ($cur -and [IO.Path]::IsPathRooted($cur)) { $cur } else { Join-Path $PhpDir $cur }
            if ($edIdx -lt 0) { $edIdx = $i; $edOk = Test-Path (Join-Path $abs 'php_curl.dll') }
            else { $lines[$i] = ';' + $lines[$i] }  # extension_dir ganda
        }
    }
    if (-not $edOk) {
        $ed = "extension_dir=`"$ExtDir`""
        if ($edIdx -ge 0) { $lines[$edIdx] = $ed } else { $lines.Add($ed) }
    }

    foreach ($x in $Exts) {
        $pat = "^\s*extension\s*=\s*`"?(php_)?$x(\.dll)?`"?\s*(;.*)?$"
        $active = @(); $commented = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match $pat) { $active += $i }
            elseif ($commented -lt 0 -and $lines[$i] -match "^\s*;\s*extension\s*=\s*`"?(php_)?$x(\.dll)?`"?\s*$") { $commented = $i }
        }
        if ($active.Count -gt 1) { foreach ($i in $active[1..($active.Count - 1)]) { $lines[$i] = ';' + $lines[$i] } }
        elseif ($active.Count -eq 0) { if ($commented -ge 0) { $lines[$commented] = "extension=$x" } else { $lines.Add("extension=$x") } }
    }

    $new = ($lines -join "`r`n")
    if ($new -ne $orig) {
        if ($orig -and -not (Test-Path "$PhpIni.bisaclip-bak")) { Copy-Item $PhpIni "$PhpIni.bisaclip-bak" }
        [IO.File]::WriteAllText($PhpIni, $new, $enc)
        $ExtChanged = $true
        if ($orig) { Ok 'php.ini dirapikan (cadangan: php.ini.bisaclip-bak)' } else { Ok 'php.ini dibuat dari php.ini-development' }
    }
} catch {
    Fail "Tidak bisa menulis $PhpIni ($($_.Exception.Message)). Klik kanan Install BisaClip.bat -> Run as administrator."
}
$mods = (& $Php -m 2>$null) -join ' '
$still = @($Exts | Where-Object { $mods -notmatch "(?i)(^|\s)$_(\s|$)" })
if ($still.Count -eq 0) { Ok ('Ekstensi PHP aktif: ' + ($Exts -join ', ')) }
else { Warn "Ekstensi PHP belum aktif: $($still -join ', ') (file php_*.dll tidak ada di $ExtDir?). Pasang ulang XAMPP versi terbaru." }

# ---------- Apache: DLL pendukung ekstensi ----------
# php_curl.dll butuh DLL di folder php (libssh2, nghttp2, ...). PHP di terminal menemukannya, tapi Apache
# (httpd.exe di apache\bin) tidak, sehingga curl hanya gagal di Apache. Solusi: LoadFile DLL itu di httpd-xampp.conf.
function Get-DllNames([string]$path) {
    $txt = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes($path))
    [regex]::Matches($txt, '[A-Za-z0-9_+.-]{2,60}\.dll') | ForEach-Object { $_.Value } | Sort-Object -Unique
}
$XamppDir = Split-Path $PhpDir
$ApacheBin = Join-Path $XamppDir 'apache\bin'
$HttpdConf = Join-Path $XamppDir 'apache\conf\extra\httpd-xampp.conf'
if ((Test-Path $HttpdConf) -and (Test-Path "$ExtDir\php_curl.dll")) {
    $need = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    function Visit([string]$dll) {
        foreach ($d in (Get-DllNames $dll)) {
            $k = $d.ToLower()
            if ($seen.ContainsKey($k) -or $k -like 'php*') { continue }
            $seen[$k] = $true
            $p = Join-Path $PhpDir $d
            if (-not (Test-Path $p)) { continue }
            $a = Join-Path $ApacheBin $d
            # Nama sama di apache\bin tapi isi beda (mis. nghttp2.dll lama milik Apache) -> versi PHP harus dimuat dulu.
            # libcrypto/libssl dikecualikan: sudah dipakai mod_ssl, dan ekstensi openssl berjalan dengan versi Apache.
            $differs = (Test-Path $a) -and $k -notmatch '^lib(crypto|ssl)' -and ((Get-FileHash $a).Hash -ne (Get-FileHash $p).Hash)
            if (-not (Test-Path $a) -or $differs) {
                Visit $p                       # dependensinya dulu (urutan LoadFile penting)
                $need.Add($d)
            }
        }
    }
    try {
        Visit "$ExtDir\php_curl.dll"
        $conf = [IO.File]::ReadAllText($HttpdConf, $enc)
        $add = @($need | Where-Object { $conf -notmatch ('(?i)LoadFile\s+"?[^"\r\n]*[\\/]' + [regex]::Escape($_)) })
        if ($add.Count -gt 0) {
            $phpFwd = $PhpDir.Replace('\', '/')
            $ins = ($add | ForEach-Object { "LoadFile `"$phpFwd/$_`"" }) -join "`r`n"
            $mm = [regex]::Match($conf, '(?im)^[ \t]*LoadModule[ \t]+php')
            if ($mm.Success) {
                if (-not (Test-Path "$HttpdConf.bisaclip-bak")) { Copy-Item $HttpdConf "$HttpdConf.bisaclip-bak" }
                $conf = $conf.Insert($mm.Index, "# BisaClip: DLL pendukung php_curl`r`n$ins`r`n")
                [IO.File]::WriteAllText($HttpdConf, $conf, $enc)
                $ExtChanged = $true
                Ok ('Apache: memuat ' + ($add -join ', '))
            }
        }
    } catch { Warn "Tidak bisa mengubah $HttpdConf ($($_.Exception.Message))." }
}
if (-not $m.Success) { Warn "Folder aplikasi sebaiknya di dalam C:\xampp\htdocs supaya bisa dibuka lewat http://localhost/..." }

# ---------- 2. Git Bash (dipakai untuk menjalankan semua perintah ffmpeg/python) ----------
Say 'Memeriksa Git Bash...'
$Bash = @("$env:ProgramFiles\Git\bin\bash.exe", "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe", "${env:ProgramFiles(x86)}\Git\bin\bash.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Bash) {
    Warn 'Git for Windows belum ada, memasang lewat winget...'
    & winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    $Bash = @("$env:ProgramFiles\Git\bin\bash.exe", "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $Bash) { Fail 'Git for Windows belum terpasang. Pasang dari git-scm.com/download/win, lalu jalankan ini lagi.' }
Ok $Bash

# ---------- 3. GPU ----------
$Gpu = $false
$Cc = 0.0
$smi = "$env:WINDIR\System32\nvidia-smi.exe"
if (-not $NoCuda -and (Test-Path $smi)) {
    $name = (& $smi --query-gpu=name --format=csv,noheader 2>$null | Select-Object -First 1)
    if ($LASTEXITCODE -eq 0 -and $name) {
        $Gpu = $true
        try { $Cc = [double]((& $smi --query-gpu=compute_cap --format=csv,noheader 2>$null | Select-Object -First 1).Trim()) } catch { $Cc = 0 }
        Ok "GPU NVIDIA: $name"
    }
}
if (-not $Gpu) { Warn 'Tanpa GPU NVIDIA: render & transkrip memakai CPU (hasil sama, lebih lambat), AI upscale memakai scaling biasa.' }

# ---------- 4. ffmpeg (build lengkap: libass, x264, x265, NVENC) ----------
Say 'Memasang ffmpeg...'
if (-not (Test-Path "$Bin\ffmpeg.exe") -or -not (Test-Path "$Bin\ffprobe.exe")) {
    if (-not (Fetch 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip' "$Tmp\ff.zip")) { Fail 'Gagal mengunduh ffmpeg. Periksa internet lalu coba lagi.' }
    Expand-Archive -Force "$Tmp\ff.zip" "$Tmp\ff"
    Get-ChildItem -Recurse "$Tmp\ff" -Include ffmpeg.exe, ffprobe.exe | Copy-Item -Destination $Bin -Force
}
if (((& "$Bin\ffmpeg.exe" -hide_banner -filters 2>$null) -join "`n") -notmatch ' ass ') { Fail 'ffmpeg tanpa libass (subtitle). Hapus storage\bin\ffmpeg.exe lalu jalankan ini lagi.' }
Ok ((& "$Bin\ffmpeg.exe" -hide_banner -version | Select-Object -First 1).Substring(0, 40))

# ---------- 5. yt-dlp (selalu terbaru) + deno ----------
Say 'Memasang yt-dlp & deno...'
if (-not (Fetch 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' "$Bin\yt-dlp.exe" -Quiet)) {
    if (Test-Path "$Bin\yt-dlp.exe") { Warn 'Gagal memperbarui yt-dlp, memakai versi yang ada.' } else { Fail 'Gagal mengunduh yt-dlp.' }
}
Ok ('yt-dlp ' + (& "$Bin\yt-dlp.exe" --version))
# Sertifikat CA untuk HTTPS dari PHP (Gemini, ElevenLabs). XAMPP sering tidak mengisi curl.cainfo di php.ini.
if (Fetch 'https://curl.se/ca/cacert.pem' "$App\storage\cacert.pem" -Quiet) { Ok 'Sertifikat CA (storage\cacert.pem)' }
elseif (Test-Path "$App\storage\cacert.pem") { Warn 'Gagal memperbarui sertifikat CA, memakai yang ada.' }
else { Warn 'Gagal mengunduh sertifikat CA. Kalau simpan API key gagal karena SSL, jalankan installer ini lagi.' }
if (-not (Test-Path "$Bin\deno.exe")) {
    if (-not (Fetch 'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip' "$Tmp\deno.zip" -Quiet)) { Fail 'Gagal mengunduh deno.' }
    Expand-Archive -Force "$Tmp\deno.zip" $Bin
}
Ok ('deno ' + ((& "$Bin\deno.exe" --version | Select-Object -First 1) -replace '^deno\s+', ''))

# ---------- 6. whisper.cpp (transkrip subtitle) ----------
Say 'Memasang whisper (transkrip)...'
# Versi dikunci: rilis whisper.cpp terbaru kadang tidak menyertakan file Windows (dan nama filenya pernah berganti)
$WhisperVer = 'v1.9.2'
$script:WhisperCode = $null
function Test-Whisper {
    if (-not (Test-Path "$Bin\whisper-cli.exe")) { $script:WhisperCode = 'tidak ada'; return $false }
    & "$Bin\whisper-cli.exe" -h *> $null
    $script:WhisperCode = $LASTEXITCODE
    return ($LASTEXITCODE -eq 0)
}
# whisper-cli butuh Microsoft Visual C++ Runtime (sering belum ada di Windows baru)
function Install-VcRedist {
    if ((Test-Path "$env:WINDIR\System32\msvcp140.dll") -and (Test-Path "$env:WINDIR\System32\vcruntime140_1.dll")) { return }
    Warn 'Memasang Microsoft Visual C++ Runtime (kalau muncul jendela izin Administrator, klik Yes)...'
    if (-not (Fetch 'https://aka.ms/vs/17/release/vc_redist.x64.exe' "$Tmp\vc_redist.x64.exe" -Quiet)) { Warn 'Gagal mengunduh Visual C++ Runtime.'; return }
    $p = Start-Process -FilePath "$Tmp\vc_redist.x64.exe" -ArgumentList '/install', '/quiet', '/norestart' -Verb RunAs -Wait -PassThru
    if ($p.ExitCode -in 0, 1638, 3010) { Ok 'Visual C++ Runtime' } else { Warn "Visual C++ Runtime gagal dipasang (kode $($p.ExitCode))." }
}
Install-VcRedist
if (-not (Test-Whisper)) {
    $pick = @()
    if ($Gpu) { $pick += 'whisper-cublas-12.4.0-bin-x64.zip' }
    $pick += 'whisper-bin-x64.zip'
    foreach ($name in $pick) {
        Write-Host "    mengunduh $name ($WhisperVer)..."
        if (-not (Fetch "https://github.com/ggml-org/whisper.cpp/releases/download/$WhisperVer/$name" "$Tmp\w.zip")) { Warn "Gagal mengunduh $name."; continue }
        Remove-Item -Recurse -Force "$Tmp\w" -ErrorAction SilentlyContinue
        Expand-Archive -Force "$Tmp\w.zip" "$Tmp\w"
        # Sisa versi lain (mis. DLL CUDA) dibersihkan dulu supaya tidak tercampur
        Get-ChildItem $Bin -Include 'whisper*', 'ggml*', 'cublas*', 'cudart*', 'nvblas*', 'nvrtc*', 'SDL2.dll' -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Recurse "$Tmp\w" | Where-Object { $_.Name -eq 'whisper-cli.exe' -or $_.Extension -eq '.dll' } | Copy-Item -Destination $Bin -Force
        if (Test-Whisper) { break }
        Warn "$name tidak bisa dijalankan di laptop ini (kode $script:WhisperCode), mencoba versi lain..."
    }
}
if (-not (Test-Whisper)) {
    $why = switch ($script:WhisperCode) {
        -1073741515 { 'ada DLL yang tidak ditemukan (biasanya Microsoft Visual C++ Runtime). Pasang dari https://aka.ms/vs/17/release/vc_redist.x64.exe lalu jalankan ini lagi.' }
        -1073741795 { 'CPU laptop ini tidak didukung build whisper (instruksi CPU tidak tersedia).' }
        'tidak ada' { 'file whisper-cli.exe tidak ada setelah diunduh (kemungkinan diblokir antivirus: cek Windows Security > Protection history).' }
        default { "whisper-cli.exe gagal dijalankan (kode $script:WhisperCode)." }
    }
    Fail "whisper-cli gagal dipasang: $why"
}
Ok "whisper-cli ($WhisperVer)"

# ---------- 7. Python + OpenCV (deteksi wajah, split screen) ----------
Say 'Menyiapkan Python...'
$Venv = "$App\storage\venv\Scripts\python.exe"
function Find-Python {
    foreach ($v in @('3.12', '3.13', '3.11')) {
        $p = (& py "-$v" -c 'import sys;print(sys.executable)' 2>$null)
        if ($LASTEXITCODE -eq 0 -and $p) { return $p.Trim() }
    }
    foreach ($p in @("$env:LOCALAPPDATA\Programs\Python\Python312\python.exe", "$env:ProgramFiles\Python312\python.exe")) { if (Test-Path $p) { return $p } }
    return $null
}
if (-not (Test-Path $Venv)) {
    $Py = Find-Python
    if (-not $Py) {
        Warn 'Python belum ada, memasang Python 3.12 lewat winget...'
        & winget install --id Python.Python.3.12 -e --source winget --scope user --silent --accept-package-agreements --accept-source-agreements
        $Py = Find-Python
    }
    if (-not $Py) { Fail 'Python gagal dipasang. Pasang Python 3.12 dari python.org (centang "Add to PATH"), lalu jalankan ini lagi.' }
    & $Py -m venv "$App\storage\venv"
}
if (-not (Test-Path $Venv)) { Fail 'Gagal membuat Python venv di storage\venv.' }
& $Venv -m pip install -q --disable-pip-version-check --upgrade pip
& $Venv -m pip install -q --disable-pip-version-check numpy opencv-python-headless fonttools
if ($LASTEXITCODE -ne 0) { Fail 'Gagal memasang paket Python (numpy, opencv). Periksa internet lalu coba lagi.' }
Ok ('OpenCV ' + (& $Venv -c 'import cv2;print(cv2.__version__)'))
if ($Gpu) {
    & $Venv -c 'import torch' 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host '    memasang PyTorch untuk AI upscale (+-3 GB)...'
        $cu = if ($Cc -gt 0 -and $Cc -lt 7.0) { 'cu126' } else { 'cu128' }
        & $Venv -m pip install -q --disable-pip-version-check torch --index-url "https://download.pytorch.org/whl/$cu"
    }
    if ((& $Venv -c 'import torch;print(torch.cuda.is_available())' 2>$null) -eq 'True') { Ok 'PyTorch CUDA (AI upscale)' } else { Warn 'PyTorch tidak melihat GPU: AI upscale memakai scaling biasa.' }
}

# ---------- 8. Model AI ----------
Say 'Memeriksa model AI...'
function Model([string]$file, [string]$url) {
    if ((Test-Path "$Models\$file") -and (Get-Item "$Models\$file").Length -gt 0) { Ok "$file sudah ada"; return }
    Write-Host "    mengunduh $file..."
    if (Fetch $url "$Models\$file") { Ok $file } else { Fail "Gagal mengunduh $file. Periksa internet lalu coba lagi." }
}
Model 'ggml-large-v3-turbo-q5_0.bin' 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin'
Model 'face_detection_yunet.onnx' 'https://github.com/opencv/opencv_zoo/raw/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx'
if ($Gpu) { Model 'realesr-general-x4v3.pth' 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesr-general-x4v3.pth' }

# ---------- 9. Font Arial Black (gaya subtitle bawaan) ----------
$ab = "$env:WINDIR\Fonts\ariblk.ttf"
if ((Test-Path $ab) -and -not (Test-Path "$App\assets\fonts\ariblk.ttf")) { Copy-Item $ab "$App\assets\fonts\ariblk.ttf" }

# ---------- 10. Library tim (musik, SFX, preset, key Gemini bawaan) ----------
$Lib = if ($NoLibrary) { $null } else { @("$App\bisaclip-library.tar.gz", "$env:USERPROFILE\Downloads\bisaclip-library.tar.gz", ([Environment]::GetFolderPath('Desktop') + '\bisaclip-library.tar.gz')) | Where-Object { Test-Path $_ } | Select-Object -First 1 }
if ($Lib) {
    Say "Memasang library tim dari $Lib..."
    New-Item -ItemType Directory -Force "$Tmp\lib" | Out-Null
    & "$env:WINDIR\System32\tar.exe" -xzf $Lib -C "$Tmp\lib"
    if ($LASTEXITCODE -ne 0) { Fail 'File library rusak atau tidak bisa dibuka.' }
    # File yang sudah ada tidak ditimpa; daftar (musik, SFX, preset) digabung oleh merge-library.php
    foreach ($d in @('previews', 'storage')) {
        if (Test-Path "$Tmp\lib\$d") {
            & robocopy "$Tmp\lib\$d" "$App\$d" /E /XC /XN /XO /NFL /NDL /NJH /NJS /NP /XF music.json sfx.json presets.json brands.json mproj_presets.json settings.json | Out-Null
        }
    }
    & $Php "$App\install\merge-library.php" "$Tmp\lib" $App
    Ok 'Library terpasang'
} elseif ($NoLibrary) {
    Ok 'Library tim dilewati (update): musik, SFX & preset di laptop ini tetap'
} else {
    Warn 'File bisaclip-library.tar.gz tidak ditemukan (Downloads / Desktop): musik, SFX & preset mulai kosong, API key Gemini diisi di Pengaturan.'
}

# Pemasangan pertama: kompresi H.264 (HEVC butuh codec tambahan di Windows)
if (-not (Test-Path "$App\storage\.windows-installed")) {
    & $Php -r '$f=$argv[1]; $s=json_decode((string)@file_get_contents($f),true); $s=is_array($s)?$s:[]; $s["clip_codec"]="h264"; file_put_contents($f, json_encode($s, JSON_PRETTY_PRINT));' "$App\storage\settings.json"
    Ok 'Kompresi clip: H.264 (bisa diubah di Pengaturan)'
}
Remove-Item -Force "$App\storage\hwenc.json" -ErrorAction SilentlyContinue   # deteksi encoder GPU diulang
Set-Content -Path "$App\storage\.windows-installed" -Value (Get-Date -Format s)

# ---------- 11. Ikon di Desktop ----------
$url = 'http://localhost/'
if ($m.Success) { $url += ($App.Substring($m.Groups[0].Length) -replace '\\', '/') + '/' }
$desk = [Environment]::GetFolderPath('Desktop')
Set-Content -Path "$desk\BisaClip.url" -Value "[InternetShortcut]`r`nURL=$url`r`n"
try {
    $sh = New-Object -ComObject WScript.Shell
    $lnk = $sh.CreateShortcut("$desk\Hasil BisaClip.lnk"); $lnk.TargetPath = "$App\downloads"; $lnk.Save()
    $lnk = $sh.CreateShortcut("$desk\Update BisaClip.lnk"); $lnk.TargetPath = "$App\Update BisaClip.bat"; $lnk.WorkingDirectory = $App
    $lnk.IconLocation = "$env:WINDIR\System32\shell32.dll,238"; $lnk.Save()
} catch { }
Ok "Ikon Desktop: BisaClip ($url), Hasil BisaClip, Update BisaClip"

# ---------- 12. Cek akhir ----------
Say 'Cek sistem'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
& $Php "$App\install\doctor.php"
Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue

$up = $false
try { $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 $url; $up = $true } catch { }
if ($up -and -not $ExtChanged) {
    # Cek PHP yang dipakai Apache (bisa memakai php.ini lain dari PHP CLI)
    try {
        $h = Invoke-RestMethod -UseBasicParsing -TimeoutSec 5 ($url + 'api.php?action=health')
        if ($h.missing.Count -gt 0) {
            Warn "Apache: ekstensi PHP belum aktif: $($h.missing -join ', ') (php.ini Apache: $($h.ini)). Restart Apache (Stop lalu Start di XAMPP Control Panel), lalu jalankan installer ini lagi."
        } else { Ok "Apache PHP $($h.php): ekstensi lengkap" }
    } catch { }
}
Write-Host ''
if ($ExtChanged) {
    Write-Host '  PENTING: pengaturan PHP diubah. Restart Apache supaya aktif:' -ForegroundColor Yellow
    Write-Host '    XAMPP Control Panel -> baris Apache -> klik Stop, lalu Start.' -ForegroundColor Yellow
    Write-Host ''
}
if ($up -and -not $ExtChanged) {
    Write-Host "  Selesai! Buka $url" -ForegroundColor Green
    Start-Process $url
} else {
    Write-Host '  Selesai! Langkah terakhir:' -ForegroundColor Green
    Write-Host '    1. Buka XAMPP Control Panel, klik Start di baris Apache.'
    Write-Host "    2. Klik dua kali ikon BisaClip di Desktop ($url)."
}
exit 0

# Update BisaClip (Windows / XAMPP) ke versi terbaru dari GitHub TANPA menyentuh data di laptop ini.
# Dijalankan oleh "Update BisaClip.bat" (folder aplikasi atau ikon di Desktop). Padanan install/update-mac.sh.
#
# Yang diganti hanya kode aplikasi. Yang tidak disentuh sama sekali (tidak dilacak git):
#   storage\    preset, library musik & SFX (daftar), API key, room, project, model AI, tool
#   previews\   file musik, SFX, gambar preset        downloads\  video hasil        avatars\  foto
# Sebelum update, pengaturan penting (file .json dan .key di storage) dicadangkan ke %USERPROFILE%\BisaClip-backup\.
# Perubahan kode lokal (kalau ada) tidak dibuang: disimpan dulu di git stash / branch cadangan.
# Opsi: -WithLibrary  ikut pasang file library tim terbaru (bisaclip-library.tar.gz di Downloads / Desktop)
#       -NoCuda       diteruskan ke installer
# Catatan: file ini sengaja hanya berisi karakter ASCII (Windows PowerShell 5.1 membaca file tanpa BOM sebagai ANSI).
param([switch]$WithLibrary, [switch]$NoCuda)

$ErrorActionPreference = 'Continue'
$App = (Resolve-Path "$PSScriptRoot\..").Path
$Branch = 'main'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Say([string]$m) { Write-Host ''; Write-Host "==> $m" -ForegroundColor Cyan }
function Ok([string]$m) { Write-Host "    [OK] $m" -ForegroundColor Green }
function Warn([string]$m) { Write-Host "    [!]  $m" -ForegroundColor Yellow }
function Fail([string]$m) { Write-Host ''; Write-Host "GAGAL: $m" -ForegroundColor Red; Write-Host '  Data kamu aman, tidak ada yang berubah.'; exit 1 }

Write-Host ''
Write-Host '  BisaClip - Update' -ForegroundColor White

# ---------- 0. Git ----------
$Git = (Get-Command git.exe -ErrorAction SilentlyContinue).Source
if (-not $Git) { $Git = @("$env:ProgramFiles\Git\cmd\git.exe", "$env:LOCALAPPDATA\Programs\Git\cmd\git.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1 }
if (-not $Git) { Fail 'Git tidak ditemukan. Pasang dulu: winget install --id Git.Git -e --source winget' }
if (-not (Test-Path "$App\.git")) { Fail "Folder ini bukan hasil git clone: $App. Clone ulang: git clone https://github.com/Moover-Studio/bisaclip-w.git" }
function G { & $Git -C $App @args }

# ---------- 1. Proses yang sedang berjalan ----------
$busy = @(Get-CimInstance Win32_Process -Filter "Name='php.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'worker\.php' })
if ($busy.Count -gt 0) {
    Warn "Ada $($busy.Count) proses BisaClip yang sedang berjalan (unduh / analisa / render)."
    Warn 'Sebaiknya tunggu sampai selesai. Update di tengah proses bisa membuat proses itu gagal.'
    $ans = Read-Host '    Tetap update sekarang? (y/N)'
    if ($ans -notmatch '^(y|ya|yes)$') { Write-Host '    Update dibatalkan. Jalankan lagi nanti.'; exit 0 }
}

# ---------- 2. Cadangan pengaturan ----------
Say 'Mencadangkan preset & pengaturan...'
$Bk = "$env:USERPROFILE\BisaClip-backup\$Stamp"
New-Item -ItemType Directory -Force $Bk | Out-Null
Get-ChildItem "$App\storage" -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.json', '.key' } | Copy-Item -Destination $Bk
# Simpan 10 cadangan terakhir saja
Get-ChildItem "$env:USERPROFILE\BisaClip-backup" -Directory | Sort-Object Name -Descending | Select-Object -Skip 10 | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Ok "Cadangan: $Bk"

# ---------- 3. Ambil kode terbaru ----------
Say 'Mengambil update dari GitHub...'
$before = (G rev-parse --short HEAD).Trim()
G fetch --quiet origin $Branch
if ($LASTEXITCODE -ne 0) { Fail 'Gagal menghubungi GitHub. Periksa internet (dan login GitHub kalau diminta), lalu coba lagi.' }
$remote = (G rev-parse --short "origin/$Branch").Trim()

# Perubahan kode lokal disimpan dulu (bisa dikembalikan dengan: git stash list / git stash pop)
if (G status --porcelain --untracked-files=no) {
    G stash push --quiet -m "sebelum-update-$Stamp" | Out-Null
    Warn "Ada perubahan kode di laptop ini: disimpan di git stash (sebelum-update-$Stamp)."
}
G checkout --quiet $Branch 2>$null
G merge --ff-only --quiet "origin/$Branch" 2>$null
if ($LASTEXITCODE -ne 0) {
    # Riwayat bercabang (ada commit lokal): simpan di branch cadangan, lalu samakan dengan GitHub
    G branch --quiet "cadangan-$Stamp"
    G reset --quiet --hard "origin/$Branch"
    Warn "Commit lokal disimpan di branch cadangan-$Stamp, kode disamakan dengan GitHub."
}
$after = (G rev-parse --short HEAD).Trim()
if ($before -eq $after) {
    Ok "Sudah versi terbaru ($after)"
} else {
    Ok "Diperbarui: $before -> $after"
    Write-Host ''
    Write-Host '    Yang baru:' -ForegroundColor White
    G log --no-merges --format='      - %s' "$before..$after" | Select-Object -First 15 | ForEach-Object { Write-Host $_ }
}

# ---------- 4. Pasang kebutuhan baru (kalau ada) & cek ----------
Say 'Memeriksa kebutuhan aplikasi...'
$a = @{}
if (-not $WithLibrary) { $a['NoLibrary'] = $true }
if ($NoCuda) { $a['NoCuda'] = $true }
& "$App\install\setup-windows.ps1" @a
exit $LASTEXITCODE

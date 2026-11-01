[CmdletBinding()]
param(
    [string]$BuildDir = "",
    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $BuildDir) { $BuildDir = Join-Path $Root "build\cmake-cli" }
if (-not $OutDir) { $OutDir = Join-Path $Root "build\cli" }

$MsysRoot = if ($env:MSYS2_ROOT) { $env:MSYS2_ROOT } else { "C:\msys64" }
$DirCandidates = @(
    (Join-Path $MsysRoot "ucrt64\bin"),
    (Join-Path $MsysRoot "mingw64\bin"),
    (Join-Path $MsysRoot "usr\bin")
) | Where-Object { Test-Path $_ }

$Gcc = $DirCandidates | ForEach-Object { Join-Path $_ "gcc.exe" } | Where-Object { Test-Path $_ } | Select-Object -First 1
$Cmake = $DirCandidates | ForEach-Object { Join-Path $_ "cmake.exe" } | Where-Object { Test-Path $_ } | Select-Object -First 1
$Ninja = $DirCandidates | ForEach-Object { Join-Path $_ "ninja.exe" } | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $Gcc) {
    throw "gcc.exe not found under $MsysRoot. Install MSYS2 UCRT64: pacman -S mingw-w64-ucrt-x86_64-gcc"
}
if (-not $Cmake) {
    throw "cmake.exe not found under $MsysRoot. Install MSYS2 UCRT64: pacman -S mingw-w64-ucrt-x86_64-cmake"
}
if (-not $Ninja) {
    throw "ninja.exe not found under $MsysRoot. Install MSYS2 UCRT64: pacman -S mingw-w64-ucrt-x86_64-ninja"
}

$env:PATH = (($DirCandidates -join ";") + ";" + $env:PATH)
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "==> Configuring LowYSwampHutFinderBase CLI (JNI off)"
& $Cmake -S $Root -B $BuildDir -G Ninja -DCMAKE_BUILD_TYPE=Release -DLYSH_JNI=OFF "-DCMAKE_C_COMPILER=$Gcc"
if ($LASTEXITCODE -ne 0) { throw "cmake configure failed" }

Write-Host "==> Building LowYSwampHutFinderBase-cli.exe"
& $Cmake --build $BuildDir --target LowYSwampHutFinderBase-cli --config Release
if ($LASTEXITCODE -ne 0) { throw "cmake build failed" }

$Exe = Join-Path $BuildDir "bin\LowYSwampHutFinderBase-cli.exe"
if (-not (Test-Path $Exe)) { throw "CLI not produced: $Exe" }
Copy-Item $Exe (Join-Path $OutDir "LowYSwampHutFinderBase-cli.exe") -Force

Write-Host "Built: $(Join-Path $OutDir 'LowYSwampHutFinderBase-cli.exe')"
Get-Item (Join-Path $OutDir "LowYSwampHutFinderBase-cli.exe") | Format-List FullName, Length, LastWriteTime

[CmdletBinding()]
param(
    [string]$BuildDir = "",
    [string]$OutDir = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $BuildDir) { $BuildDir = Join-Path $Root "build\cmake-jni" }
if (-not $OutDir) { $OutDir = Join-Path $Root "build\native" }

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

$JdkCandidates = @(
    "C:\Program Files\Java\jdk-17",
    "C:\Program Files\Java\jdk-21",
    "C:\Program Files\Eclipse Adoptium\jdk-17",
    "C:\Program Files\Eclipse Adoptium\jdk-21",
    $env:JAVA_HOME
)
$Jdk = $JdkCandidates | Where-Object {
    $_ -and (Test-Path (Join-Path $_ "include\jni.h"))
} | Select-Object -First 1
if (-not $Jdk) {
    throw "A JDK with include\jni.h was not found. Set JAVA_HOME to a JDK 17+ directory."
}
$env:JAVA_HOME = $Jdk

$env:PATH = (($DirCandidates -join ";") + ";" + $env:PATH)
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host "==> Configuring LowYSwampHutFinderBase JNI library (JDK: $Jdk)"
& $Cmake -S $Root -B $BuildDir -G Ninja -DCMAKE_BUILD_TYPE=Release -DLYSH_JNI=ON "-DCMAKE_C_COMPILER=$Gcc" "-DJAVA_HOME=$Jdk"
if ($LASTEXITCODE -ne 0) { throw "cmake configure failed" }

Write-Host "==> Building LowYSwampHutFinderBase.dll"
& $Cmake --build $BuildDir --target LowYSwampHutFinderBase_jni --config Release
if ($LASTEXITCODE -ne 0) { throw "cmake build failed" }

$Dll = Join-Path $BuildDir "bin\LowYSwampHutFinderBase.dll"
if (-not (Test-Path $Dll)) { throw "JNI DLL not produced: $Dll" }
Copy-Item $Dll (Join-Path $OutDir "LowYSwampHutFinderBase.dll") -Force

Write-Host "Built: $(Join-Path $OutDir 'LowYSwampHutFinderBase.dll')"
Get-Item (Join-Path $OutDir "LowYSwampHutFinderBase.dll") | Format-List FullName, Length, LastWriteTime

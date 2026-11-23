param(
  [string]$WhisperCppDir,
  [ValidateSet('Release', 'Debug')]
  [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$pluginRoot = Split-Path -Parent $PSScriptRoot
$configurationDir = $Configuration.ToLowerInvariant()
$buildDir = Join-Path $pluginRoot "build\web-wasm-emscripten\$configurationDir"
$assetDir = Join-Path $pluginRoot 'assets\web'

if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
  $bundledCMake = Get-ChildItem `
    'C:\Program Files (x86)\Microsoft Visual Studio' `
    -Recurse -Filter cmake.exe -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match 'CommonExtensions\\Microsoft\\CMake\\CMake\\bin' } |
    Select-Object -First 1
  if (-not $bundledCMake) { throw 'CMake was not found.' }
  $env:PATH = "$($bundledCMake.DirectoryName);$env:PATH"
}

if (-not (Get-Command ninja -ErrorAction SilentlyContinue)) {
  $bundledNinja = Get-ChildItem `
    'C:\Program Files (x86)\Microsoft Visual Studio' `
    -Recurse -Filter ninja.exe -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match 'CommonExtensions\\Microsoft\\CMake\\Ninja' } |
    Select-Object -First 1
  if (-not $bundledNinja) { throw 'Ninja was not found.' }
  $env:PATH = "$($bundledNinja.DirectoryName);$env:PATH"
}

if (-not (Get-Command emcmake -ErrorAction SilentlyContinue)) {
  throw 'Emscripten is not active. Install emsdk and run emsdk_env.ps1.'
}

& emcmake cmake -G Ninja -S (Join-Path $pluginRoot 'web') -B $buildDir `
  "-DCMAKE_BUILD_TYPE=$Configuration" `
  "-DFLUTTER_WHISPER_CPP_DIR=$WhisperCppDir" `
  -DWHISPER_WASM_SINGLE_FILE=OFF
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& cmake --build $buildDir --config $Configuration --parallel
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Copy-Item -Force (Join-Path $buildDir 'flutter_whisper.js') $assetDir
Copy-Item -Force (Join-Path $buildDir 'flutter_whisper.wasm') $assetDir
Write-Output "WebAssembly artifacts copied to $assetDir"

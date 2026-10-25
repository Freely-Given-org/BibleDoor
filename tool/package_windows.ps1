$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$versionLine = (Select-String -Path pubspec.yaml -Pattern '^version: (.+)$').Matches[0].Groups[1].Value
$version = $versionLine.Split('+')[0]
$name = "Bible-Door-$version-windows-x64"
$source = 'build/windows/x64/runner/Release'
if (!(Test-Path "$source/bibledoor.exe")) { throw 'Run flutter build windows --release first.' }
$stage = "build/releases/$name"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null
Copy-Item "$source/*" $stage -Recurse

# Application-local CRT deployment keeps the ZIP usable without an installer.
$vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
$visualStudio = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$visualStudio) { throw 'Visual Studio C++ build tools were not found.' }
$runtime = Get-ChildItem "$visualStudio/VC/Redist/MSVC/*/x64/Microsoft.VC143.CRT" -Directory |
    Sort-Object FullName -Descending | Select-Object -First 1
if (!$runtime) { throw 'The redistributable Visual C++ runtime was not found.' }
Copy-Item "$($runtime.FullName)/*.dll" $stage
foreach ($file in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'flutter_windows.dll')) {
    if (!(Test-Path "$stage/$file")) { throw "Missing runtime file: $file" }
}
Copy-Item LICENSE, NOTICE $stage
Copy-Item docs/INSTALL_WINDOWS.txt "$stage/READ-ME.txt"
Compress-Archive -Path $stage -DestinationPath "build/releases/$name.zip" -Force
Get-FileHash "build/releases/$name.zip" -Algorithm SHA256

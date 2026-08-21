# Recompiles the java/ class overrides in this folder against a given
# projectzomboid.jar and drops the .class files back in place, ready to
# be copied into the dedicated server.
#
# Usage:
#   .\rebuild.ps1 -JarPath "C:\path\to\projectzomboid.jar"
#
# See README.md in this folder for when/why you need to run this again.

param(
    [Parameter(Mandatory = $true)]
    [string]$JarPath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $JarPath)) {
    throw "jar not found: $JarPath"
}

# The game's own classes (zombie.*) are compiled with a specific --release
# version (b42 uses 25); read it straight from a class already in the jar
# instead of hardcoding it, so this script keeps working across updates.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($JarPath)
$entry = $zip.GetEntry("zombie/iso/areas/SafeHouse.class")
if (-not $entry) {
    $zip.Dispose()
    throw "zombie/iso/areas/SafeHouse.class not found inside the jar - did the package layout change?"
}
$stream = $entry.Open()
$header = New-Object byte[] 8
$stream.Read($header, 0, 8) | Out-Null
$stream.Dispose()
$zip.Dispose()
$majorVersion = ($header[6] * 256) + $header[7]
$javaRelease = $majorVersion - 44  # class file major 52 == Java 8, ... 69 == Java 25

Write-Host "Detected class file major version $majorVersion -> javac --release $javaRelease"

$root = $PSScriptRoot
$srcFiles = @(
    "zombie\iso\areas\SafeHouse.java",
    "zombie\network\packets\safehouse\SafehouseClaimPacket.java"
)

& javac --release $javaRelease -encoding UTF-8 -cp $JarPath -d $root ($srcFiles | ForEach-Object { Join-Path $root $_ })

if ($LASTEXITCODE -ne 0) {
    throw "javac failed, see errors above"
}

Write-Host "OK: recompiled into $root\zombie\..."

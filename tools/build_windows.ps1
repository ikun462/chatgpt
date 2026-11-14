param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [switch]$Export
)
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$GodotPath = (Resolve-Path $GodotPath).Path
function Invoke-Checked([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}
Invoke-Checked 'python' @("$PSScriptRoot/bootstrap.py")
Invoke-Checked 'cmake' @('-S',$ProjectRoot,'-B',"$ProjectRoot/build/windows",'-G','Visual Studio 17 2022','-A','x64')
Invoke-Checked 'cmake' @('--build',"$ProjectRoot/build/windows",'--config','Release','--parallel','4')
Invoke-Checked 'ctest' @('--test-dir',"$ProjectRoot/build/windows",'-C','Release','--output-on-failure','-V')
Invoke-Checked $GodotPath @('--headless','--path',"$ProjectRoot/godot",'--editor','--import')
Invoke-Checked $GodotPath @('--headless','--path',"$ProjectRoot/godot",'--script','res://scripts/test_extension.gd')
if ($Export) {
    New-Item -ItemType Directory -Force -Path "$ProjectRoot/dist/windows" | Out-Null
    Invoke-Checked $GodotPath @('--headless','--path',"$ProjectRoot/godot",'--export-release','Windows Desktop')
}
Write-Host 'Build and checks completed. Run the Godot project or dist/windows/SolarSandbox.exe.'

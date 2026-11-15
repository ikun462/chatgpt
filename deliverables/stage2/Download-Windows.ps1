$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$expected = '87f4a3bfbe03afb67ee2550fc7730907317428ca4712d9279cec2a57ebb9784a'
$destination = Join-Path $PSScriptRoot 'SolarSandbox-Stage2-Prototype-Windows-x64.zip'
if (Test-Path -LiteralPath $destination) {
    if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLower() -eq $expected) {
        Write-Host "Verified package already exists: $destination"
        exit 0
    }
    throw 'An existing ZIP has a different hash. Move it before running this script.'
}
$temporary = $destination + '.partial'
$output = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew)
try {
    for ($index = 1; $index -le 14; $index++) {
        $part = 'SolarSandbox-Stage2.zip.part{0:D2}' -f $index
        $url = 'https://raw.githubusercontent.com/ikun462/chatgpt/feature/stage2-solar-collisions/deliverables/stage2/' + $part
        Write-Host "Downloading $index / 14"
        $client = New-Object Net.WebClient
        try {
            $bytes = $client.DownloadData($url)
            $output.Write($bytes, 0, $bytes.Length)
        } finally { $client.Dispose() }
    }
} finally { $output.Dispose() }
if ((Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToLower() -ne $expected) {
    throw "SHA-256 mismatch. The incomplete file is retained at $temporary"
}
Move-Item -LiteralPath $temporary -Destination $destination
Write-Host "Verified: $destination"
Write-Host 'Extract the ZIP completely, then run Start-Stage2.bat.'

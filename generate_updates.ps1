$zippath = Read-Host "Enter the ROM zip file path"
$downloadurl = Read-Host "Enter the download URL"

$zippath = $zippath.Trim('"')

if (-not (Test-Path $zippath)) {
    Write-Host "Error: File not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

$filename = [System.IO.Path]::GetFileName($zippath)
$filesize = (Get-Item $zippath).Length
$timestamp = [int](Get-Date -UFormat %s)
$hash = (Get-FileHash -Path $zippath -Algorithm SHA256).Hash

$version = ($filename -split '-')[1]

Write-Host ""
Write-Host "Generated information:" -ForegroundColor Green
Write-Host "Filename: $filename"
Write-Host "Size: $filesize bytes"
Write-Host "SHA256: $hash"
Write-Host "Version: $version"
Write-Host "URL: $downloadurl"
Write-Host "Timestamp: $timestamp"
Write-Host ""

$scriptdir = $PSScriptRoot
if (-not $scriptdir) { $scriptdir = "." }

$json = @"
{
  "response": [
    {
      "datetime": "$timestamp",
      "filename": "$filename",
      "id": "$hash",
      "romtype": "OFFICIAL",
      "size": $filesize,
      "url": "$downloadurl",
      "version": $version
    }
  ]
}
"@

$json | Out-File -FilePath "$scriptdir\updates.json" -Encoding utf8

Write-Host "updates.json has been created successfully!" -ForegroundColor Green
Read-Host "Press Enter to exit"

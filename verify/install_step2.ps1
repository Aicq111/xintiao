param([string]$Dir)
$log = Join-Path $Dir 'install_log.txt'
"=== start $(Get-Date) ===" | Out-File $log -Encoding utf8
"installing from: $Dir" | Out-File $log -Append -Encoding utf8

$iTunes = Join-Path $Dir 'iTunes64Setup.exe'
$iCloud = Join-Path $Dir 'iCloudSetup.exe'
$altMsi = Join-Path $Dir 'AltInstaller\AltInstaller.msi'

$p1 = Start-Process -FilePath $iTunes -ArgumentList '/quiet','/norestart' -Wait -PassThru
"iTunes exit: $($p1.ExitCode)" | Out-File $log -Append -Encoding utf8

$p2 = Start-Process -FilePath $iCloud -ArgumentList '/quiet','/norestart' -Wait -PassThru
"iCloud exit: $($p2.ExitCode)" | Out-File $log -Append -Encoding utf8

$p3 = Start-Process -FilePath 'msiexec.exe' -ArgumentList '/i',"`"$altMsi`"",'/qn','/norestart' -Wait -PassThru
"AltServer exit: $($p3.ExitCode)" | Out-File $log -Append -Encoding utf8

Start-Sleep -Seconds 3
$checks = @(
  'C:\Program Files\iTunes\iTunes.exe',
  'C:\Program Files (x86)\AltServer\AltServer.exe',
  'C:\Program Files\AltServer\AltServer.exe',
  'C:\Program Files (x86)\Common Files\Apple\Mobile Device Support\AppleMobileDeviceService.exe',
  'C:\Program Files\Common Files\Apple\Mobile Device Support\AppleMobileDeviceService.exe'
)
foreach ($c in $checks) {
  "check $c => $(Test-Path $c)" | Out-File $log -Append -Encoding utf8
}
"=== end ===" | Out-File $log -Append -Encoding utf8

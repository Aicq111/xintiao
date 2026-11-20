param([string]$Dir)
$log = Join-Path $Dir 'icloud_log.txt'
"=== start $(Get-Date) ===" | Out-File $log -Encoding utf8
$iCloud = Join-Path $Dir 'iCloudSetup.exe'
$p = Start-Process -FilePath $iCloud -ArgumentList '/qn','REBOOT=ReallySuppress' -Wait -PassThru
"iCloud exit: $($p.ExitCode)" | Out-File $log -Append -Encoding utf8
Start-Sleep -Seconds 3
$checks = @(
  'C:\Program Files (x86)\Common Files\Apple\Apple Application Support\APSDaemon.exe',
  'C:\Program Files\Common Files\Apple\Apple Application Support\APSDaemon.exe',
  'C:\Program Files (x86)\Common Files\Apple\Internet Services\iCloudServices.exe',
  'C:\Program Files\WindowsApps\AppleInc.iCloud*'
)
foreach ($c in $checks) {
  "check $c => $(Test-Path $c)" | Out-File $log -Append -Encoding utf8
}
"=== end ===" | Out-File $log -Append -Encoding utf8

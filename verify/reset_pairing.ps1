param([string]$LogDir)
$log = Join-Path $LogDir 'pairing_log.txt'
"=== start $(Get-Date) ===" | Out-File $log -Encoding utf8

Stop-Service -Name 'Apple Mobile Device Service' -Force -ErrorAction SilentlyContinue
"service stopped" | Out-File $log -Append -Encoding utf8

$lockdown = 'C:\ProgramData\Apple\Lockdown'
if (Test-Path $lockdown) {
    Get-ChildItem $lockdown -File -ErrorAction SilentlyContinue | ForEach-Object {
        "deleting $($_.Name)" | Out-File $log -Append -Encoding utf8
        Remove-Item $_.FullName -Force
    }
    "pairing records cleared" | Out-File $log -Append -Encoding utf8
} else {
    "no lockdown folder" | Out-File $log -Append -Encoding utf8
}

Start-Service -Name 'Apple Mobile Device Service' -ErrorAction SilentlyContinue
"service restarted" | Out-File $log -Append -Encoding utf8
"=== end ===" | Out-File $log -Append -Encoding utf8

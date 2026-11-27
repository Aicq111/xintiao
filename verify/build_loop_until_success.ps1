# Auto retry build loop until success (ASCII only; paths derived from script location)
$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent $PSScriptRoot
$out = Join-Path $repo 'build_status.txt'
$headers = @{ 'User-Agent' = 'xintiao-check' }
$env:Path = 'C:\Program Files\Git\cmd;C:\Program Files\Git\bin;' + $env:Path
Set-Location $repo

function Get-LatestRuns {
  try {
    return (Invoke-RestMethod -Uri 'https://api.github.com/repos/Aicq111/xintiao/actions/runs?per_page=2' -Headers $headers -TimeoutSec 60).workflow_runs
  } catch { return $null }
}

$deadline = (Get-Date).AddHours(4)
$lastSha = ''
while ((Get-Date) -lt $deadline) {
  $runs = Get-LatestRuns
  if ($runs) {
    $r = $runs[0]
    if ($r.status -eq 'completed') {
      if ($r.conclusion -eq 'success') {
        Set-Content -Path $out -Value ("SUCCESS " + $r.html_url) -Encoding UTF8
        Write-Host ("SUCCESS " + $r.html_url)
        break
      }
      if ($r.head_sha -ne $lastSha) {
        $lastSha = $r.head_sha
        git commit --allow-empty -m 'auto retry (queue)' | Out-Null
        git push origin main 2>&1 | Out-Null
        Write-Host ("retry pushed at " + (Get-Date -Format 'HH:mm:ss') + " for run #" + $r.run_number)
      }
    }
  }
  Start-Sleep -Seconds 180
}
if ((Get-Date) -ge $deadline) {
  Set-Content -Path $out -Value 'TIMEOUT' -Encoding UTF8
  Write-Host 'TIMEOUT'
}

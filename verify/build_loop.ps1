# Autonomous build loop: watch runs, save annotations on real failure, retry on queued-cancel.
# ASCII only (Windows PowerShell 5.1 reads UTF-8 without BOM as GBK).
$env:Path = 'C:\Program Files\Git\cmd;C:\Program Files\Git\bin;' + $env:Path
Set-Location (Split-Path $PSScriptRoot -Parent)
$h = @{ 'User-Agent' = 'xintiao-loop' }

for ($attempt = 1; $attempt -le 6; $attempt++) {
    Write-Host "=== attempt $attempt ==="
    git commit --allow-empty -m "auto retry $attempt" | Out-Null
    git push origin main 2>&1 | Select-Object -Last 1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "push failed, wait and continue"
        Start-Sleep -Seconds 60
        continue
    }
    $sha = (git rev-parse HEAD).Trim()
    Write-Host "watching sha $sha"

    for ($i = 1; $i -le 12; $i++) {
        Start-Sleep -Seconds 150
        try {
            $runs = Invoke-RestMethod -Uri 'https://api.github.com/repos/Aicq111/xintiao/actions/runs?per_page=10' -Headers $h -TimeoutSec 60
            $run = $runs.workflow_runs | Where-Object { $_.head_sha -eq $sha } | Select-Object -First 1
            if (-not $run) { Write-Host "run not found yet"; continue }
            Write-Host ("poll{0}: #{1} {2}/{3}" -f $i, $run.run_number, $run.status, $run.conclusion)

            if ($run.status -eq 'completed') {
                $jobs = Invoke-RestMethod -Uri "https://api.github.com/repos/Aicq111/xintiao/actions/runs/$($run.id)/jobs" -Headers $h -TimeoutSec 60
                $anySuccess = $false
                $anyRealFail = $false
                $allCancelled = $true
                foreach ($j in $jobs.jobs) {
                    Write-Host ("job {0} {1} steps={2}" -f $j.id, $j.conclusion, $j.steps.Count)
                    if ($j.conclusion -eq 'success') { $anySuccess = $true }
                    if ($j.conclusion -notin @('cancelled', 'success', 'skipped')) { $anyRealFail = $true }
                    if ($j.conclusion -ne 'cancelled') { $allCancelled = $false }
                }
                if ($anySuccess) {
                    Write-Host 'SUCCESS'
                    exit 0
                }
                if ($anyRealFail) {
                    Write-Host "REAL FAIL run#$($run.run_number) sha=$sha"
                    $out = @()
                    try {
                        $cr = Invoke-RestMethod -Uri "https://api.github.com/repos/Aicq111/xintiao/commits/$sha/check-runs" -Headers $h -TimeoutSec 60
                        $failed = $cr.check_runs | Where-Object { $_.conclusion -eq 'failure' }
                        foreach ($f in $failed) {
                            if ($f.output.annotations_count -gt 0) {
                                $ann = Invoke-RestMethod -Uri "https://api.github.com/repos/Aicq111/xintiao/check-runs/$($f.id)/annotations" -Headers $h -TimeoutSec 60
                                foreach ($a in $ann) { $out += $a.message }
                            }
                        }
                        $out | Out-File -FilePath (Join-Path $PSScriptRoot 'annotations.txt') -Encoding utf8
                        Write-Host "annotations saved: $($out.Count) lines"
                    } catch {
                        Write-Host "annotation fetch failed: $($_.Exception.Message)"
                    }
                    exit 2
                }
                if ($allCancelled) {
                    Write-Host 'all jobs queued-cancelled, next attempt'
                    break
                }
            }
        } catch {
            Write-Host "poll failed: $($_.Exception.Message)"
        }
    }
    Write-Host "attempt $attempt window over"
}
Write-Host 'all attempts exhausted'
exit 1

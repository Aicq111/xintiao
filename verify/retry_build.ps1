# Auto-retry build with multi-job verdict: any success -> exit 0; any real fail -> exit 2; all cancelled -> retry
# No non-ASCII characters in this file (Windows PowerShell 5.1 reads UTF-8 without BOM as GBK).
$env:Path = 'C:\Program Files\Git\cmd;C:\Program Files\Git\bin;' + $env:Path
Set-Location (Split-Path $PSScriptRoot -Parent)
$headers = @{ 'User-Agent' = 'xintiao-retry' }

for ($attempt = 1; $attempt -le 6; $attempt++) {
    Write-Host "=== attempt $attempt ==="
    git commit --allow-empty -m "retry build attempt $attempt" | Out-Null
    git push origin main 2>&1 | Select-Object -Last 1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "push failed, skip this attempt"
        Start-Sleep -Seconds 60
        continue
    }

    for ($i = 1; $i -le 12; $i++) {
        Start-Sleep -Seconds 120
        try {
            $runs = Invoke-RestMethod -Uri 'https://api.github.com/repos/Aicq111/xintiao/actions/runs?per_page=1' -Headers $headers -TimeoutSec 60
            $latest = $runs.workflow_runs[0]
            Write-Host ("a{0} poll{1}: #{2} {3}/{4}" -f $attempt, $i, $latest.run_number, $latest.status, $latest.conclusion)

            if ($latest.status -eq 'completed') {
                try {
                    $jobs = Invoke-RestMethod -Uri "https://api.github.com/repos/Aicq111/xintiao/actions/runs/$($latest.id)/jobs" -Headers $headers -TimeoutSec 60
                    $anySuccess = $false
                    $anyRealFail = $false
                    $allCancelled = $true
                    foreach ($j in $jobs.jobs) {
                        Write-Host ("job id={0} conclusion={1} steps={2}" -f $j.id, $j.conclusion, $j.steps.Count)
                        if ($j.conclusion -eq 'success') { $anySuccess = $true }
                        if ($j.conclusion -notin @('cancelled', 'success', 'skipped')) { $anyRealFail = $true }
                        if ($j.conclusion -ne 'cancelled') { $allCancelled = $false }
                    }
                    if ($anySuccess) {
                        Write-Host 'SUCCESS'
                        exit 0
                    }
                    if ($anyRealFail) {
                        Write-Host 'REAL FAILURE, steps of failed job:'
                        foreach ($j in $jobs.jobs) {
                            if ($j.conclusion -notin @('cancelled', 'success', 'skipped')) {
                                foreach ($st in $j.steps) {
                                    Write-Host ("  step: {0} -> {1}" -f $st.name, $st.conclusion)
                                }
                            }
                        }
                        exit 2
                    }
                    if ($allCancelled) {
                        Write-Host 'all jobs queued-cancelled, retrying'
                        break
                    }
                } catch {
                    Write-Host "jobs query failed: $($_.Exception.Message)"
                }
            }
        } catch {
            Write-Host "poll failed (rate-limit?): $($_.Exception.Message)"
        }
    }
    Write-Host "attempt $attempt window over, sleep 25min before next"
    Start-Sleep -Seconds 1500
}
Write-Host 'all attempts exhausted'
exit 1

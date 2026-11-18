# 轮询 GitHub Actions 构建状态，直到最新一次运行结束
$ErrorActionPreference = 'Continue'
$headers = @{ 'User-Agent' = 'xintiao-poll' }
$maxLoops = 45

for ($i = 1; $i -le $maxLoops; $i++) {
    try {
        $runs = Invoke-RestMethod -Uri 'https://api.github.com/repos/Aicq111/xintiao/actions/runs?per_page=3' -Headers $headers -TimeoutSec 60
        $latest = $runs.workflow_runs | Select-Object -First 1
        Write-Host ("poll {0}: #{1} status={2} conclusion={3}" -f $i, $latest.run_number, $latest.status, $latest.conclusion)
        if ($latest.status -eq 'completed') {
            Write-Host "DONE run#$($latest.run_number) conclusion=$($latest.conclusion)"
            try {
                $jobs = Invoke-RestMethod -Uri "https://api.github.com/repos/Aicq111/xintiao/actions/runs/$($latest.id)/jobs" -Headers $headers -TimeoutSec 60
                foreach ($j in $jobs.jobs) {
                    Write-Host ("job name={0} conclusion={1}" -f $j.name, $j.conclusion)
                    foreach ($st in $j.steps) {
                        Write-Host ("  step: {0} -> {1}" -f $st.name, $st.conclusion)
                    }
                }
            } catch {
                Write-Host "jobs 查询失败: $($_.Exception.Message)"
            }
            break
        }
    } catch {
        Write-Host "poll 失败: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds 30
}

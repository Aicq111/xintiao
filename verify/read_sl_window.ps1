# Read text from Sideloadly window via UI Automation (ASCII only)
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, 'Sideloadly! v0.72')
$win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
if (-not $win) { Write-Host 'window not found'; exit 1 }
Write-Host 'window found'
$all = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
$out = @()
foreach ($e in $all) {
    $n = $e.Current.Name
    if ($n -and $n.Trim()) { $out += $n }
}
$out | Where-Object { $_ -match 'fail|error|Error|install|Install|Guru|Login|password|Password|lockdown|trust|Trust|success|Success|Failed' } | Select-Object -Unique | ForEach-Object { Write-Host $_ }
Write-Host "--- total named elements: $($out.Count)"

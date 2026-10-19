<#
.SYNOPSIS
  Run a build command on GitHub Actions and, if it fails, report the compiler errors as an
  annotation on the run (Actions ▸ the run ▸ Annotations), where they can be read without
  downloading the whole log.

.EXAMPLE
  pwsh packaging/vidora/ci-run.ps1 -Title Build -Command "pwsh -NoProfile -File packaging\vidora\package.ps1 -BuildOnly"
#>
param(
  [Parameter(Mandatory)] [string] $Title,
  [Parameter(Mandatory)] [string] $Command
)
$log = Join-Path (Get-Location) ("ci-" + ($Title -replace '\W', '-') + ".log")
cmd /c "$Command > `"$log`" 2>&1"
$code = $LASTEXITCODE
Get-Content $log
if ($code -ne 0) {
  $hits = Select-String -Path $log -Pattern '^\s*error|error\[E|panicked|failed|cannot find|^\s*Error|Exception' -Context 0, 8 | Select-Object -First 25
  $lines = foreach ($h in $hits) { $h.Line; $h.Context.PostContext; '' }
  $tail = Get-Content $log -Tail 60
  $msg = (@($lines) + '---- last lines ----' + @($tail)) -join "`n"
  if ($msg.Length -gt 30000) { $msg = $msg.Substring(0, 30000) }
  $esc = $msg.Replace('%', '%25').Replace("`r", '').Replace("`n", '%0A')
  Write-Output "::error title=$Title failed::$esc"
  exit $code
}

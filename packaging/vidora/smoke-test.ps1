<#
.SYNOPSIS
  Start the packaged VIDORA.exe the way a user does and check that its window comes up.

.DESCRIPTION
  Unzips the portable package into a temp folder, starts VIDORA.exe with the control channel
  (--control), and waits for the running app to answer a UI request. Then it reports what
  happened as an annotation on the GitHub Actions run: the outcome, the process state and the
  app's own log (data\Logs\filmcraft.log, plus any crash log), so a start-up failure on Windows
  can be read without the machine. Exits 1 when the window never came up.

.EXAMPLE
  pwsh packaging/vidora/smoke-test.ps1 -Zip dist\VIDORA-0.9.0-windows-x64-portable.zip
  pwsh packaging/vidora/smoke-test.ps1 -Zip filmcraft-0.9.0-windows-x64-portable.zip -Exe filmcraft.exe -Title "FilmCraft (upstream)"
#>
param(
  [Parameter(Mandatory)] [string] $Zip,
  [string] $Exe = 'VIDORA.exe',
  [string] $Title = 'VIDORA',
  [int] $Port = 47931,
  [int] $Seconds = 150
)
$ErrorActionPreference = 'Stop'
$dir = Join-Path ([IO.Path]::GetTempPath()) ('smoke-' + ($Title -replace '\W', '-'))
Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
Expand-Archive -Path $Zip -DestinationPath $dir
$exe = Get-ChildItem -Path $dir -Recurse -Filter $Exe | Select-Object -First 1
if (-not $exe) { Write-Output "::error title=Smoke test $Title::$Exe is not in $Zip"; exit 1 }
$data = Join-Path $exe.DirectoryName 'data'

$env:RUST_BACKTRACE = '1'
$p = Start-Process -FilePath $exe.FullName -ArgumentList '--control', "$Port" -WorkingDirectory $exe.DirectoryName -PassThru
$null = $p.Handle  # keeps the handle, so ExitCode is readable after the process exits
$reply = $null
$started = Get-Date
while (((Get-Date) - $started).TotalSeconds -lt $Seconds) {
  Start-Sleep -Milliseconds 1000
  if ($p.HasExited) { break }
  try {
    $client = [System.Net.Sockets.TcpClient]::new('127.0.0.1', $Port)
    $client.ReceiveTimeout = 30000
    $stream = $client.GetStream()
    $writer = [IO.StreamWriter]::new($stream)
    $reader = [IO.StreamReader]::new($stream)
    $writer.WriteLine('{"id": 1, "method": "ui.inspect"}')
    $writer.Flush()
    $reply = $reader.ReadLine()
    $client.Close()
    if ($reply) { break }
  } catch {
    # not listening yet
  }
}
$elapsed = [int]((Get-Date) - $started).TotalSeconds
$alive = -not $p.HasExited
$exitCode = if ($alive) { 'still running' } else { '0x{0:X8}' -f $p.ExitCode }
if ($alive) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }

$ok = [bool]$reply -and ($reply -match '"ok"\s*:\s*true')
$report = @(
  "Result: $(if ($ok) { 'the window came up and answered' } else { 'the window did NOT come up' }) after $elapsed s",
  "Process: $exitCode",
  "Reply: $(if ($reply) { $reply.Substring(0, [Math]::Min(400, $reply.Length)) } else { '(none)' })",
  ''
)
foreach ($log in Get-ChildItem -Path (Join-Path $data 'Logs') -Filter '*.log' -ErrorAction SilentlyContinue) {
  $report += "==== $($log.Name)"
  $report += Get-Content $log.FullName -Tail 120
}
foreach ($f in Get-ChildItem -Path $data -Filter 'graphics-start*' -Recurse -File -ErrorAction SilentlyContinue) {
  $report += "==== $($f.Name)"
  $report += Get-Content $f.FullName -ErrorAction SilentlyContinue
}
$text = ($report -join "`n")
Write-Output $text
if ($text.Length -gt 60000) { $text = $text.Substring(0, 60000) }
$esc = $text.Replace('%', '%25').Replace("`r", '').Replace("`n", '%0A')
$level = if ($ok) { 'notice' } else { 'error' }
Write-Output "::$level title=Smoke test $Title::$esc"
if (-not $ok) { exit 1 }

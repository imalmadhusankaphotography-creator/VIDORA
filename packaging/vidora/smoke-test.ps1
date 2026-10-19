<#
.SYNOPSIS
  Start the packaged VIDORA.exe the way a user does and check that its window comes up.

.DESCRIPTION
  Unzips the portable package into a temp folder, starts VIDORA.exe with the control channel
  (--control), and waits for the running app to answer a UI request. Then it reports what
  happened as annotations on the GitHub Actions run: the outcome, the process state and the
  app's own log (data\Logs\filmcraft.log, plus any crash log), so a start-up failure on Windows
  can be read without the machine. Exits 1 when the window never came up.

.EXAMPLE
  pwsh packaging/vidora/smoke-test.ps1 -Zip dist\VIDORA-0.9.0-windows-x64-portable.zip
  pwsh packaging/vidora/smoke-test.ps1 -Zip filmcraft-0.9.0-windows-x64-portable.zip -Exe filmcraft.exe -Title "FilmCraft upstream"
#>
param(
  [Parameter(Mandatory)] [string] $Zip,
  [string] $Exe = 'VIDORA.exe',
  [string] $Title = 'VIDORA',
  [int] $Port = 47931,
  [int] $Seconds = 150
)

# One annotation per chunk: GitHub drops a message that is too long, and keeps at most 10 per step.
function Write-Annotation([string] $Level, [string] $Text) {
  $chunk = 3000
  $parts = [Math]::Min(8, [Math]::Ceiling($Text.Length / $chunk))
  if ($parts -lt 1) { $parts = 1 }
  for ($i = 0; $i -lt $parts; $i++) {
    $start = $i * $chunk
    $part = if ($start -lt $Text.Length) { $Text.Substring($start, [Math]::Min($chunk, $Text.Length - $start)) } else { '' }
    $esc = $part.Replace('%', '%25').Replace("`r", '').Replace("`n", '%0A').Replace('::', ': :')
    Write-Output "::$Level title=Smoke test $Title ($($i + 1)/$parts)::$esc"
  }
}

$report = New-Object System.Collections.Generic.List[string]
$ok = $false
try {
  $dir = Join-Path ([IO.Path]::GetTempPath()) ('smoke-' + ($Title -replace '\W', '-'))
  Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
  Expand-Archive -Path $Zip -DestinationPath $dir -Force
  $exeFile = Get-ChildItem -Path $dir -Recurse -Filter $Exe | Select-Object -First 1
  if (-not $exeFile) { throw "$Exe is not in $Zip" }
  $data = Join-Path $exeFile.DirectoryName 'data'
  $report.Add("Executable: $($exeFile.FullName) ($([int]($exeFile.Length / 1MB)) MB)")
  $report.Add("Portable marker: $(Test-Path (Join-Path $exeFile.DirectoryName 'portable.txt'))")
  $report.Add("dxcompiler.dll beside it: $(Test-Path (Join-Path $exeFile.DirectoryName 'dxcompiler.dll'))")

  $env:RUST_BACKTRACE = '1'
  $p = Start-Process -FilePath $exeFile.FullName -ArgumentList '--control', "$Port" -WorkingDirectory $exeFile.DirectoryName -PassThru
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
  $state = if ($alive) { 'still running' } else { "exited, code $($p.ExitCode)" }
  if ($alive) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue; Start-Sleep -Seconds 2 }
  $ok = [bool]$reply -and ($reply -match '"ok"\s*:\s*true')
  $report.Insert(0, "Result: $(if ($ok) { 'the window came up and answered' } else { 'the window did NOT come up' }) after $elapsed s; process $state")
  $report.Add("Reply: $(if ($reply) { $reply.Substring(0, [Math]::Min(300, $reply.Length)) } else { '(none)' })")
  foreach ($log in Get-ChildItem -Path (Join-Path $data 'Logs') -Filter '*.log' -ErrorAction SilentlyContinue) {
    $report.Add("==== $($log.Name)")
    foreach ($line in (Get-Content -LiteralPath $log.FullName -Tail 60 -ErrorAction SilentlyContinue)) { $report.Add($line) }
  }
  foreach ($f in Get-ChildItem -Path $data -Filter 'graphics-start*' -Recurse -File -ErrorAction SilentlyContinue) {
    $report.Add("==== $($f.Name): $(Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue)")
  }
} catch {
  $report.Insert(0, "Result: the smoke test itself failed: $($_.Exception.Message)")
  $report.Add("$($_.ScriptStackTrace)")
}
$text = ($report -join "`n")
Write-Output $text
Write-Annotation $(if ($ok) { 'notice' } else { 'error' }) $text
if (-not $ok) { exit 1 }

# Sipario - vardiya senkron kontrolu (Claude Code SessionStart hook'u)
#
# Iki gelistirici nobetlese calisiyor. Oturum acilirken:
#  - origin'den fetch edilir,
#  - depo GERIDEYSE ve agac temizse otomatik fast-forward pull yapilir
#    (arkadasinin isi gelmeden calismaya baslamak sapma/merge cehennemi demek),
#  - pull otomatik yapilamiyorsa (kirli agac / dallar ayrismis) hem kullaniciya
#    hem Claude'a acik uyari verilir,
#  - push edilmemis commit varsa hatirlatilir.
# Cikis kodu her zaman 0; ag yoksa sessizce gecilir.

$ErrorActionPreference = 'Continue'

function EmitBoth([string]$userMsg, [string]$ctx) {
  $o = @{}
  if ($userMsg) { $o.systemMessage = $userMsg }
  if ($ctx) {
    $o.hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $ctx }
  }
  if ($o.Count -gt 0) { $o | ConvertTo-Json -Compress -Depth 4 }
}

if ([Console]::IsInputRedirected) { try { [Console]::In.ReadToEnd() | Out-Null } catch { } }

$root = $env:CLAUDE_PROJECT_DIR
if (-not $root -or -not (Test-Path $root)) {
  $root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
}
Set-Location $root

git rev-parse --is-inside-work-tree 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { exit 0 }

git fetch --quiet origin 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  EmitBoth 'Vardiya senkronu: GitHub''a ulasilamadi, kontrol atlandi.' ''
  exit 0
}

$upstream = (git rev-parse --abbrev-ref '@{u}' 2>$null | Out-String).Trim()
if (-not $upstream) { exit 0 }

$behind = [int](git rev-list --count "HEAD..$upstream" 2>$null | Out-String).Trim()
$ahead  = [int](git rev-list --count "$upstream..HEAD" 2>$null | Out-String).Trim()
$dirty  = git status --porcelain 2>$null

if ($behind -eq 0 -and $ahead -eq 0) { exit 0 }  # senkron, sessiz gec

$msgs = New-Object System.Collections.Generic.List[string]
$ctx  = New-Object System.Collections.Generic.List[string]

if ($behind -gt 0) {
  if (-not $dirty -and $ahead -eq 0) {
    git merge --ff-only $upstream 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
      $msgs.Add("Vardiya senkronu: $behind yeni commit cekildi ($upstream). Diger gelistiricinin isi yerel kopyaya alindi.")
      $ctx.Add("Depo oturum basinda $behind commit gerideydi; otomatik fast-forward pull yapildi. Yeni gelen isi anlamak icin once PLAN.md guncel durumunu ve 'git log' son commitleri oku.")
    } else {
      $msgs.Add("DIKKAT: depo $behind commit geride ve otomatik pull yapilamadi. Elle senkron gerekli.")
      $ctx.Add("Depo $behind commit geride, ff-pull basarisiz (dallar ayrismis olabilir). Kullaniciyla birlikte senkronla; is yapmaya baslamadan once cozulmeli.")
    }
  } else {
    $neden = 'agac kirli'
    if ($ahead -gt 0) { $neden = 'yerel push edilmemis commit var' }
    $msgs.Add("DIKKAT: depo $behind commit geride ($neden). Ise baslamadan senkronla.")
    $ctx.Add("Depo $behind commit geride ama otomatik pull guvenli degil ($neden). Ilk is olarak durumu kullaniciya soyle ve senkronu birlikte coz.")
  }
}

if ($ahead -gt 0) {
  $msgs.Add("Not: push edilmemis $ahead commit var - vardiya sonunda push gitmis olmali.")
  $ctx.Add("Yerelde push edilmemis $ahead commit var; uygun ilk firsatta push et.")
}

EmitBoth ($msgs -join ' ') ($ctx -join ' ')
exit 0

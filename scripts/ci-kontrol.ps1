param (
    [Alias("t", "Watch", "w")]
    [switch]$Takip,

    [Alias("o", "Open")]
    [switch]$Web
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Show-Header {
    Clear-Host
    Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " 🚀 SIPARIO CI/CD & SAHA APK DURUM PANELİ" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host " Zaman: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
    Write-Host ""
}

function Get-CIData {
    try {
        $jsonStr = gh run list --limit 6 --json databaseId,name,headBranch,status,conclusion,event,createdAt,updatedAt,headSha,displayTitle
        if ($jsonStr) {
            return ($jsonStr | ConvertFrom-Json)
        }
    } catch {
        $null
    }
    return $null
}

function Get-ReleaseInfo {
    try {
        $ts = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        $url = "https://github.com/tnyligokhan/sipario/releases/download/saha/surum.json?t=" + $ts
        return (Invoke-RestMethod -Uri $url -TimeoutSec 5 -ErrorAction Stop)
    } catch {
        $null
    }
    return $null
}

function Render-Status {
    $runs = Get-CIData
    $release = Get-ReleaseInfo

    if ($null -eq $runs -or $runs.Count -eq 0) {
        Write-Host " ❌ GitHub Actions verisi alınamadı! (gh CLI yetkisi veya internet bağlantısını kontrol edin)" -ForegroundColor Red
        return $false
    }

    $sahaRun = $null
    foreach ($r in $runs) {
        if ($r.name -eq 'saha-apk') {
            $sahaRun = $r
            break
        }
    }

    # ── 1. SAHA APK (MOBİL İŞ AKIŞI) ──────────────────────────────────
    Write-Host "📱 SAHA APK (MOBİL İŞ AKIŞI)" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

    if ($sahaRun) {
        $statusStr = $sahaRun.status
        $conclusion = $sahaRun.conclusion

        if ($statusStr -eq 'in_progress') {
            Write-Host "  Durum        : " -NoNewline
            Write-Host " 🟡 DERLENİYOR (In Progress) " -ForegroundColor Black -BackgroundColor Yellow
        } elseif ($statusStr -eq 'queued') {
            Write-Host "  Durum        : " -NoNewline
            Write-Host " ⏳ SIRADA (Queued) " -ForegroundColor Black -BackgroundColor DarkYellow
        } elseif ($conclusion -eq 'success') {
            Write-Host "  Durum        : " -NoNewline
            Write-Host " ✅ BAŞARILI (APK Güncellendi) " -ForegroundColor Black -BackgroundColor Green
        } elseif ($conclusion -eq 'failure') {
            Write-Host "  Durum        : " -NoNewline
            Write-Host " ❌ BAŞARISIZ (Hata Alındı) " -ForegroundColor White -BackgroundColor Red
        } else {
            Write-Host "  Durum        : $statusStr ($conclusion)" -ForegroundColor DarkCyan
        }

        Write-Host "  Son Commit   : $($sahaRun.displayTitle)" -ForegroundColor White
        Write-Host "  Dal (Branch) : $($sahaRun.headBranch)" -ForegroundColor DarkCyan
        Write-Host "  Koşum ID     : $($sahaRun.databaseId)" -ForegroundColor DarkGray
        Write-Host "  Detay URL    : https://github.com/tnyligokhan/sipario/actions/runs/$($sahaRun.databaseId)" -ForegroundColor Blue

        # Alt görevler
        if ($statusStr -eq 'in_progress' -or $conclusion -eq 'failure') {
            try {
                $runId = $sahaRun.databaseId
                $jobsJson = gh run view $runId --json jobs
                if ($jobsJson) {
                    $jobsObj = $jobsJson | ConvertFrom-Json
                    if ($jobsObj.jobs) {
                        Write-Host ""
                        Write-Host "  Alt Görevler:" -ForegroundColor DarkYellow
                        foreach ($j in $jobsObj.jobs) {
                            $jStat = "⏳ Bekliyor"
                            if ($j.status -eq 'in_progress') { $jStat = "🟡 Çalışıyor" }
                            elseif ($j.conclusion -eq 'success') { $jStat = "✅ Tamamlandı" }
                            elseif ($j.conclusion -eq 'failure') { $jStat = "❌ Hata" }
                            Write-Host "   • $($j.name) : $jStat" -ForegroundColor White
                        }
                    }
                }
            } catch {
                $null
            }
        }
    } else {
        Write-Host "  saha-apk koşumu bulunamadı." -ForegroundColor DarkGray
    }

    # ── 2. YAYINDAKİ SÜRÜM & APK BİLGİSİ ────────────────────────────────
    Write-Host ""
    Write-Host "📦 YAYINDAKİ SAHA SÜRÜMÜ (GitHub Releases)" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    if ($release) {
        Write-Host "  Sürüm Adı    : $($release.ad) ($($release.kod))" -ForegroundColor Green
        Write-Host "  Yapım No     : $($release.yapim)" -ForegroundColor White
        Write-Host "  Yayın Tarihi : $($release.tarih)" -ForegroundColor DarkCyan
        Write-Host "  Release Linki: https://github.com/tnyligokhan/sipario/releases/tag/saha" -ForegroundColor Blue
        Write-Host "  APK İndir    : https://github.com/tnyligokhan/sipario/releases/download/saha/sipario-saha-arm64.apk" -ForegroundColor Cyan
    } else {
        Write-Host "  Yayındaki sürüm bilgisine ulaşılamadı veya henüz release oluşmadı." -ForegroundColor DarkGray
    }

    # ── 3. SON KOŞUMLAR LİSTESİ ─────────────────────────────────────────
    Write-Host ""
    Write-Host "📋 SON İŞ AKIŞLARI" -ForegroundColor Yellow
    Write-Host "────────────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    $counter = 0
    foreach ($r in $runs) {
        if ($counter -ge 4) { break }
        $icon = "⚪"
        if ($r.status -eq 'in_progress') { $icon = "🟡" }
        elseif ($r.conclusion -eq 'success') { $icon = "✅" }
        elseif ($r.conclusion -eq 'failure') { $icon = "❌" }

        $t = [DateTime]::Parse($r.createdAt).ToLocalTime().ToString("HH:mm:ss")
        $namePadded = $r.name.PadRight(12)
        $branchPadded = $r.headBranch.PadRight(5)
        Write-Host "  $icon [$t] $namePadded ($branchPadded) : $($r.displayTitle)" -ForegroundColor DarkGray
        $counter++
    }

    Write-Host "════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    if ($Web -and $sahaRun) {
        Start-Process "https://github.com/tnyligokhan/sipario/actions/runs/$($sahaRun.databaseId)"
    }

    if ($sahaRun) {
        return ($sahaRun.status -eq 'in_progress' -or $sahaRun.status -eq 'queued')
    }
    return $false
}

# ── ÇALIŞTIRMA MANTIĞI ───────────────────────────────────────────────
if ($Takip) {
    do {
        Show-Header
        $devamEdiyor = Render-Status
        if ($devamEdiyor) {
            Write-Host "  ⏳ Derleme devam ediyor... (4 sn sonra yenilenecek - Çıkış için Ctrl+C)" -ForegroundColor DarkYellow
            Start-Sleep -Seconds 4
        } else {
            Write-Host "  🎉 İş akışı tamamlandı!" -ForegroundColor Green
            break
        }
    } while ($true)
} else {
    Show-Header
    $null = Render-Status
    Write-Host "  İpucu: Canlı takip için '.\ci.bat -t' veya '.\ci.ps1 -t' çalıştırabilirsiniz." -ForegroundColor DarkGray
    Write-Host ""
}

param([switch]$AutoInstall)

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ReportsDir  = Join-Path $ProjectRoot "assets\reports"
$ImagesDir   = Join-Path $ProjectRoot "assets\images"
$ScriptJs    = Join-Path $PSScriptRoot "extract-pdf-pages.js"
$EdgePath    = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

$PageMapping = @(
    @{ Pdf = "SentimentAnalysis.pdf";  Page = 1; Output = "reddits_sentiment_timeline_counts.png"           }
    @{ Pdf = "SentimentAnalysis.pdf";  Page = 2; Output = "reddits_sentiment_histogram_counts.png"          }
    @{ Pdf = "PopularityAnalysis.pdf"; Page = 1; Output = "reddits_popularity_timeline_counts.png"          }
    @{ Pdf = "PopularityAnalysis.pdf"; Page = 2; Output = "reddits_popularity_entry_level_histogram_counts.png" }
    @{ Pdf = "PopularityAnalysis.pdf"; Page = 3; Output = "reddits_popularity_histogram_counts.png"         }
)

if (-not (Test-Path $EdgePath)) {
    Write-Error "Microsoft Edge not found at $EdgePath"
    exit 1
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "Node.js is required. Install from https://nodejs.org/"
    exit 1
}

foreach ($item in $PageMapping) {
    $pdfPath = Join-Path $ReportsDir $item.Pdf
    $outPath = Join-Path $ImagesDir $item.Output

    Write-Host "$($item.Pdf) page $($item.Page) -> $($item.Output)"

    $result = node $ScriptJs $pdfPath $item.Page $outPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Extraction failed for $($item.Pdf) page $($item.Page)"
        $result | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
    $result | Select-String "^OK" | ForEach-Object { Write-Host "  $_" }
}

Write-Host "Done - all pages extracted (y=35 CSS top, +15 CSS from previous)."

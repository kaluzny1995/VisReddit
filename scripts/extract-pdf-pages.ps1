param([switch]$AutoInstall)

function Find-Edge {
    if ($env:EDGE_PATH -and (Test-Path -LiteralPath $env:EDGE_PATH -PathType Leaf)) {
        Write-Host "  Using EDGE_PATH from environment"
        return $env:EDGE_PATH
    }
    try { return (Get-Command msedge.exe -ErrorAction Stop).Source } catch {}
    $paths = @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
        "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
    )
    foreach ($p in $paths) { if (Test-Path -LiteralPath $p -PathType Leaf) { return $p } }
    return $null
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ReportsDir  = Join-Path $ProjectRoot "assets\reports"
$ImagesDir   = Join-Path $ProjectRoot "assets\images"
$ScriptJs    = Join-Path $PSScriptRoot "extract-pdf-pages.js"

$EdgePath = Find-Edge
if (-not $EdgePath) {
    Write-Error "Microsoft Edge not found. Set EDGE_PATH environment variable or install Edge."
    exit 1
}
$env:EDGE_PATH = $EdgePath
Write-Host "Edge: $EdgePath"

$PageMapping = @(
    @{ Pdf = "SentimentAnalysis.pdf";  Page = 1; Output = "reddits_sentiment_timeline_counts.png"           }
    @{ Pdf = "SentimentAnalysis.pdf";  Page = 2; Output = "reddits_sentiment_histogram_counts.png"          }
    @{ Pdf = "PopularityAnalysis.pdf"; Page = 1; Output = "reddits_popularity_timeline_counts.png"          }
    @{ Pdf = "PopularityAnalysis.pdf"; Page = 2; Output = "reddits_popularity_entry_level_histogram_counts.png" }
    @{ Pdf = "PopularityAnalysis.pdf"; Page = 3; Output = "reddits_popularity_histogram_counts.png"         }
)

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

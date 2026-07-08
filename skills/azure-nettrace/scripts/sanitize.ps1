<#
.SYNOPSIS
  Sanitize a trace artifact for public examples/.
  Replaces real identifiers with safe placeholders. NOT a substitute for manual review.

.EXAMPLE
  ./sanitize.ps1 -InPath ../../out/trace.md -OutPath ../../examples/appservice-to-sql.md
#>
param(
  [Parameter(Mandatory)][string]$InPath,
  [Parameter(Mandatory)][string]$OutPath,
  [string]$NamePrefix = "contoso"
)

$ErrorActionPreference = "Stop"
$text = Get-Content -Raw -LiteralPath $InPath

# 1. GUIDs (subscription / tenant / object / principal) -> zeroed placeholder
$text = [regex]::Replace($text,
  '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  '00000000-0000-0000-0000-000000000000')

# 2. Tenant domains
$text = [regex]::Replace($text, '[A-Za-z0-9-]+\.onmicrosoft\.com', "$NamePrefix.onmicrosoft.com")

# 3. E-mail addresses
$text = [regex]::Replace($text, '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', 'user@example.com')

# 4. Secret-bearing key/value pairs (belt & braces; the skill masks already)
$text = [regex]::Replace($text,
  '(?i)(AccountKey|SharedAccessKey|SharedAccessSignature|Password|Pwd|client_secret|token)\s*=\s*[^;&"''\s]+',
  '$1=***MASKED***')

# 5. Public IPv4 addresses (keep RFC1918 private ranges, which are illustrative)
$text = [regex]::Replace($text, '\b(?!10\.)(?!192\.168\.)(?!172\.(1[6-9]|2\d|3[01])\.)(\d{1,3}\.){3}\d{1,3}\b', 'x.x.x.x')

# NOTE: resource names cannot be auto-detected reliably. Rename them to
#       $NamePrefix-* MANUALLY, then review the whole file before committing.

$dir = Split-Path -Parent $OutPath
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
Set-Content -LiteralPath $OutPath -Value $text -NoNewline

Write-Host "Sanitized -> $OutPath"
Write-Host "MANUAL STEP REQUIRED: rename real resource names to '$NamePrefix-*' and review before committing." -ForegroundColor Yellow

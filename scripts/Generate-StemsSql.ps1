<#
  NOTE: This assumes Generate-InflectionsSql.ps1 has no errors
#>

Import-Module $PSScriptRoot/PSGenSqlite.psm1 -Force

$ioRoot = "$PSScriptRoot/../build"

$ValidPaliWordMatcher = "^[a|ā|i|ī|u|ū|e|o|k|kh|g|gh|ṅ|c|ch|j|jh|ñ|ṭ|ṭh|ḍ|ḍh|ṇ|t|th|d|dh|n|p|ph|b|bh|m|y|r|l|v|s|h|ḷ|ṃ]+$"
$ValidAlternateStemValues = "^[!|*|-]$"

$abbreviations = Get-Content -Raw "$ioRoot/abbreviations.csv" -Encoding utf8 | Read-AbbreviationsCsv
$index = Get-Content -Raw "$ioRoot/index.csv" -Encoding utf8 | Read-IndexCsv $abbreviations
$stems = Get-Content -Raw "$ioRoot/stems.csv" -Encoding utf8 | Read-StemsCsv | Sort-Object -Property Pāli1

#
# Missing abbreviations checks.
#
Write-Host -ForegroundColor Green "Checking for missing abbreviations..."
$missingAbbreviations =
  $stems
  | Where-Object { -not $_.ismetadata }
  | Group-Object -Property pos
  | Where-Object { -not $abbreviations.ContainsKey($_.Name) }
if ($missingAbbreviations) {
  $missingAbbreviations | ForEach-Object { Write-Host -ForegroundColor Red "Error: '$($_.Name)' not found in abbreviations sheet." }
  throw "Rows missing in abbreviations sheet"
}
Write-Host -ForegroundColor Green "... done!"

#
# Valid stem values: -, *, ! or a pāli word.
#
Write-Host -ForegroundColor Green "Checking for valid stem values..."
$unknownStemValues = $stems | Where-Object { ($_.stem -notmatch $ValidAlternateStemValues) -and ($_.stem -notmatch $ValidPaliWordMatcher) }
if ($unknownStemValues) {
  $unknownStemValues | ForEach-Object { Write-Host -ForegroundColor Red "Error: '$($_.pāli1)' has unknown stem value '$($_.stem)'." }
  throw "Validation error. See above for more details."
}
Write-Host -ForegroundColor Green "... done!"

#
# Valid pattern values for given stems. (AltStem => empty pattern AND PaliWordStem => non-empty pattern)
#
Write-Host -ForegroundColor Green "Checking for valid pattern values for each stem..."
$unknownPatternsForStem = $stems | Where-Object {
  -not (
    (-not ($_.stem -match $ValidAlternateStemValues)) -or (-not $_.pattern) `
    -and `
    (-not ($_.stem -match $ValidPaliWordMatcher)) -or ($_.pattern)
  )
}
if ($unknownPatternsForStem) {
  $unknownPatternsForStem | ForEach-Object { Write-Host -ForegroundColor Red "Error: '$($_.pāli1)' has unknown pattern value '$($_.pattern)' for its stem '$($_.stem)'." }
  throw "Validation error. See above for more details."
}
Write-Host -ForegroundColor Green "... done!"

#
# Stem pattern that do not resolve to a table pointed to by index.
#
Write-Host -ForegroundColor Green "Checking for non-inflectd-form stem patterns that do not resolve to a table pointed to by index..."
$indexPatternMap = $index | Group-Object -Property name -AsHashTable
$unknownPatterns = $stems | Where-Object { $_.stem -ne "!" -and $_.pattern -and (-not $indexPatternMap.ContainsKey($_.pattern)) }
if ($unknownPatterns) {
  $unknownPatterns | ForEach-Object { Write-Host -ForegroundColor Red "Error: $($_.stem) | $($_.pāli1) | $($_.pattern) " }
  throw "Validation error. See above for more details."
}
Write-Host -ForegroundColor Green "... done!"

#
# Inflected form patterns should be a pali1
#
Write-Host -ForegroundColor Green "Checking for inflected form patterns that are not pali1..."
$pali1xStemMap = $stems | Group-Object -Property { $_.pāli1 -replace ' \d+$','' } -AsHashTable
$unknownPatterns =
  $stems
  | Where-Object { $_.stem -eq "!" }
  | Where-Object {
    $notInPali1 = @($_.pattern.split(" ") | Where-Object { $_ } | Where-Object { -not $pali1xStemMap.ContainsKey($_) })
    $notInPali1.Length -ne 0
  }
if ($unknownPatterns) {
  $unknownPatterns | ForEach-Object { Write-Host -ForegroundColor Red "Error: $($_.stem) | $($_.pāli1) | $($_.pattern) " }
  throw "Validation error. See above for more details."
}
Write-Host -ForegroundColor Green "... done!"

#
# Head word (Pāli1) should be unique.
#
Write-Host -ForegroundColor Green "Checking for unique head words..."
$duplicateStemRecords = $stems | Group-Object -Property Pāli1 | Where-Object { $_.Count -ne 1 }
if ($duplicateStemRecords) {
  Write-Host "Duplicate records found"
  $duplicateStemRecords | ForEach-Object { Write-Host "... $($_.Name), $($_.Count)" }
  throw "Validation error. See above for more details."
}
Write-Host -ForegroundColor Green "... done!"

function Out-Sql {
  param (
    [Parameter(Mandatory=$false)]
    [Switch] $Overwrite,
    [Parameter(ValueFromPipeline = $true)]
    $Statement
  )

  Process {
    $Statement | Out-File -Encoding utf8 -FilePath "$ioRoot/stems.sql" -Append:(-not $Overwrite)
  }
}

$commit_id = $env:GITHUB_SHA ?? "0000000000"
$run_number = $env:GITHUB_RUN_NUMBER ?? "0"
$repository = $env:GITHUB_REPOSITORY ?? "dev"
$endRecordMarker = '0xdeadbeef'

"/* stems.db */" | Out-Sql -Overwrite
"PRAGMA foreign_keys = ON;" | Out-Sql
"" | Out-Sql

"-- Version" | Out-Sql
"CREATE TABLE _version (commit_id TEXT NOT NULL, run_number TEXT NOT NULL, repository TEXT NOT NULL);" | Out-Sql
"INSERT INTO _version (commit_id, run_number, repository)" | Out-Sql
"VALUES ('$commit_id', '$run_number', '$repository');" | Out-Sql
"" | Out-Sql

"-- Stems" | Out-Sql
"CREATE TABLE _stems (pāli1 TEXT NOT NULL PRIMARY KEY, stem TEXT NOT NULL, pattern TEXT NOT NULL, pos TEXT NOT NULL, definition TEXT NOT NULL);" | Out-Sql
"INSERT INTO _stems (pāli1, stem, pattern, pos, definition)" | Out-Sql
"VALUES" | Out-Sql
$stems | ForEach-Object { "  ('$($_.pāli1)', '$($_.stem)', '$($_.pattern)', '$($_.pos)', '$($_.definition)')," } | Out-Sql
"  ('$endRecordMarker', '', '', '', '')" | Out-Sql
";" | Out-Sql
"DELETE FROM _stems WHERE pāli1 = '$endRecordMarker';" | Out-Sql
"" | Out-Sql

"-- Save to db" | Out-Sql
".save $("$ioRoot/stems.db".Replace("\", "/"))" | Out-Sql

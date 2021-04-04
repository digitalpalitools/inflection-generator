<#
  NOTE: This assumes Generate-InflectionsSql.ps1 has no errors
#>

Import-Module $PSScriptRoot/PSGenSqlite.psm1 -Force

$ioRoot = "$PSScriptRoot/../build"

$abbreviations = Get-Content -Raw "$ioRoot/abbreviations.csv" -Encoding utf8 | Read-AbbreviationsCsv
$index = Get-Content -Raw "$ioRoot/index.csv" -Encoding utf8 | Read-IndexCsv $abbreviations
$inflections = Get-Content -Raw "$ioRoot/declensions.csv" -Encoding utf8 | Read-InflectionsCsv
$stems = Get-Content -Raw "$ioRoot/stems.csv" -Encoding utf8 | Read-StemsCsv
  | Sort-Object -Property Pāli1
  #| Where-Object { $_.stem -ine "-" }
  #| Select-Object -Skip 0 -First 1000

$reqAbbrevs = @("nom","acc","instr","dat","abl","gen","loc","voc","in comps","masc","fem","nt","x","sg","pl","dual","act","reflx","pr","fut","aor","opt","imp","cond","imperf","perf","1st","2nd","3rd","irreg","gram","ind","abs","adj","adv","base","card","case","comp","cs","ger","idiom","inf","like","ordin","person","pp","prefix","pron","prp","ptp","root","sandhi","suffix","ve")
$missingAbbreviations = $reqAbbrevs | Where-Object { -Not $abbreviations.ContainsKey($_) }
if ($missingAbbreviations) {
  $missingAbbreviations | ForEach-Object { Write-Host -ForegroundColor Red "Error: " $_.Name "not found in abbreviations sheet." }
  throw "Rows missing in abbreviations sheet"
}

$indexPatternMap = $index | Group-Object -Property name -AsHashTable
$unknownPatterns =
  $stems
  | Where-Object { $_.stem -cne "-" }
  | Where-Object { -not $indexPatternMap.ContainsKey($_.pattern) }

$unknownPatterns
| ForEach-Object { Write-Host -ForegroundColor Red "Error: $($_.stem) | $($_.pāli1) | $($_.pattern) " }

if ($unknownPatterns) {
  throw "there were one or more stems that dont have a corresponding inflection. see above errors for more details."
}

$duplicateStemRecords = $stems | Group-Object -Property Pāli1 | Where-Object { $_.Count -ne 1 }
if ($duplicateStemRecords) {
  Write-Host "Duplicate records found"
  $duplicateStemRecords | ForEach-Object { Write-Host "... $($_.Name), $($_.Count)" }
  throw "there are duplicate records in the stems sheet. see above for more info."
}

Write-Host -ForegroundColor Green "Stems validation completed successfully."

$inflectionInfoMap =
  $index
  | Import-InflectionInfos
  | Import-Inflection $inflections $Abbreviations
  | Group-Object -Property { $_.info.name } -AsHashTable

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

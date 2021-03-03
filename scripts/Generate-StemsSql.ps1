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

function Out-SqlForIrregularStem {
  param (
    $printStatus,
    $pāli1,
    $pattern
  )

  if ($printStatus) {
    Write-Host -ForegroundColor DarkMagenta "[irregular]" -NoNewline
  }

  $entries = $inflectionInfoMap.$pattern.entries
  $entries.Keys
  | ForEach-Object {
    $grammar = $entries.$_.grammar -join " "
    $entries.$_.inflections
    | ForEach-Object { "  ('$_', '$pāli1', '$grammar', '*')," }
  }
  | Out-Sql
}

function Out-SqlForIndeclinableStem {
  param (
    $printStatus,
    $pāli1
  )

  if ($printStatus) {
    Write-Host -ForegroundColor DarkYellow "[indeclinable]" -NoNewline
  }

  $word = $pāli1 -replace "[ ]*\d*$","" | TrimWithNull
  "  ('$word', '$pāli1', '', 'ind')," | Out-Sql
}

function Out-SqlForDeclinableStem {
  param (
    $printStatus,
    $pāli1,
    $stem,
    $pattern
  )

  if ($printStatus) {
    Write-Host -ForegroundColor Blue "[declinable]" -NoNewline
  }

  $entries = $inflectionInfoMap.$pattern.entries
  $entries.Keys
  | ForEach-Object {
    $grammar = $entries.$_.grammar -join " "
    $entries.$_.inflections
    | ForEach-Object { "  ('$stem$_', '$pāli1', '$grammar', '')," }
  }
  | Out-Sql
}

function Out-SqlForStem {
  param (
    [Parameter(ValueFromPipeline = $true)]
    $StemRecord
  )

  Begin {
    $count = 0
  }

  Process {
    $pāli1 = $StemRecord.pāli1
    $stem = $StemRecord.stem
    $pattern = $StemRecord.pattern
    $printStatus = $count % 1000 -eq 0
    if ($printStatus) {
      Write-Host -ForegroundColor Green "[$count] Writing sql '$pāli1' " -NoNewline
    }

    if ($stem -eq "*") {
      Out-SqlForIrregularStem $printStatus $pāli1 $pattern
    } elseif ($stem -eq "-") {
      Out-SqlForIndeclinableStem $printStatus $pāli1
    } else {
      Out-SqlForDeclinableStem $printStatus $pāli1 $stem $pattern
    }

    if ($printStatus) {
      Write-Host -ForegroundColor Green " ..."
    }

    $count++
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
"CREATE TABLE _stems (pāli1 TEXT NOT NULL PRIMARY KEY, stem TEXT NOT NULL, pattern TEXT NOT NULL);" | Out-Sql
"INSERT INTO _stems (pāli1, stem, pattern)" | Out-Sql
"VALUES" | Out-Sql
$stems | ForEach-Object { "  ('$($_.pāli1)', '$($_.stem)', '$($_.pattern)')," } | Out-Sql
"  ('$endRecordMarker', '', '')" | Out-Sql
";" | Out-Sql
"DELETE FROM _stems WHERE pāli1 = '$endRecordMarker';" | Out-Sql
"" | Out-Sql

"-- all_words" | Out-Sql
"CREATE TABLE all_words (pāli TEXT NOT NULL, pāli1 TEXT NOT NULL, grammar TEXT NOT NULL, type TEXT NOT NULL, FOREIGN KEY (pāli1) REFERENCES _stems (pāli1));" | Out-Sql
"INSERT INTO all_words (pāli, pāli1, grammar, type)" | Out-Sql
"VALUES" | Out-Sql
# $stems | Out-SqlForStem
"  ('$endRecordMarker', '$($stems[0].pāli1)', '', '')" | Out-Sql
";" | Out-Sql
"DELETE FROM all_words WHERE pāli = '$endRecordMarker';" | Out-Sql
"" | Out-Sql

"-- Save to db" | Out-Sql
".save $("$ioRoot/stems.db".Replace("\", "/"))" | Out-Sql

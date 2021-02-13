<#
  NOTE: This assumes Generate-InflectionsSql.ps1 has no errors
#>

Import-Module $PSScriptRoot/PSGenSqlite.psm1 -Force

$ioRoot = "$PSScriptRoot/../build"

$index = Get-Content -Raw "$ioRoot/index.csv" -Encoding utf8 | Read-IndexCsv
$inflections = Get-Content -Raw "$ioRoot/declensions.csv" -Encoding utf8 | Read-InflectionsCsv
$abbreviations = Get-Content -Raw "$ioRoot/abbreviations.csv" -Encoding utf8 | Read-AbbreviationsCsv
$stems = Get-Content -Raw "$ioRoot/stems.csv" -Encoding utf8 | ConvertFrom-Csv | Select-Object -Skip 0 -First 1000000

$indexPatternMap = $index | Group-Object -Property name -AsHashTable
$unknownPatterns =
  $stems
  | Where-Object { $_.stem -cne "ind" }
  | Where-Object { -not $indexPatternMap.ContainsKey($_.pattern) }

$unknownPatterns
| ForEach-Object { Write-Host -ForegroundColor Red "Error: $($_)" }

if ($unknownPatterns) {
  throw "there were one or more stems that dont have a corresponding inflection. see above errors for more details."
} else {
  Write-Host -ForegroundColor Green "Stems validation completed successfully."
}

$inflectionInfos =
  $index
  | Import-InflectionInfos $abbreviations
  | Import-Inflection $inflections $Abbreviations

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
    $StemRecord
  )

  Write-Host -ForegroundColor DarkMagenta "[irregular]" -NoNewline
}

function Out-SqlForIndeclinableStem {
  param (
    $StemRecord
  )

  Write-Host -ForegroundColor DarkYellow "[indeclinable]" -NoNewline

  $word = $StemRecord.pāli1 -replace "[ ]*\d*$","" | TrimWithNull
  "  ('$word', '$($StemRecord.pāli1)', 'ind')," | Out-Sql
}

function Out-SqlForDeclinableStem {
  param (
    $StemRecord
  )

  Write-Host -ForegroundColor DarkBlue "[declinable]" -NoNewline
}

function Out-SqlForStem {
  param (
    [Parameter(ValueFromPipeline = $true)]
    $StemRecord
  )

  Process {
    $pāli1 = $StemRecord.pāli1
    $stem = $StemRecord.stem
    Write-Host -ForegroundColor Green "Writing sql '$pāli1' " -NoNewline

    if ($stem -eq "*") {
      Out-SqlForIrregularStem $StemRecord
    } elseif ($stem -eq "ind") {
      Out-SqlForIndeclinableStem $StemRecord
    } else {
      Out-SqlForDeclinableStem $StemRecord
    }

    Write-Host -ForegroundColor Green " ..."
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
"CREATE TABLE all_words (pāli TEXT NOT NULL, pāli1 TEXT NOT NULL, type TEXT NOT NULL, FOREIGN KEY (pāli1) REFERENCES _stems (pāli1));" | Out-Sql
"INSERT INTO all_words (pāli, pāli1, type)" | Out-Sql
"VALUES" | Out-Sql

$stems | Out-SqlForStem

"  ('$endRecordMarker', 'acca', '')" | Out-Sql
";" | Out-Sql
"DELETE FROM all_words WHERE pāli1 = '$endRecordMarker';" | Out-Sql
"" | Out-Sql

"-- Save to db" | Out-Sql
".save $("$ioRoot/stems.db".Replace("\", "/"))" | Out-Sql

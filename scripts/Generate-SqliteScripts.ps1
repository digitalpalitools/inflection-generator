Import-Module $PSScriptRoot/PSGenSqlite.psm1 -Force

$ioRoot = "$PSScriptRoot/../build"

$index = Get-Content -Raw "$ioRoot/index.csv" -Encoding utf8 | Read-IndexCsv
$inflections = Get-Content -Raw "$ioRoot/declensions.csv" -Encoding utf8 | Read-InflectionsCsv
$abbreviations = Get-Content -Raw "$ioRoot/abbreviations.csv" -Encoding utf8 | Read-AbbreviationsCsv

$inflectionInfos =
  $index
  | Import-InflectionInfos $abbreviations
  | Import-Inflection $inflections $Abbreviations

$errors =
  $inflectionInfos
  | Where-Object { $_.error }

$errors
| ForEach-Object { Write-Host -ForegroundColor Red "Error: $($_.error)" }

if ($errors) {
  throw "there were one or more errors, see above for details"
}

function Out-Sql {
  param (
    [Parameter(Mandatory=$false)]
    [Switch] $Overwrite,
    [Parameter(ValueFromPipeline = $true)]
    $Statement
  )

  Process {
    $Statement | Out-File -Encoding utf8 -FilePath "$ioRoot/inflections.sql" -Append:(-not $Overwrite)
  }
}

$commit_id = $env:GITHUB_SHA ?? "0000000000"
$run_number = $env:GITHUB_RUN_NUMBER ?? "0"
$repository = $env:GITHUB_REPOSITORY ?? "dev"

"/* inflections.db */" | Out-Sql -Overwrite
"PRAGMA foreign_keys = ON;" | Out-Sql
"" | Out-Sql

"-- Version" | Out-Sql
"CREATE TABLE _version (commit_id TEXT NOT NULL, run_number TEXT NOT NULL, repository TEXT NOT NULL);" | Out-Sql
"INSERT INTO _version (commit_id, run_number, repository)" | Out-Sql
"VALUES ('$commit_id', '$run_number', '$repository');" | Out-Sql
"" | Out-Sql

"-- Abbreviations" | Out-Sql
"CREATE TABLE _abbreviations (name TEXT NOT NULL PRIMARY KEY, description TEXT NOT NULL, isgrammar INTEGER NOT NULL, isverb INTEGER NOT NULL);" | Out-Sql
"INSERT INTO _abbreviations (name, description, isgrammar, isverb)" | Out-Sql
"VALUES" | Out-Sql
($Abbreviations.Keys | Sort-Object | ForEach-Object { "  ('$($Abbreviations.$_.name)', '$($Abbreviations.$_.description)', '$($Abbreviations.$_.isgrammar)', '$($Abbreviations.$_.isverb)')" }) -join ",`n" | Out-Sql
";" | Out-Sql
"" | Out-Sql

function Out-SqlForInflectionForVerbs {
  param (
    $TableName,
    $Entries
  )

  Process {
    @"
CREATE TABLE $TableName (
  actrefxl TEXT NOT NULL,
  tense TEXT NOT NULL,
  person TEXT NOT NULL,
  number TEXT NOT NULL,
  inflections TEXT NOT NULL,
  PRIMARY KEY(actrefxl, tense, person, number),
  FOREIGN KEY (actrefxl) REFERENCES _abbreviations (name),
  FOREIGN KEY (tense) REFERENCES _abbreviations (name),
  FOREIGN KEY (person) REFERENCES _abbreviations (name),
  FOREIGN KEY (number) REFERENCES _abbreviations (name)
);
"@ | Out-Sql
    "INSERT INTO $TableName (actrefxl, tense, person, number, inflections)" | Out-Sql
    "VALUES" | Out-Sql
    ($Entries.Keys | ForEach-Object {
      "  ('$($Entries.$_.grammar[0])', '$($Entries.$_.grammar[1])', '$($Entries.$_.grammar[2])', '$($Entries.$_.grammar[3])', '$($Entries.$_.inflections -join ',')')"
    }) -join ",`n" | Out-Sql
  }
}

function Out-SqlForInflectionForNonVerbs {
  param (
    $TableName,
    $Entries
  )

  Process {
    @"
CREATE TABLE $TableName (
  gender TEXT NOT NULL,
  "case" TEXT NOT NULL,
  number TEXT NOT NULL,
  inflections TEXT NOT NULL,
  PRIMARY KEY(gender, "case", number),
  FOREIGN KEY (gender) REFERENCES _abbreviations (name),
  FOREIGN KEY ("case") REFERENCES _abbreviations (name),
  FOREIGN KEY (number) REFERENCES _abbreviations (name)
);
"@ | Out-Sql
    "INSERT INTO $TableName (gender, ""case"", number, inflections)" | Out-Sql
    "VALUES" | Out-Sql
    ($Entries.Keys | ForEach-Object {
      "  ('$($Entries.$_.grammar[0])', '$($Entries.$_.grammar[1])', '$($Entries.$_.grammar[2])', '$($Entries.$_.inflections -join ',')')"
    }) -join ",`n" | Out-Sql
  }
}

function Out-SqlForInflection {
  param (
    [Parameter(ValueFromPipeline = $true)]
    $Inflection
  )

  Process {
    $info = $Inflection.info
    $entries = $Inflection.entries
    Write-Host -ForegroundColor Green "Writing schema for '$($info.name)' [$($info.SCol)$($info.SRow):$($($info.ECol))$($info.ERow)] ..."

    $tableName = $info.name.Replace(" ", "_")
    "-- $tableName" | Out-Sql
    if ($Inflection.info.isverb) {
      Out-SqlForInflectionForVerbs $tableName $entries
    } else {
      Out-SqlForInflectionForNonVerbs $tableName $entries
    }
    ";" | Out-Sql
    "" | Out-Sql
  }
}

$inflectionInfos | Sort-Object -Property { $_.info.name } | Out-SqlForInflection

"-- Save to db" | Out-Sql
".save $("$ioRoot/inflections.db".Replace("\", "/"))" | Out-Sql

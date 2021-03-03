Import-Module $PSScriptRoot/PSGenSqlite.psm1 -Force

$ioRoot = "$PSScriptRoot/../build"

$abbreviations = Get-Content -Raw "$ioRoot/abbreviations.csv" -Encoding utf8 | Read-AbbreviationsCsv
$index = Get-Content -Raw "$ioRoot/index.csv" -Encoding utf8 | Read-IndexCsv $abbreviations
$inflections = Get-Content -Raw "$ioRoot/declensions.csv" -Encoding utf8 | Read-InflectionsCsv

$inflectionInfos =
  $index
  | Import-InflectionInfos
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

$tableName = "_version"
"-- $tableName" | Out-Sql
"CREATE TABLE $tableName (commit_id TEXT NOT NULL, run_number TEXT NOT NULL, repository TEXT NOT NULL);" | Out-Sql
"INSERT INTO $tableName (commit_id, run_number, repository)" | Out-Sql
"VALUES ('$commit_id', '$run_number', '$repository');" | Out-Sql
"" | Out-Sql

$tableName = "_abbreviations"
"-- $tableName" | Out-Sql
"CREATE TABLE $tableName (name TEXT NOT NULL PRIMARY KEY, description TEXT NOT NULL, isgrammar INTEGER NOT NULL, isverb INTEGER NOT NULL);" | Out-Sql
"INSERT INTO $tableName (name, description, isgrammar, isverb)" | Out-Sql
"VALUES" | Out-Sql
($Abbreviations.Keys | Sort-Object | ForEach-Object { "  ('$($Abbreviations.$_.name)', '$($Abbreviations.$_.description)', '$($Abbreviations.$_.isgrammar)', '$($Abbreviations.$_.isverb)')" }) -join ",`n" | Out-Sql
";" | Out-Sql
"" | Out-Sql

$gramValues = @{
  special_pron_class = @("", "1st", "2nd", "dual")
  actreflx = @("", "act", "reflx")
  tense = @("", "pr", "imp", "opt", "fut", "aor", "cond", "imperf", "perf")
  person = @("", "3rd", "2nd", "1st")
  number = @("", "sg", "pl", "dual")
  gender = @("", "masc", "fem", "nt", "x")
  case = @("", "nom", "acc", "instr", "dat", "abl", "gen", "loc", "voc")
}

$gramValues.Keys | ForEach-Object {
  $tableName = "_$($_)_values"
  "-- $tableName" | Out-Sql
  "CREATE TABLE $tableName (name TEXT NOT NULL UNIQUE, FOREIGN KEY (name) REFERENCES _abbreviations (name));" | Out-Sql
  "INSERT INTO $tableName (name)" | Out-Sql
  "VALUES" | Out-Sql
  ($gramValues.$_ | ForEach-Object { "  ('$_')" }) -join ",`n" | Out-Sql
  ";" | Out-Sql
  "CREATE UNIQUE INDEX pk_$($tableName)_index ON $tableName (""rowid"", ""name"");" | Out-Sql
  "" | Out-Sql
}

$tableName = "_index"
"-- $tableName" | Out-Sql
"CREATE TABLE $tableName (name TEXT NOT NULL PRIMARY KEY, inflection_class TEXT NOT NULL, example_info INTEGER NOT NULL);" | Out-Sql
"INSERT INTO $tableName (name, inflection_class, example_info)" | Out-Sql
"VALUES" | Out-Sql
($index | ForEach-Object { "  ('$($_.name)', '$($_.inflectionclass)', '$($_.exampleinfo)')" }) -join ",`n" | Out-Sql
";" | Out-Sql
"" | Out-Sql

<#
  "actreflx / tense / person / number" for verbs e.g optative 3rd singular
#>
function Out-SqlForInflectionForVerbs {
  param (
    $TableName,
    $Entries
  )

  Process {
    @"
CREATE TABLE $TableName (
  actreflx TEXT NOT NULL,
  tense TEXT NOT NULL,
  person TEXT NOT NULL,
  number TEXT NOT NULL,
  inflections TEXT NOT NULL,
  PRIMARY KEY (actreflx, tense, person, number),
  FOREIGN KEY (actreflx) REFERENCES _actreflx_values (name),
  FOREIGN KEY (tense) REFERENCES _tense_values (name),
  FOREIGN KEY (person) REFERENCES _person_values (name),
  FOREIGN KEY (number) REFERENCES _number_values (name)
);
"@ | Out-Sql
    "INSERT INTO $TableName (actreflx, tense, person, number, inflections)" | Out-Sql
    "VALUES" | Out-Sql
    ($Entries.Keys | ForEach-Object {
      "  ('$($Entries.$_.grammar[0])', '$($Entries.$_.grammar[1])', '$($Entries.$_.grammar[2])', '$($Entries.$_.grammar[3])', '$($Entries.$_.inflections -join ',')')"
    }) -join ",`n" | Out-Sql
  }
}

<#
  "gender / case / number" for nouns, adjectives, participles, etc eg. masc nom sg
#>
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
  PRIMARY KEY (gender, "case", number),
  FOREIGN KEY (gender) REFERENCES _gender_values (name),
  FOREIGN KEY ("case") REFERENCES _case_values (name),
  FOREIGN KEY (number) REFERENCES _number_values (name)
);
"@ | Out-Sql
    "INSERT INTO $TableName (gender, ""case"", number, inflections)" | Out-Sql
    "VALUES" | Out-Sql
    ($Entries.Keys | ForEach-Object {
      "  ('$($Entries.$_.grammar[0])', '$($Entries.$_.grammar[1])', '$($Entries.$_.grammar[2])', '$($Entries.$_.inflections -join ',')')"
    }) -join ",`n" | Out-Sql
  }
}

<#
  prondual = dual / case / number
  pron1st = 1st / case / number
  pron2st = 2nd / case / number
#>
function Out-SqlForInflectionForSpecialNonVerbs {
  param (
    $TableName,
    $InflectionClass,
    $Entries
  )

  Process {
    @"
CREATE TABLE $TableName (
  special_pron_class TEXT NOT NULL,
  "case" TEXT NOT NULL,
  number TEXT NOT NULL,
  inflections TEXT NOT NULL,
  PRIMARY KEY (special_pron_class, "case", number),
  FOREIGN KEY (special_pron_class) REFERENCES _special_pron_class_values (name),
  FOREIGN KEY ("case") REFERENCES _case_values (name),
  FOREIGN KEY (number) REFERENCES _number_values (name)
);
"@ | Out-Sql
    "INSERT INTO $TableName (special_pron_class, ""case"", number, inflections)" | Out-Sql
    "VALUES" | Out-Sql
    ($Entries.Keys | ForEach-Object {
      $spc = $Entries.$_.grammar[0].length -eq 0 ? "" : $inflectionClass.Substring(4)
      "  ('$($spc)', '$($Entries.$_.grammar[1])', '$($Entries.$_.grammar[2])', '$($Entries.$_.inflections -join ',')')"
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
    Write-Host -ForegroundColor Green "Writing sql for '$($info.name)' [$($info.SCol)$($info.SRow):$($($info.ECol))$($info.ERow)] ..."

    $tableName = $info.name.Replace(" ", "_")

    "-- $tableName" | Out-Sql
    if ($Inflection.info.inflectionClass -eq "verb") {
      Out-SqlForInflectionForVerbs $tableName $entries
    } elseif (@("pron1st", "pron2nd", "prondual") -contains $Inflection.info.inflectionClass) {
      Out-SqlForInflectionForSpecialNonVerbs $tableName $info.inflectionclass $entries
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

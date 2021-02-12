# param (
#   [Parameter(Mandatory)]
#   $SrcDir,
#   [Parameter(Mandatory)]
#   $DstDir
# )

<#
o a.adj in db
  o load schema
    x bottom-right - 3 corner cells
    x name 2nd part is a valid pos
    v index has same name
    v has even number of columns
    v get mapping from grammar -> suffix
    v grammar has valid parts
    v inflection is not empty
    v unknown pos
    v invalid number of grammar parts for pos
    v check no spaces or punctuation in inflection
  o generate .sql
    v dummy sql
    - final sql
    - expansions table
  o generate .db
    v run sqlite cmd line
v integrate above with CI
  - publish: .csvs, .db, .sql to azure storage
#>

Import-Module $PSScriptRoot/PSGenSqlite.psm1 -Force

$ioRoot = "$PSScriptRoot/../build"

$index = Get-Content -Raw "$ioRoot/index.csv" -Encoding utf8 | Read-IndexCsv
$inflections = Get-Content -Raw "$ioRoot/declensions.csv" -Encoding utf8 | Read-InflectionsCsv
$abbreviations = Get-Content -Raw "$ioRoot/abbreviations.csv" -Encoding utf8 | Read-AbbreviationsCsv

$inflectionInfos =
  $index
  | Import-InflectionInfos
  | Import-Inflection $inflections $Abbreviations

$errors1 =
  $inflectionInfos
  | Where-Object { $_.error }

$errors1
| ForEach-Object { Write-Host -ForegroundColor Red "Error: $($_.error)" }

if ($errors1) {
  throw "there were one or more errors, see above for details"
}

$inflectionInfos
  | Where-Object { -not $_.error }
  | ForEach-Object {
    $x = $_.info
    $c = $_.entries.Count
    Write-Host -ForegroundColor Green "Loading schema #$($x.Id) ($c) '$($($x.Name))' from $($x.SCol)$($($x.SRow)):$($($x.ECol))$($x.ERow) ..."
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
$run_id = $env:GITHUB_RUN_ID ?? "0"
$repository = $env:GITHUB_REPOSITORY ?? "dev"

"/* inflections.db */" | Out-Sql -Overwrite
"" | Out-Sql

"-- Version" | Out-Sql
"CREATE TABLE _version (commit_id TEXT NOT NULL, run_id TEXT NOT NULL, repository TEXT NOT NULL);" | Out-Sql
"INSERT INTO _version (commit_id, run_id, repository)" | Out-Sql
"VALUES ('$commit_id', '$run_id', '$repository');" | Out-Sql
"" | Out-Sql

"-- PosInfo" | Out-Sql
"CREATE TABLE pos_info (pos TEXT NOT NULL PRIMARY KEY, parts INTEGER NOT NULL);" | Out-Sql
"INSERT INTO pos_info (pos, parts)" | Out-Sql
"VALUES" | Out-Sql
($PosInfo.Keys | ForEach-Object { "  ('$_', $($PosInfo[$_]))" }) -join ",`n" | Out-Sql
";" | Out-Sql
"" | Out-Sql

"-- VerbCategories" | Out-Sql
"CREATE TABLE verb_categories (category TEXT NOT NULL PRIMARY KEY);" | Out-Sql
"INSERT INTO verb_categories (category)" | Out-Sql
"VALUES" | Out-Sql
($VerbCategories.Keys | ForEach-Object { "  ('$_')" }) -join ",`n" | Out-Sql
";" | Out-Sql
"" | Out-Sql

"-- Save to db" | Out-Sql
".save $("$ioRoot/inflections.db".Replace("\", "/"))" | Out-Sql

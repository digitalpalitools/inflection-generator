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

$sql = @"
create table tbl1(one varchar(10), two smallint);
insert into tbl1 values('hello!', 110);
insert into tbl1 values('goodbye', 120);
select * from tbl1;

.save $("$ioRoot/inflections.db".Replace("\", "/"))
"@

$sql | Out-File -Encoding utf8 -FilePath "$ioRoot/inflections.sql"

$abbreviations
$abbreviations.masc
$abbreviations.nom
$abbreviations.sg
$abbreviations.pl

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
    v index has same name
    v has even number of columns
    v get mapping from grammar -> suffix
    - grammar is valid
    - suffix is not empty
    - check no spaces or punctuation in cells with inflection data
  o generate .sql
    v dummy sql
    - final sql
  o generate .db
    v run sqlite cmd line
- expansions table
- integrate above with CI
- publish: .csvs, .db, .sql
#>

Import-Module $PSScriptRoot/PSGenSqlite.psm1 -Force

$ioRoot = "$PSScriptRoot/../build"

$index = Get-Content -Raw "$ioRoot/index.csv" -Encoding utf8 | Read-Index
$inflections = Get-Content -Raw "$ioRoot/declensions.csv" -Encoding utf8 | Read-Inflection

$inflectionInfos =
  $index
  | Import-InflectionInfos
  | Import-Inflection $inflections

$errors1 =
  $inflectionInfos
    | Where-Object { $_.Error }

$errors1
    | ForEach-Object { Write-Host -ForegroundColor Red "Error: $($_.Error)" }

if ($errors1) {
  throw "there were one or more errors, see above for details"
}

$inflectionInfos
  | Where-Object { -not $_.Error }
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

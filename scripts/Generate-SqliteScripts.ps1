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
    - has even number of columns
    - short id is valid
    - suffix is not empty
    - get mapping from short id -> suffix
    - check no spaces or punctuation in cells with inflection data
  o generate .sql
    -
  o generate .db
    - run sqlite cmd line
- expansions table
- integrate above with CI
- publish: .csvs, .db, .sql
#>

Import-Module $PSScriptRoot/PSGenSqlite.psm1 -Force

$index = Get-Content -Raw "$PSScriptRoot/../build/index.csv" -Encoding utf8 | Read-Index
$inflections = Get-Content -Raw "$PSScriptRoot/../build/declensions.csv" -Encoding utf8 | Read-Inflection

$inflectionInfos =
  $index
  | Import-InflectionInfos
  | Test-InflectionInfo $inflections

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
    Write-Host -ForegroundColor Green "Loading schema #$($_.Id) '$($($_.Name))' from $($_.SCol)$($($_.SRow)):$($($_.ECol))$($_.ERow) ..."
  }


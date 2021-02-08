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
  o generate .sql
    -
  o generate .db
    - run sqlite cmd line
- expansions table
- integrate above with CI
- publish: .csvs, .db, .sql
#>

Import-Module $PSScriptRoot/PSGenSqlite.psm1 -Force

$index = Get-Content -Raw "$PSScriptRoot/../build/index.csv" | Read-Index
$inflections = Get-Content -Raw "$PSScriptRoot/../build/declensions.csv" | Read-Inflection

$inflectionInfos =
  $index
  | Import-InflectionInfos
  #| Select-Object -First 1000
  | Test-InflectionInfo $inflections

$inflectionInfos
  | Where-Object { $_.Error }
  | ForEach-Object { Write-Host -ForegroundColor Red "Error: $($_.Error)" }

$inflectionInfos
  | Where-Object { -not $_.Error }
  | ForEach-Object {
    Write-Host -ForegroundColor Green "Loading schema #$($_.Id) '$($($_.Name))' from $($_.SCol)$($($_.SRow)):$($($_.ECol))$($_.ERow) ..."
  }

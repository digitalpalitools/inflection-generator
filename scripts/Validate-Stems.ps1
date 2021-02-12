Import-Module $PSScriptRoot/PSGenSqlite.psm1 -Force

$ioRoot = "$PSScriptRoot/../build"

$index = Get-Content -Raw "$ioRoot/index.csv" -Encoding utf8 | Read-IndexCsv | Group-Object -Property name -AsHashTable
$stems = Get-Content -Raw "$ioRoot/stems.csv" -Encoding utf8 | ConvertFrom-Csv

$unknownPatterns =
  $stems
  | Where-Object { $_.stem -cne "ind" }
  | Where-Object { -not $index.ContainsKey($_.pattern) }

$unknownPatterns
| ForEach-Object { Write-Host -ForegroundColor Red "Error: $($_)" }

if ($unknownPatterns) {
  throw "there were one or more stems that dont have a corresponding inflection. see above errors for more details."
} else {
  Write-Host -ForegroundColor Green "Stems validation completed successfully."
}

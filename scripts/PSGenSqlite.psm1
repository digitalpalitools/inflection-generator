New-Variable -Name 'ArrayOf5EmptyStrings' -Option Constant @("", "", "", "", "")

New-Variable -Name 'PosInfo' -Option Constant -Value @{
  "adj" = 3
  "aor" = 4
  "aor irreg" = 4
  "card" = 3
  "cond" = 4
  "fem" = 3
  "fem irreg" = 3
  "fut" = 4
  "imperf" = 4
  "letter" = 3
  "masc" = 3
  "masc pl" = 3
  "nt" = 3
  "nt irreg" = 3
  "ordin" = 3
  "perf" = 4
  "pp" = 3
  "pr" = 4
  "pron" = 3
  "prp" = 3
  "ptp" = 3
  "root" = 3
  "imp" = 4
  "opt" = 4
}

function CreateInflectionCsvColumns {
  @(
    @("", ("A".."Z"))
    | ForEach-Object { $_ }
    | ForEach-Object {
      $c1 = $_
      "A".."Z" | ForEach-Object { $c2 = $_; "$c1$c2" } }
  )
}

New-Variable -Name 'InflectionCsvColumns' -Option Constant -Value $(CreateInflectionCsvColumns)

function CreateInflectionCsvColumnIndices {
  $i = 0;
  $map = @{};

  $InflectionCsvColumns
  | ForEach-Object {
    $map.($_) = $i; $i++
  }

  $map
}

New-Variable -Name 'InflectionCsvColumnIndices' -Option Constant -Value $(CreateInflectionCsvColumnIndices)

function TrimWithNull {
  param (
    [Parameter(ValueFromPipeline = $true)]
    $String
  )

  Process {
    if ($String) {
      $String.Trim()
    } else {
      $String
    }
  }
}

function New-Error {
  param (
    [Parameter(ValueFromPipeline = $true)]
    $Error
  )

  Process {
    @{ error = $Error }
  }
}

function Read-IndexCsv {
  param (
    [Parameter(ValueFromPipeline = $true)]
    $Csv
  )

  Process {
    ConvertFrom-Csv $Csv -Header @("name", "bounds")
    | Where-Object { $_.name -or $_.bounds }
    | ForEach-Object { @{ name = $_.name | TrimWithNull; bounds = $_.bounds | TrimWithNull; } }
  }
}

function Read-AbbreviationsCsv {
  param (
    [Parameter(ValueFromPipeline = $true)]
    $Csv
  )

  Process {
    $abbreviations = @{}

    ConvertFrom-Csv $Csv -Header @("name", "description")
    | Where-Object { $_.name -and $_.description }
    | ForEach-Object {
      $name = $_.name | TrimWithNull
      if ($name -ieq "in comps") {
        $name = ""
      }

      $abbreviations.$name = @{ name = $name; description = $_.description | TrimWithNull; }
    }

    $abbreviations
  }
}

function Read-InflectionsCsv {
  param (
    [Parameter(ValueFromPipeline = $true)]
    $Csv
  )

  Process {
    ConvertFrom-Csv $Csv -Header $InflectionCsvColumns
  }
}

function Import-InflectionInfos {
  param (
    [Parameter(ValueFromPipeline = $true)]
    $Index
  )

  Begin {
    $id = 0
  }

  Process {
    $id++

    if ((-not $Index.name) -or (-not $Index.bounds)) {
      "Index row $id is invalid." | New-Error
      return
    }

    if (-not ($Index.bounds -match '^([A-Z]+)([0-9]+):([A-Z]+)([0-9]+)$')) {
      "Index row $id has invalid bounds." | New-Error
      return
    }

    $name = $Index.name.Trim()
    $pos = $name.Trim().Split(" ")[1..10] -join " "
    if (-not $PosInfo.ContainsKey($pos)) {
      "Inflection '$name' is for an unknown part of speech." | New-Error
      return
    }

    $sRow = [int] ($Matches[2] - 1)
    $sCol = $Matches[1]
    $eRow = [int] ($Matches[4] - 1)
    $eCol = $Matches[3]

    $sColIndex = $InflectionCsvColumnIndices.$($sCol)
    $eColIndex = $InflectionCsvColumnIndices.$($eCol)
    if (($eColIndex -le ($sColIndex + 1)) -or ($eRow -le $sRow)) {
      "Inflection '$name' location must have start row and col less than end row and col." | New-Error
      return
    }

    if ((($eColIndex - $sColIndex + 1) % 2) -eq 0) {
      "Inflection '$name' must have even number of columns (grammar and inflection)." | New-Error
      return
    }

    @{
      Id = $id
      Pos = $pos
      Name = $name
      SRow = $sRow
      SCol = $sCol
      ERow = $eRow
      ECol = $eCol
    }
  }
}

function Import-Inflection {
  param (
    $InflectionCsv,
    $Abbreviations,
    [Parameter(ValueFromPipeline = $true)]
    $InflectionInfo
  )

  Process {
    # NOTE: Pass through errors from previous steps.
    if ($InflectionInfo.error) {
      $InflectionInfo
      return
    }

    $name = $InflectionCsv[$InflectionInfo.SRow]."$($InflectionInfo.SCol)".Trim()
    if ($name -cne $InflectionInfo.Name) {
      "Inflection '$($InflectionInfo.Name)' not found at $($InflectionInfo.SCol)$($InflectionInfo.SRow+1)." | New-Error
      return
    }

    $inflection = @{ info = $InflectionInfo; entries = @{} }
    $sCol = $InflectionCsvColumnIndices.$($InflectionInfo.SCol)
    $eCol = $InflectionCsvColumnIndices.$($InflectionInfo.ECol)
    for ($i = $InflectionInfo.SRow + 1; $i -le $InflectionInfo.ERow; $i += 1) {
      for ($j = $sCol + 1; $j -le $eCol; $j += 2) {
        $inf = $InflectionCsv[$i].$($InflectionCsvColumns[$j]) | TrimWithNull
        $gra = $InflectionCsv[$i].$($InflectionCsvColumns[$j + 1]) | TrimWithNull
        if ($inf) {
          $inflection.entries.$($gra) = @{
            grammar = if ($gra) { $gra.Split(" ") | Where-Object { $_} } else { @($ArrayOf5EmptyStrings | Select-Object -First $PosInfo[$inflection.info.Pos]) }
            allInflections = $inf
            inflections = $inf.Split("`n") | ForEach-Object { $_ | TrimWithNull } | Where-Object { $_}
          }
        }
      }
    }

    $errors = @()

    $errors +=
      $inflection.entries.Keys
      | ForEach-Object { $inflection.entries[$_].grammar }
      | Where-Object { -not $Abbreviations.ContainsKey($_) }
      | ForEach-Object {
          "Inflection '$($inflection.info.name)' has unrecognized grammar '$_'." | New-Error
      }

    $errors +=
      $inflection.entries.Keys
      | Where-Object { $inflection.entries[$_].grammar.Length -ne $PosInfo[$inflection.info.Pos] }
      | ForEach-Object {
        "Inflection '$($inflection.info.name)':'$_' was expected to have '$($PosInfo[$inflection.info.Pos])' grammar entries, instead has '$($inflection.entries[$_].grammar.Length)' grammar entries." | New-Error
      }

    $errors +=
      $inflection.entries.Keys
      | ForEach-Object { $inflection.entries[$_].inflections }
      | Where-Object { $_ -notmatch "^[a|ā|i|ī|u|ū|e|o|k|kh|g|gh|ṅ|c|ch|j|jh|ñ|ṭ|ṭh|ḍ|ḍh|ṇ|t|th|d|dh|n|p|ph|b|bh|m|y|r|l|v|s|h|ḷ|ṃ]+$" }
      | ForEach-Object {
        "Inflection '$($inflection.info.name)':'$_' cannot have invalid characters." | New-Error
      }

    if ($errors) {
      $errors
      return
    }

    $inflection
  }
}

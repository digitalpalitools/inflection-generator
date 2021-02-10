New-Variable -Name 'PosInfo' -Option Constant -Value @{
  "adj" = 1
  "aor" = 1
  "aor irreg" = 1
  "card" = 1
  "cond" = 1
  "fem" = 1
  "fem irreg" = 1
  "fut" = 1
  "imperf" = 1
  "letter" = 1
  "masc" = 1
  "masc pl" = 1
  "nt" = 1
  "nt irreg" = 1
  "ordin" = 1
  "perf" = 1
  "pp" = 1
  "pr" = 1
  "pron" = 1
  "prp" = 1
  "ptp" = 1
  "root" = 1
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
          $inflection.entries.$($gra) = $inf
        }
      }
    }

    $errors = @()
    $errors +=
      $inflection.entries.Keys
      | ForEach-Object { $_.Split(" ") }
      | Where-Object { -not $Abbreviations.ContainsKey($_) }
      | ForEach-Object {
          "Inflection '$($inflection.info.name)' has invalid grammar '$_'." | New-Error
      }

    if ($errors) {
      $errors
      return
    }

    $inflection
  }
}

function CreateInflectionCsvColumns
{
  @(
    @("", ("A".."Z"))
    | ForEach-Object { $_ }
    | ForEach-Object {
      $c1 = $_
      "A".."Z" | ForEach-Object { $c2 = $_; "$c1$c2" } }
  )
}

New-Variable -Name 'InflectionCsvColumns' -Option Constant -Value $(CreateInflectionCsvColumns)

function CreateInflectionCsvColumnIndices
{
  $i = 0;
  $map = @{};

  $InflectionCsvColumns
  | ForEach-Object {
    $map.($_) = $i; $i++
  }

  $map
}

New-Variable -Name 'InflectionCsvColumnIndices' -Option Constant -Value $(CreateInflectionCsvColumnIndices)

function TrimWithNull
{
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

function New-Error
{
  param (
    [Parameter(ValueFromPipeline = $true)]
    $Error
  )

  Process {
    @{ Error = $Error }
  }
}

function Read-Index {
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

function Read-Inflection {
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
    $sRow = [int] ($Matches[2] - 1)
    $sCol = $Matches[1]
    $eRow = [int] ($Matches[4] - 1)
    $eCol = $Matches[3]

    $sColIndex = $InflectionCsvColumnIndices.$($sCol)
    $eColIndex = $InflectionCsvColumnIndices.$($eCol)
    if ((($eColIndex - $sColIndex + 1) % 2) -eq 0) {
      "Inflection '$name' must have even number of columns (grammar and inflection)." | New-Error
      return
    }

    @{
      Id = $id
      Name = $name
      SRow = $sRow
      SCol = $sCol
      ERow = $eRow
      ECol = $eCol
    }
  }
}

function Test-InflectionInfo {
  param (
    $InflectionCsv,
    [Parameter(ValueFromPipeline = $true)]
    $InflectionInfo
  )

  Process {
    # NOTE: Pass through errors from previous steps.
    if ($InflectionInfo.Error) {
      $InflectionInfo
      return
    }

    $name = $InflectionCsv[$InflectionInfo.SRow]."$($InflectionInfo.SCol)".Trim()
    if ($name -cne $InflectionInfo.Name) {
      "Inflection '$($InflectionInfo.Name)' not found at $($InflectionInfo.SCol)$($InflectionInfo.SRow+1)." | New-Error
      return
    }

    $InflectionInfo
  }
}

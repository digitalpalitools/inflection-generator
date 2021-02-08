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
  }
}

function Read-Inflection {
  param (
    [Parameter(ValueFromPipeline = $true)]
    $Csv
  )

  Begin {
    $header = @(@("", ("A".."Z")) | ForEach-Object { $_ } | ForEach-Object { $c1 = $_; "A".."Z" | ForEach-Object { $c2 = $_; "$c1$c2" } })
  }

  Process {
    ConvertFrom-Csv $Csv -Header $header
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

    @{
      Id = $id
      Name = $Index.name.Trim()
      SRow = [int] ($Matches[2] - 1)
      SCol = $Matches[1]
      ERow = [int] ($Matches[4] - 1)
      ECol = $Matches[3]
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
    $name = $InflectionCsv[$InflectionInfo.SRow]."$($InflectionInfo.SCol)"
    if ($name -cne $InflectionInfo.Name) {
      "Inflection '$($InflectionInfo.Name)' not found at $($InflectionInfo.SCol)$($InflectionInfo.SRow+1)." | New-Error
      return
    }

    $InflectionInfo
  }
}

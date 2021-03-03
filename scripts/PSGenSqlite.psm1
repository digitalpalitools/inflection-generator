$ArrayOf5EmptyStrings = @("", "", "", "", "")

function CreateInflectionCsvColumns {
  @(
    @("", ("A".."Z"))
    | ForEach-Object { $_ }
    | ForEach-Object {
      $c1 = $_
      "A".."Z" | ForEach-Object { $c2 = $_; "$c1$c2" } }
  )
}

New-Variable -Name 'InflectionCsvColumns' -Option ReadOnly -Force -Value $(CreateInflectionCsvColumns)

function CreateInflectionCsvColumnIndices {
  $i = 0;
  $map = @{};

  $InflectionCsvColumns
  | ForEach-Object {
    $map.($_) = $i; $i++
  }

  $map
}

New-Variable -Name 'InflectionCsvColumnIndices' -Option ReadOnly -Force -Value $(CreateInflectionCsvColumnIndices)

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

function Get-InflectionClass {
  param (
    $Abbreviations,
    [Parameter(ValueFromPipeline = $true)]
    $Pattern
  )

  Process {
    $name = $Pattern.Trim()

    $inflectionClass = ""
    if ($name -match "pron 1st$") {
      $inflectionClass = "pron1st"
    } elseif ($name -match "pron 2nd$") {
      $inflectionClass = "pron2nd"
    } elseif ($name -match "pron dual$") {
      $inflectionClass = "prondual"
    } elseif ($name.Split(" ")[1] -and $Abbreviations.$($name.Split(" ")[1]).isverb) {
      $inflectionClass = "verb"
    }

    $inflectionClass
  }
}

function Read-IndexCsv {
  param (
    $Abbreviations,
    [Parameter(ValueFromPipeline = $true)]
    $Csv
  )

  Process {
    ConvertFrom-Csv $Csv -Header @("name", "bounds", "exampleinfo")
    | ForEach-Object {
      $name = $_.name | TrimWithNull
      @{
        name = $name
        inflectionclass = $name | Get-InflectionClass $Abbreviations
        bounds = $_.bounds | TrimWithNull
        exampleinfo = $_.exampleinfo | TrimWithNull
      }
    }
    | Where-Object { $_.name -or $_.bounds -or $_.exampleinfo }
  }
}

function Read-StemsCsv {
  param (
    [Parameter(ValueFromPipeline = $true)]
    $Csv
  )

  Process {
    ConvertFrom-Csv $Csv
    | ForEach-Object {
      @{
        pāli1 = $_.pāli1 | TrimWithNull
        stem = $_.stem | TrimWithNull
        pattern = $_.pattern | TrimWithNull
      }
    }
    | Where-Object { $_.pāli1 -and $_.stem }
  }
}

function Read-AbbreviationsCsv {
  param (
    [Parameter(ValueFromPipeline = $true)]
    $Csv
  )

  Process {
    $abbreviations = @{}

    ConvertFrom-Csv $Csv -Header @("name", "description", "isgrammar", "isverb")
    | Where-Object { $_.name -and $_.description }
    | ForEach-Object {
      $name = $_.name | TrimWithNull
      $abbreviations.$name = @{
        name = $name
        description = $_.description | TrimWithNull
        isgrammar = ($_.isgrammar  | TrimWithNull) -ceq "gram"
        isverb = ($_.isverb | TrimWithNull) -ceq "verb"
      }
    }

    # NOTE: Add empty grammar for "in comps"
    $abbreviations."" = @{ name = ""; description = "grammar absent"; isgrammar = $True; isverb = $False }

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

    if ((-not $Index.name) -or (-not $Index.bounds) -or (-not $Index.exampleinfo)) {
      "Index row $id must have name, bounds and example info." | New-Error
      return
    }

    if (-not ($Index.bounds -match '^([A-Z]+)([0-9]+):([A-Z]+)([0-9]+)$')) {
      "Index row $id has invalid bounds." | New-Error
      return
    }

    $name = $Index.name
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
      id = $id
      name = $name
      inflectionclass = $Index.inflectionclass
      grammarparts = ($Index.inflectionclass -eq "verb") ? 4 : 3
      rowoffset = ($Index.inflectionclass -eq "verb") ? 2 : 1 # NOTE: Verbs have the active / reflexive overarching row
      srow = $sRow
      scol = $sCol
      erow = $eRow
      ecol = $eCol
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
    if ($name -cne $InflectionInfo.name) {
      "Inflection '$($InflectionInfo.name)' not found at $($InflectionInfo.SCol)$($InflectionInfo.SRow+1)." | New-Error
      return
    }

    $inflection = @{ info = $InflectionInfo; entries = @{} }
    $sCol = $InflectionCsvColumnIndices.$($InflectionInfo.SCol)
    $eCol = $InflectionCsvColumnIndices.$($InflectionInfo.ECol)

    for ($i = $InflectionInfo.SRow + $inflection.info.rowoffset; $i -le $InflectionInfo.ERow; $i += 1) {
      for ($j = $sCol + 1; $j -le $eCol; $j += 2) {
        $inf = $InflectionCsv[$i].$($InflectionCsvColumns[$j]) | TrimWithNull
        $gra = $InflectionCsv[$i].$($InflectionCsvColumns[$j + 1]) | TrimWithNull
        if ($inf) {
          $entryKey = "{0:d2}x{1:d2}-$gra" -f $i,$j
          $inflection.entries.$entryKey = @{
            grammar = $ArrayOf5EmptyStrings[0..($inflection.info.grammarparts - 1)] # NOTE: default is array of empty strings for "in comps"
            allInflections = $inf
            inflections = $inf.Split("`n") | ForEach-Object { $_ | TrimWithNull } | Where-Object { $_}
          }

          if ($gra) {
            $inflection.entries.$entryKey.grammar = $gra.Split(" ") | Where-Object { $_ }
          }

          # NOTE: Prepend "act" so all grammars have either act or refxl
          if (($inflection.info.inflectionclass -eq "verb") -and ($inflection.entries.$entryKey.grammar.length -ne 4)) {
            $inflection.entries.$entryKey.grammar = @("act") + $inflection.entries.$entryKey.grammar
          }
        }
      }
    }

    $errors = @()

    $errors +=
      $inflection.entries.Keys
      | ForEach-Object { $inflection.entries[$_].grammar }
      | Where-Object { -not ($Abbreviations.ContainsKey($_) -and $Abbreviations.$_.isgrammar) }
      | ForEach-Object {
        "Inflection '$($inflection.info.name)' has unrecognized grammar '$_'." | New-Error
      }

    $errors +=
      $inflection.entries.Keys
      | Where-Object { $inflection.entries[$_].grammar.Length -ne $inflection.info.grammarparts }
      | ForEach-Object {
        "Inflection '$($inflection.info.name)':'$($inflection.entries[$_].grammar -join " ")' was expected to have '$($inflection.info.grammarparts)' grammar entries, instead has '$($inflection.entries[$_].grammar.Length)' grammar entries." | New-Error
      }

    $errors +=
      $inflection.entries.Keys
      | ForEach-Object { $inflection.entries[$_].inflections }
      | Where-Object {
        ($_ -notmatch "^[a|ā|i|ī|u|ū|e|o|k|kh|g|gh|ṅ|c|ch|j|jh|ñ|ṭ|ṭh|ḍ|ḍh|ṇ|t|th|d|dh|n|p|ph|b|bh|m|y|r|l|v|s|h|ḷ|ṃ]+$")
      }
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

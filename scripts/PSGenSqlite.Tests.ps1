BeforeAll {
  Import-Module $PSScriptRoot/PSGenSqlite.psm1 -Force

  function InflectionInfo2String {
    param(
      [Parameter(ValueFromPipeline = $true)]
      $IInfo
    )

    Process {
      if ($IInfo.error) {
        $IInfo.error
      } else {
        "$($IInfo.Id), $($IInfo.Name), $($IInfo.Pos), $($IInfo.SRow), $($IInfo.SCol), $($IInfo.ERow), $($IInfo.ECol)"
      }
    }
  }

  $Abbreviations = @{
    masc = @{ name = "masc"; description = "masculine" }
    nom = @{ name = "nom"; description = "nominative" }
    sg = @{ name = "sg"; description = "singular" }
    pl = @{ name = "pl"; description = "plural" }
    acc = @{ name = "acc"; description = "accusative" }
    "" = @{ name = "in comps"; description = "in compounds" }
  }
}

Describe "GenSqlite Tests" {
  Context "Import-InflectionIndices" {
    It "Basic test" {
      $index = @'
a adj,A3:M12
,A14:M23
in adj,A25:M3 4
ant adj,AZ136:BB137,x,x,
ī adj
a pron,AC23:AF31
abc pron,AC23:AC25
xxx card,AC23:AG23
a root1,A3:M12
'@
      | Read-IndexCsv

      $indices = $index | Import-InflectionInfos
      $indices.Length | Should -Be 9
      $indices[0] | InflectionInfo2String | Should -BeExactly "1, a adj, adj, 2, A, 11, M"
      $indices[1].error | Should -BeExactly "Index row 2 is invalid."
      $indices[2].error | Should -BeExactly "Index row 3 has invalid bounds."
      $indices[3] | InflectionInfo2String | Should -BeExactly "4, ant adj, adj, 135, AZ, 136, BB"
      $indices[4].error | Should -BeExactly "Index row 5 is invalid."
      $indices[5].error | Should -BeExactly "Inflection 'a pron' must have even number of columns (grammar and inflection)."
      $indices[6].error | Should -BeExactly "Inflection 'abc pron' location must have start row and col less than end row and col."
      $indices[7].error | Should -BeExactly "Inflection 'xxx card' location must have start row and col less than end row and col."
      $indices[8].error | Should -BeExactly "Inflection 'a root1' is for an unknown part of speech."
    }
  }

  Context "Import-Inflection" {
    It "Basic test" {
      $ii = @{ Id = 1; Name = "eka card"; Pos = "card"; SRow = 1; SCol = "Y"; ERow = 4; ECol = "AB" }
      $inflection = @'
,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,eka card,masc sg,,masc pl,
,,,,,,,,,,,,,,,,,,,,,,,,nom,eko,masc nom sg,eke,masc nom pl
,,,,,,,,,,,,,,,,,,,,,,,,acc,ekaṃ,masc acc sg,eke,masc acc pl
,,,,,,,,,,,,,,,,,,,,,,,,in comps,a,,,
'@ | Read-InflectionsCsv

      $i = $ii | Import-Inflection $inflection $Abbreviations
      $i.info | InflectionInfo2String | Should -BeExactly "1, eka card, card, 1, Y, 4, AB"
      $i.entries.Count | Should -Be 5
      $i.entries."masc nom sg" | Should -BeExactly "eko"
      $i.entries."masc nom pl" | Should -BeExactly "eke"
      $i.entries."masc acc sg" | Should -BeExactly "ekaṃ"
      $i.entries."masc acc pl" | Should -BeExactly "eke"
      $i.entries."" | Should -BeExactly "a"
    }

    It "Error if not found at index" {
      $ii = @{ Id = 1; Name = "x adx"; SRow = 0; SCol = "B"; ERow = 1; ECol = "C" }
      $inflection = ",`n,x adx" | Read-InflectionsCsv

      $i = $ii | Import-Inflection $inflection $Abbreviations
      $i.error | Should -BeExactly "Inflection 'x adx' not found at B1."
      $i.info | Should -Be $null
    }

    It "Pass through errors" {
      $ii = @{ Error = "Some error" }

      $i = $ii | Import-Inflection $inflection $Abbreviations
      $i.error | Should -BeExactly "Some error"
      $i.info | Should -Be $null
    }

    It "Grammar has 1 error" {
      $ii = @{ Id = 1; Name = "eka card"; SRow = 0; SCol = "A"; ERow = 2; ECol = "D" }
      $inflection = @'
eka card,masc sg,,masc pl,
nom,eko,masc nom sg,eke,masc nom plx
acc,ekaṃ,masc acc sg,eke,masc acc pl
'@ | Read-InflectionsCsv

      $i = $ii | Import-Inflection $inflection $Abbreviations | Sort-Object
      $i.info | Should -Be $null
      $i.error | Should -BeExactly "Inflection 'eka card' has invalid grammar 'plx'."
    }

    It "Grammar has multiple errors" {
      $ii = @{ Id = 1; Name = "eka card"; SRow = 0; SCol = "A"; ERow = 2; ECol = "D" }
      $inflection = @'
eka card,masc sg,,masc pl,
nom,eko,masc nom sg,eke,masc nom plx
acc,ekaṃ,1masc acc sg,eke,masc acc pl
'@ | Read-InflectionsCsv

      $i = $ii | Import-Inflection $inflection $Abbreviations | Sort-Object -Property error
      $i[0].info | Should -Be $null
      $i[0].error | Should -BeExactly "Inflection 'eka card' has invalid grammar '1masc'."
      $i[1].info | Should -Be $null
      $i[1].error | Should -BeExactly "Inflection 'eka card' has invalid grammar 'plx'."
    }
  }
}

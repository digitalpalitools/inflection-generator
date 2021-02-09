BeforeAll {
  Import-Module $PSScriptRoot/PSGenSqlite.psm1 -Force

  function InflectionInfo2String {
    param(
      [Parameter(ValueFromPipeline = $true)]
      $IInfo
    )

    Process {
      if ($IInfo.Error) {
        $IInfo.Error
      } else {
        "$($IInfo.Id), $($IInfo.Name), $($IInfo.SRow), $($IInfo.SCol), $($IInfo.ERow), $($IInfo.ECol)"
      }
    }
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
abc,AC23:AC25
xxx,AC23:AG23
'@
      | Read-Index

      $indices = $index | Import-InflectionInfos
      $indices.Length | Should -Be 8
      $indices[0] | InflectionInfo2String | Should -BeExactly "1, a adj, 2, A, 11, M"
      $indices[1].Error | Should -BeExactly "Index row 2 is invalid."
      $indices[2].Error | Should -BeExactly "Index row 3 has invalid bounds."
      $indices[3] | InflectionInfo2String | Should -BeExactly "4, ant adj, 135, AZ, 136, BB"
      $indices[4].Error | Should -BeExactly "Index row 5 is invalid."
      $indices[5].Error | Should -BeExactly "Inflection 'a pron' must have even number of columns (grammar and inflection)."
      $indices[6].Error | Should -BeExactly "Inflection 'abc' location must have start row and col less than end row and col."
      $indices[7].Error | Should -BeExactly "Inflection 'xxx' location must have start row and col less than end row and col."
    }
  }

  Context "Import-Inflection" {
    It "Basic test" {
      $ii = @{ Id = 1; Name = "eka card"; SRow = 1; SCol = "Y"; ERow = 3; ECol = "AB" }
      $inflection = @'
,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,eka card,masc sg,,masc pl,
,,,,,,,,,,,,,,,,,,,,,,,,nom,eko,masc nom sg,eke,masc nom pl
,,,,,,,,,,,,,,,,,,,,,,,,acc,ekaṃ,masc acc sg,eke,masc acc pl
'@ | Read-Inflection

      $i = $ii | Import-Inflection $inflection
      $i.info | InflectionInfo2String | Should -BeExactly "1, eka card, 1, Y, 3, AB"
      $i.entries.Count | Should -Be 4
      $i.entries."masc nom sg" | Should -BeExactly "eko"
      $i.entries."masc nom pl" | Should -BeExactly "eke"
      $i.entries."masc acc sg" | Should -BeExactly "ekaṃ"
      $i.entries."masc acc pl" | Should -BeExactly "eke"
    }

    It "Error if not found at index" {
      $ii = @{ Id = 1; Name = "x adx"; SRow = 0; SCol = "B"; ERow = 1; ECol = "C" }
      $inflection = ",`n,x adx" | Read-Inflection

      $i = $ii | Import-Inflection $inflection
      $i.Error | Should -BeExactly "Inflection 'x adx' not found at B1."
    }

    It "Pass through errors" {
      $ii = @{ Error = "Some error" }

      $i = $ii | Import-Inflection $inflection
      $i.Error | Should -BeExactly "Some error"
    }
  }
}

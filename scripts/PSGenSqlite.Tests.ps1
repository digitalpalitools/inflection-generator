BeforeAll {
  Import-Module $PSScriptRoot/PSGenSqlite.psm1 -Force

  function InflectionInfo2String {
    param($IInfo)

    Begin {
      "$($IInfo.Id), $($IInfo.Name), $($IInfo.SRow), $($IInfo.SCol), $($IInfo.ERow), $($IInfo.ECol)"
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
ant adj,AZ136:M5,x,x,
ī adj
'@
      | Read-Index

      $indices = $index | Import-InflectionInfos
      $indices.Length | Should -Be 5
      InflectionInfo2String $indices[0] | Should -BeExactly "1, a adj, 2, A, 11, M"
      $indices[1].Error | Should -BeExactly "Index row 2 is invalid."
      $indices[2].Error | Should -BeExactly "Index row 3 has invalid bounds."
      InflectionInfo2String $indices[3] | Should -BeExactly "4, ant adj, 135, AZ, 4, M"
      $indices[4].Error | Should -BeExactly "Index row 5 is invalid."
    }
  }

  Context "Import-InflectionIndices" {
    It "Basic test" {
      $ii = @{ Id = 1; Name = "x adx"; SRow = 1; SCol = "B"; ERow = 1; ECol = "C" }
      $inflection = ",`n,x adx" | Read-Inflection

      $i = $ii | Test-InflectionInfo $inflection
      InflectionInfo2String $i | Should -BeExactly "1, x adx, 1, B, 1, C"
    }

    It "Error if not found at index" {
      $ii = @{ Id = 1; Name = "x adx"; SRow = 0; SCol = "B"; ERow = 1; ECol = "C" }
      $inflection = ",`n,x adx" | Read-Inflection

      $i = $ii | Test-InflectionInfo $inflection
      $i.Error | Should -BeExactly "Inflection 'x adx' not found at B1."
    }
  }
}

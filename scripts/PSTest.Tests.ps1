BeforeAll {
  Import-Module $PSScriptRoot/PSTest.psm1 -Force
}

Describe "Merge-Dirs" {
  Context "Main context" {
    It "Basic test" {
      $srcDir = "c:\a"
      $dstDir = "c:\b"

      $srcDir
      | Merge-Dirs $dstDir
      | Should -BeExactly "c:\b-c:\a"
    }
  }
}

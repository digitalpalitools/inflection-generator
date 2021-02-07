param (
  [Parameter(Mandatory)]
  $SrcDir,
  [Parameter(Mandatory)]
  $DstDir
)

Import-Module $PSScriptRoot/PSTest.psm1 -Force

Merge-Dirs $SrcDir $DstDir

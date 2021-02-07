function Merge-Dirs {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    $SrcDir,
    [Parameter(ValueFromPipeline = $true, Mandatory)]
    $DstDir
)

  Process {
    "$SrcDir-$DstDir"
  }
}

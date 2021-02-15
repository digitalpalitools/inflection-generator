BeforeAll {
  Import-Module $PSScriptRoot/PSGenSqlite.psm1 -Force

  function InflectionInfo2String {
    param(
      [Parameter(ValueFromPipeline = $true)]
      $Info
    )

    Process {
      if ($Info.error) {
        $Info.error
      } else {
        "$($Info.id), $($Info.name), $($Info.isverb), $($Info.grammarparts), $($Info.rowoffset), $($Info.srow), $($Info.scol), $($Info.erow), $($Info.ecol)"
      }
    }
  }

  $Abbreviations = @{
    masc = @{ name = "masc"; description = "masculine"; isgrammar = $True; isverb = $False }
    nom = @{ name = "nom"; description = "nominative"; isgrammar = $True; isverb = $False }
    sg = @{ name = "sg"; description = "singular"; isgrammar = $True; isverb = $False }
    pl = @{ name = "pl"; description = "plural"; isgrammar = $True; isverb = $False }
    acc = @{ name = "acc"; description = "accusative"; isgrammar = $True; isverb = $False }
    dual = @{ name = "dual"; description = "dual"; isgrammar = $True; isverb = $False }
    act = @{ name = "act"; description = "active"; isgrammar = $True; isverb = $False }
    reflx = @{ name = "reflx"; description = "reflexive"; isgrammar = $True; isverb = $False }
    "1st" = @{ name = "1st"; description = "1st person"; isgrammar = $True; isverb = $False }
    "2nd" = @{ name = "2nd"; description = "2nd person"; isgrammar = $True; isverb = $False }
    "3rd" = @{ name = "3rd"; description = "3rd person"; isgrammar = $True; isverb = $False }
    pr = @{ name = "pr"; description = "present"; isgrammar = $True; isverb = $True }
    fut = @{ name = "fut"; description = "future"; isgrammar = $True; isverb = $True }
    aor = @{ name = "aor"; description = "aorist"; isgrammar = $True; isverb = $True }
    opt = @{ name = "opt"; description = "optative"; isgrammar = $True; isverb = $True }
    imp = @{ name = "imp"; description = "imperative"; isgrammar = $True; isverb = $True }
    cond = @{ name = "cond"; description = "conditional"; isgrammar = $True; isverb = $True }
    imperf = @{ name = "imperf"; description = "imperfect"; isgrammar = $True; isverb = $True }
    perf = @{ name = "perf"; description = "perfect"; isgrammar = $True; isverb = $True }
    irreg = @{ name = "irreg"; description = "irregular"; isgrammar = $False; isverb = $False }
    "" = @{ name = "-"; description = "grammar absent"; isgrammar = $True; isverb = $False }
  }
}

Describe "GenSqlite Tests" {
  Context "Import-InflectionIndices" {
    It "Basic test" {
      $index = @'
a adj,A3:M12
,A14:M23
in adj,A25:M3 4
atthu imp,AZ136:BB137,x,x,
ī adj
a pron,AC23:AF31
abc pron,AC23:AC25
xxx card,AC23:AG23
'@
      | Read-IndexCsv

      $indices = $index | Import-InflectionInfos $Abbreviations
      $indices.Length | Should -Be 8
      $indices[0] | InflectionInfo2String | Should -BeExactly "1, a adj, False, 3, 1, 2, A, 11, M"
      $indices[1].error | Should -BeExactly "Index row 2 is invalid."
      $indices[2].error | Should -BeExactly "Index row 3 has invalid bounds."
      $indices[3] | InflectionInfo2String | Should -BeExactly "4, atthu imp, True, 4, 2, 135, AZ, 136, BB"
      $indices[4].error | Should -BeExactly "Index row 5 is invalid."
      $indices[5].error | Should -BeExactly "Inflection 'a pron' must have even number of columns (grammar and inflection)."
      $indices[6].error | Should -BeExactly "Inflection 'abc pron' location must have start row and col less than end row and col."
      $indices[7].error | Should -BeExactly "Inflection 'xxx card' location must have start row and col less than end row and col."
    }
  }

  Context "Import-Inflection" {
    It "Basic test" {
      $ii = 'eka card,Y2:AC5' | Read-IndexCsv | Import-InflectionInfos $Abbreviations
      $inflection = @'
,,,,,,,,,,,,,,,,,,,,,,,,,
,,,,,,,,,,,,,,,,,,,,,,,,eka card,masc sg,,masc pl,
,,,,,,,,,,,,,,,,,,,,,,,,nom,eko,masc nom sg,eke,masc nom pl
,,,,,,,,,,,,,,,,,,,,,,,,acc,ekaṃ,masc acc sg,eke,masc acc pl
,,,,,,,,,,,,,,,,,,,,,,,,in comps,a,,,
'@ | Read-InflectionsCsv

      $i = $ii | Import-Inflection $inflection $Abbreviations
      $i.info | InflectionInfo2String | Should -BeExactly "1, eka card, False, 3, 1, 1, Y, 4, AC"
      $i.entries.Count | Should -Be 5

      $i.entries."02x25-masc nom sg".grammar | Should -BeExactly @("masc", "nom", "sg")
      $i.entries."02x25-masc nom sg".allInflections | Should -BeExactly "eko"
      $i.entries."02x25-masc nom sg".inflections | Should -BeExactly @("eko")

      $i.entries."02x27-masc nom pl".grammar | Should -BeExactly @("masc", "nom", "pl")
      $i.entries."02x27-masc nom pl".allInflections | Should -BeExactly "eke"
      $i.entries."02x27-masc nom pl".inflections | Should -BeExactly @("eke")

      $i.entries."03x25-masc acc sg".grammar | Should -BeExactly @("masc", "acc", "sg")
      $i.entries."03x25-masc acc sg".allInflections | Should -BeExactly "ekaṃ"
      $i.entries."03x25-masc acc sg".inflections | Should -BeExactly @("ekaṃ")

      $i.entries."03x27-masc acc pl".grammar | Should -BeExactly @("masc", "acc", "pl")
      $i.entries."03x27-masc acc pl".allInflections | Should -BeExactly "eke"
      $i.entries."03x27-masc acc pl".inflections | Should -BeExactly @("eke")

      $i.entries."04x25-".grammar | Should -BeExactly @("", "", "")
      $i.entries."04x25-".allInflections | Should -BeExactly "a"
      $i.entries."04x25-".inflections | Should -BeExactly @("a")
    }

    It "Error if not found at index" {
      $ii = 'x adx,B1:D4' | Read-IndexCsv | Import-InflectionInfos $Abbreviations
      $inflection = @"
,
,x adx
"@ | Read-InflectionsCsv

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
      $ii = 'eka card,A1:E3' | Read-IndexCsv | Import-InflectionInfos $Abbreviations
      $inflection = @'
eka card,masc sg,,masc pl,
nom,eko,masc nom sg,eke,masc nom plx
acc,ekaṃ,masc acc sg,eke,masc acc pl
'@ | Read-InflectionsCsv

      $i = $ii | Import-Inflection $inflection $Abbreviations | Sort-Object
      $i.info | Should -Be $null
      $i.error | Should -BeExactly "Inflection 'eka card' has unrecognized grammar 'plx'."
    }

    It "Grammar has multiple errors" {
      $ii = 'eka card,A1:E3' | Read-IndexCsv | Import-InflectionInfos $Abbreviations
      $inflection = @'
eka card,masc sg,,masc pl,
nom,eko,masc nom sg,eke,masc nom irreg
acc,ekaṃ,1masc acc sg,eke,masc acc pl
'@ | Read-InflectionsCsv

      $i = $ii | Import-Inflection $inflection $Abbreviations | Sort-Object -Property error
      $i[0].info | Should -Be $null
      $i[0].error | Should -BeExactly "Inflection 'eka card' has unrecognized grammar '1masc'."
      $i[1].info | Should -Be $null
      $i[1].error | Should -BeExactly "Inflection 'eka card' has unrecognized grammar 'irreg'."
    }

    It "Grammar does not have expected entries" {
      $ii = 'eka adj,A1:E3' | Read-IndexCsv | Import-InflectionInfos $Abbreviations
      $inflection = @'
eka adj,masc sg,,masc pl,
nom,eko,masc sg,eke,masc nom pl
acc,ekaṃ,masc acc sg,eke,masc acc pl dual
'@ | Read-InflectionsCsv

      $i = $ii | Import-Inflection $inflection $Abbreviations | Sort-Object -Property error
      $i[0].info | Should -Be $null
      $i[0].error | Should -BeExactly "Inflection 'eka adj':'masc acc pl dual' was expected to have '3' grammar entries, instead has '4' grammar entries."
      $i[1].info | Should -Be $null
      $i[1].error | Should -BeExactly "Inflection 'eka adj':'masc sg' was expected to have '3' grammar entries, instead has '2' grammar entries."
    }

    It "Inflection does not have non pāli characters" {
      $ii = 'eka adj,A1:E3' | Read-IndexCsv | Import-InflectionInfos $Abbreviations
      $inflection = @'
eka adj,masc sg,,masc pl,
nom,ek7o,masc nom sg,eke,masc nom pl
acc,ekaṃ,masc acc sg,~eke,masc acc pl
'@ | Read-InflectionsCsv

      $i = $ii | Import-Inflection $inflection $Abbreviations | Sort-Object -Property error
      $i[0].info | Should -Be $null
      $i[0].error | Should -BeExactly "Inflection 'eka adj':'~eke' cannot have invalid characters."
      $i[1].info | Should -Be $null
      $i[1].error | Should -BeExactly "Inflection 'eka adj':'ek7o' cannot have invalid characters."
    }

    It "Expand active verb category" {
      $ii = @{ Id = 1; Name = "ati pr"; Pos = "pr"; SRow = 0; SCol = "A"; ERow = 4; ECol = "H" }
      $ii = 'ati pr,A1:I5' | Read-IndexCsv | Import-InflectionInfos $Abbreviations
      $inflection = @"
ati pr,active,,,,reflexive,,,
,sg,,pl,,sg,,pl,
pr 3rd,ati,pr 3rd sg,anti,pr 3rd pl,ate,reflx pr 3rd sg,ante,reflx pr 3rd pl
pr 2nd,asi,pr 2nd sg,atha,pr 2nd pl,ase,reflx pr 2nd sg,avhe,reflx pr 2nd pl
"@ | Read-InflectionsCsv

      $i = $ii | Import-Inflection $inflection $Abbreviations
      $i.info | InflectionInfo2String | Should -BeExactly "1, ati pr, True, 4, 2, 0, A, 4, I"
      $i.entries.Count | Should -Be 8

      $i.entries."02x01-pr 3rd sg".grammar | Should -BeExactly @("act", "pr", "3rd", "sg")
      $i.entries."02x01-pr 3rd sg".allInflections | Should -BeExactly "ati"
      $i.entries."02x01-pr 3rd sg".inflections | Should -BeExactly @("ati")

      $i.entries."02x07-reflx pr 3rd pl".grammar | Should -BeExactly @("reflx", "pr", "3rd", "pl")
      $i.entries."02x07-reflx pr 3rd pl".allInflections | Should -BeExactly "ante"
      $i.entries."02x07-reflx pr 3rd pl".inflections | Should -BeExactly @("ante")
    }
  }

  Context "Read CSVs" {
    It "Read Stem CSV" {
      $stems = @'
Pāli1,Stem,Pattern
pali1,*,pat1
pali2 ,- ,pat2
pali3_,s_3_,pat3_
,x,pat3
x, ,pat3
'@
      | Read-StemsCsv

      $stems.pāli1 | Should -BeExactly @("pali1", "pali2", "pali3_")
      $stems.stem | Should -BeExactly @("*", "-", "s_3_")
      $stems.pattern | Should -BeExactly @("pat1", "pat2", "pat3_")
    }
  }
}

[![Continuous Integration](https://github.com/digitalpalitools/inflection-generator/workflows/Continuous%20Integration/badge.svg)](https://github.com/digitalpalitools/inflection-generator/actions?query=workflow%3A%22Continuous+Integration%22) [![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

# Digital Pāli Tools - Inflection Generator

Generate a sqlite db for the inflection schema.

# Instructions

## Generate db

- Manual
  - Export [master workbook](https://docs.google.com/spreadsheets/d/1j6SSGf519bkrPqgMn7PhQ5rv309zGRp5R5-sKBLzY30/edit?usp=sharing) as xlxs
  - Run
    ```python xlsx2csv.py 'declensions & conjugations.xlsx' ./csvs --all```
  - Commit the above changes
- Automated in CI
  - Generate-SqliteScripts.ps1 ../csvs
  - sqlite3 ./build/inflexctions.sql ./build/dpt-inflexctions.db

> Every CI if successful will publish the .sql and .db as package

## Run unit tests

- ```npm i nodemon -g```
- ```nodemon --ext ps1,psm1 --ignore .\cscd --exec 'pwsh.exe -NoProfile -NoLogo -NonInteractive -Command \"& { Invoke-Pester -Path ./scripts }\"'```

# Dependencies

- [xlsx2csv](https://raw.githubusercontent.com/dilshod/xlsx2csv/master/xlsx2csv.py)

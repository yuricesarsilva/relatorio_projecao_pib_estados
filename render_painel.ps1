$ErrorActionPreference = "Stop"

$projeto = Split-Path -Parent $MyInvocation.MyCommand.Path
$quarto = "C:\Program Files\RStudio\resources\app\bin\quarto\bin\quarto.exe"
$rprofile = Join-Path $projeto ".Rprofile"

if (-not (Test-Path $quarto)) {
  throw "Quarto nao encontrado em '$quarto'."
}

if (-not (Test-Path $rprofile)) {
  throw ".Rprofile nao encontrado em '$rprofile'."
}

$env:R_PROFILE_USER = $rprofile
& $quarto render "painel/painel.qmd"

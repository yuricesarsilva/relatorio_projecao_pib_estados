args <- commandArgs(trailingOnly = TRUE)

projeto <- normalizePath(".", winslash = "/", mustWork = TRUE)
quarto <- "C:/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.exe"
rprofile <- file.path(projeto, ".Rprofile")
activate <- file.path(projeto, "renv/activate.R")

if (!file.exists(quarto)) {
  stop("Quarto nao encontrado em '", quarto, "'.", call. = FALSE)
}

if (!file.exists(rprofile)) {
  stop(".Rprofile nao encontrado em '", rprofile, "'.", call. = FALSE)
}

if (!file.exists(activate)) {
  stop("renv/activate.R nao encontrado em '", activate, "'.", call. = FALSE)
}

source(activate, local = FALSE)
renv_lib <- normalizePath(.libPaths()[1], winslash = "/", mustWork = TRUE)

env_antigo <- Sys.getenv(c("R_PROFILE_USER", "R_LIBS_USER", "RENV_PROJECT"), unset = NA)
on.exit({
  if (is.na(env_antigo[["R_PROFILE_USER"]])) Sys.unsetenv("R_PROFILE_USER") else Sys.setenv(R_PROFILE_USER = env_antigo[["R_PROFILE_USER"]])
  if (is.na(env_antigo[["R_LIBS_USER"]])) Sys.unsetenv("R_LIBS_USER") else Sys.setenv(R_LIBS_USER = env_antigo[["R_LIBS_USER"]])
  if (is.na(env_antigo[["RENV_PROJECT"]])) Sys.unsetenv("RENV_PROJECT") else Sys.setenv(RENV_PROJECT = env_antigo[["RENV_PROJECT"]])
}, add = TRUE)

Sys.setenv(
  R_PROFILE_USER = rprofile,
  R_LIBS_USER = renv_lib,
  RENV_PROJECT = projeto
)

status <- system2(
  command = quarto,
  args = c("preview", "painel/painel.qmd", args),
  stdout = "",
  stderr = ""
)

if (!identical(status, 0L)) {
  stop("Falha ao abrir o preview do painel via Quarto.", call. = FALSE)
}

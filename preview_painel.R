args <- commandArgs(trailingOnly = TRUE)

projeto <- normalizePath(".", winslash = "/", mustWork = TRUE)
quarto <- "C:/Program Files/RStudio/resources/app/bin/quarto/bin/quarto.exe"
r_home <- "C:/Program Files/R/R-4.4.0"
r_bin <- file.path(r_home, "bin")
rprofile <- file.path(projeto, ".Rprofile")
activate <- file.path(projeto, "renv/activate.R")

if (!file.exists(quarto)) {
  stop("Quarto nao encontrado em '", quarto, "'.", call. = FALSE)
}

if (!dir.exists(r_bin)) {
  stop("Diretorio do R nao encontrado em '", r_bin, "'.", call. = FALSE)
}

if (!file.exists(rprofile)) {
  stop(".Rprofile nao encontrado em '", rprofile, "'.", call. = FALSE)
}

if (!file.exists(activate)) {
  stop("renv/activate.R nao encontrado em '", activate, "'.", call. = FALSE)
}

source(activate, local = FALSE)
renv_lib <- normalizePath(.libPaths()[1], winslash = "/", mustWork = TRUE)

env_antigo <- Sys.getenv(
  c("R_PROFILE_USER", "R_LIBS_USER", "RENV_PROJECT", "R_HOME", "PATH"),
  unset = NA
)
on.exit({
  if (is.na(env_antigo[["R_PROFILE_USER"]])) Sys.unsetenv("R_PROFILE_USER") else Sys.setenv(R_PROFILE_USER = env_antigo[["R_PROFILE_USER"]])
  if (is.na(env_antigo[["R_LIBS_USER"]])) Sys.unsetenv("R_LIBS_USER") else Sys.setenv(R_LIBS_USER = env_antigo[["R_LIBS_USER"]])
  if (is.na(env_antigo[["RENV_PROJECT"]])) Sys.unsetenv("RENV_PROJECT") else Sys.setenv(RENV_PROJECT = env_antigo[["RENV_PROJECT"]])
  if (is.na(env_antigo[["R_HOME"]])) Sys.unsetenv("R_HOME") else Sys.setenv(R_HOME = env_antigo[["R_HOME"]])
  if (is.na(env_antigo[["PATH"]])) Sys.unsetenv("PATH") else Sys.setenv(PATH = env_antigo[["PATH"]])
}, add = TRUE)

path_sep <- .Platform$path.sep
path_novo <- paste(c(normalizePath(r_bin, winslash = "/", mustWork = TRUE), env_antigo[["PATH"]]), collapse = path_sep)

Sys.setenv(
  R_PROFILE_USER = rprofile,
  R_LIBS_USER = renv_lib,
  RENV_PROJECT = projeto,
  R_HOME = normalizePath(r_home, winslash = "/", mustWork = TRUE),
  PATH = path_novo
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

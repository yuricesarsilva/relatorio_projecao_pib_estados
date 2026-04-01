library(tidyverse)

# ==============================================================================
# run_all.R
#
# Executa o pipeline completo de projeções dos PIBs estaduais em sequência.
# Rode este script a partir da raiz do projeto (where the .Rproj file is).
#
# Ordem de execução:
#   01_leitura_dados.R   → dados/especiais.rds, dados/conta_producao.rds
#   02_consistencia.R    → verificações (sem saída em disco)
#   03_projecao.R        → dados/selecao_modelos.rds, projecoes_brutas.rds,
#                          projecoes_derivadas.rds, vab_macrossetor_proj.rds
#   04_reconciliacao.R   → dados/projecoes_reconciliadas.rds,
#                          dados/vab_macro_reconciliado.rds
#   05_output.R          → output/tabelas/*.xlsx, output/graficos/*.png
# ==============================================================================

scripts <- c(
  "R/01_leitura_dados.R",
  "R/02_consistencia.R",
  "R/03_projecao.R",
  "R/04_reconciliacao.R",
  "R/05_output.R"
)

# Cache: se selecao_modelos.rds já existir, o 03 pula o CV automaticamente.
# Para forçar reprocessamento completo, remova a pasta dados/ antes de rodar.

t_total <- proc.time()

for (script in scripts) {
  cat("\n", strrep("=", 70), "\n", sep = "")
  cat("Executando:", script, "\n")
  cat(strrep("=", 70), "\n\n", sep = "")

  t0 <- proc.time()

  tryCatch(
    source(script, echo = FALSE, local = FALSE),
    error = function(e) {
      cat("\n*** ERRO em", script, "***\n")
      cat(conditionMessage(e), "\n")
      cat("Pipeline interrompido.\n")
      stop(e)
    }
  )

  elapsed <- round((proc.time() - t0)[["elapsed"]])
  cat("\n[OK]", script, "—", elapsed, "s\n")
}

cat("\n", strrep("=", 70), "\n", sep = "")
cat("Pipeline concluído em",
    round((proc.time() - t_total)[["elapsed"]]), "s\n")
cat(strrep("=", 70), "\n", sep = "")

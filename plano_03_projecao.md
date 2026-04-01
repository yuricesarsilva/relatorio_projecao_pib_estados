Plano: 03_projecao.R

     Contexto

     Script de projeção com múltiplos modelos, validação cruzada (A/B) e seleção do melhor modelo por série.
     Horizonte: 8 anos (2024–2031). Todas as variáveis requeridas pelo projeto são derivadas de um conjunto
     reduzido de séries modeladas diretamente.

     ---
     Séries a modelar diretamente

     Para cobrir todos os outputs requeridos com eficiência, modela-se:

     ┌──────────┬──────────────────────────────────┬────────────────────────────┬──────────────┐
     │  Grupo   │             Variável             │       Transformação        │ Nº de séries │
     ├──────────┼──────────────────────────────────┼────────────────────────────┼──────────────┤
     │ VAB real │ idx_volume por macrossetor × geo │ Nenhuma (já é razão ≈ 1+g) │ 4 × 33 = 132 │
     ├──────────┼──────────────────────────────────┼────────────────────────────┼──────────────┤
     │ Deflator │ idx_preco por macrossetor × geo  │ Nenhuma (já é razão)       │ 4 × 33 = 132 │
     ├──────────┼──────────────────────────────────┼────────────────────────────┼──────────────┤
     │ Impostos │ impostos_nominal por geo         │ log                        │ 33           │
     ├──────────┼──────────────────────────────────┼────────────────────────────┼──────────────┤
     │ Total    │                                  │                            │ 297          │
     └──────────┴──────────────────────────────────┴────────────────────────────┴──────────────┘

     Macrossetores (agregação das atividades da Conta da Produção)

     ┌──────────────┬─────────────────────────────────────────────────────────────────────────────────────────     ┐
     │ Macrossetor  │                                       Atividades
     │
     ├──────────────┼─────────────────────────────────────────────────────────────────────────────────────────     ┤
     │ agropecuaria │ agropecuaria
     │
     ├──────────────┼─────────────────────────────────────────────────────────────────────────────────────────     ┤
     │ industria    │ ind_extrativa + ind_transformacao + eletricidade_gas_agua + construcao
     │
     ├──────────────┼─────────────────────────────────────────────────────────────────────────────────────────     ┤
     │ adm_publica  │ adm_publica
     │
     ├──────────────┼─────────────────────────────────────────────────────────────────────────────────────────     ┤
     │ servicos     │ comercio_veiculos + transporte_armazenagem + informacao_comunicacao +
     │
     │              │ financeiro_seguros + imobiliaria + outros_servicos
     │
     └──────────────┴─────────────────────────────────────────────────────────────────────────────────────────     ┘

     Derivações (não modeladas, calculadas após projeção)

     - VAB nominal por macrossetor = val_corrente_2023 × ∏(idx_volume_t × idx_preco_t)
     - VAB total nominal = soma dos 4 macrossetores
     - PIB nominal = VAB total + impostos
     - Taxa de crescimento PIB real = variação do índice de volume acumulado (∏ idx_volume)
     - Deflator do PIB = variação do PIB nominal / variação do volume acumulado
     - VAB por atividade = distribuição proporcional dentro de cada macrossetor (mantém participações
     históricas médias de 2019–2023)

     ---
     Modelos (9 por série)

     ┌───────────┬───────────────────┬────────────────────────────────┬─────────────────────────────────────┐
     │    ID     │      Modelo       │             Pacote             │             Observação              │
     ├───────────┼───────────────────┼────────────────────────────────┼─────────────────────────────────────┤
     │ rw        │ Random Walk com   │ forecast                       │ Benchmark                           │
     │           │ drift             │                                │                                     │
     ├───────────┼───────────────────┼────────────────────────────────┼─────────────────────────────────────┤
     │ arma      │ ARMA(p,0,q)       │ forecast::auto.arima(d=0)      │ Séries estacionárias (idx)          │
     ├───────────┼───────────────────┼────────────────────────────────┼─────────────────────────────────────┤
     │ arima     │ ARIMA(p,d,q)      │ forecast::auto.arima()         │ Seleção automática                  │
     ├───────────┼───────────────────┼────────────────────────────────┼─────────────────────────────────────┤
     │ sarima    │ SARIMA            │ forecast::auto.arima(D=1,      │ Anual: captura ciclos bienais; sem  │
     │           │                   │ period=2)                      │ sazonalidade clássica               │
     ├───────────┼───────────────────┼────────────────────────────────┼─────────────────────────────────────┤
     │ ets       │ ETS automático    │ forecast::ets()                │ Suavização exponencial              │
     ├───────────┼───────────────────┼────────────────────────────────┼─────────────────────────────────────┤
     │ ets_amort │ ETS com           │ forecast::ets(damped=TRUE)     │ Tendência amortecida                │
     │           │ amortecimento     │                                │                                     │
     ├───────────┼───────────────────┼────────────────────────────────┼─────────────────────────────────────┤
     │ theta     │ Theta             │ forecast::thetaf()             │ Simples, robusto em séries curtas   │
     ├───────────┼───────────────────┼────────────────────────────────┼─────────────────────────────────────┤
     │ prophet   │ Prophet           │ prophet                        │ Tendência + feriados; adaptado para │
     │           │                   │                                │  anual                              │
     ├───────────┼───────────────────┼────────────────────────────────┼─────────────────────────────────────┤
     │ bsts      │ BSTS              │ bsts                           │ Local linear trend + MCMC           │
     └───────────┴───────────────────┴────────────────────────────────┴─────────────────────────────────────┘

     ▎ Nota SARIMA: dados anuais não têm sazonalidade intra-anual clássica. Implementado com period=2 para
     capturar eventuais ciclos bienais (recessão/expansão). auto.arima descartará o componente sazonal se não
     for significativo.

     ---
     Validação cruzada (A/B)

     - Método: janela crescente (expanding window)
     - Treinamento mínimo: 15 anos (2002–2016)
     - Janelas de teste: 7 (avalia previsões para 2017, 2018, ..., 2023)
     - Horizonte de previsão no CV: h = 1 (1-step ahead, mais informativo com série curta)
     - Métricas por série:
       - MASE (principal — independente de escala, comparável entre séries)
       - RMSE, MAE, MAPE (secundárias)
     - Seleção: modelo com menor MASE médio nas 7 janelas

     ---
     Estrutura do script

     Parte 0 — Pacotes e parâmetros
     Parte 1 — Preparação dos dados (agregar macrossetores, montar lista de séries)
     Parte 2 — Funções dos modelos (9 funções, interface uniforme: ts_obj → forecast)
     Parte 3 — Função de CV (tsCV wrapper com métricas)
     Parte 4 — Loop de CV: todas as séries × todos os modelos
     Parte 5 — Seleção do melhor modelo por série
     Parte 6 — Projeção final (fit no período 2002–2023, projetar 2024–2031)
     Parte 7 — Derivações (VAB nominal, PIB, crescimento real, deflator)
     Parte 8 — Salvar outputs

     ---
     Estratégia de performance

     - bsts: 200 iterações MCMC no CV; 2.000 na projeção final
     - Prophet: desabilitar sazonalidade diária/semanal (weekly.seasonality=FALSE, daily.seasonality=FALSE)
     - Paralelização: parallel::mclapply (Unix) ou parallel::parLapply (Windows) para o loop de CV
     - Cache: se dados/selecao_modelos.rds já existir, pular CV e ir direto à projeção final

     ---
     Outputs

     ┌───────────────────────────────┬──────────────────────────────────────────────────────────────────────┐
     │            Arquivo            │                               Conteúdo                               │
     ├───────────────────────────────┼──────────────────────────────────────────────────────────────────────┤
     │ dados/selecao_modelos.rds     │ Melhor modelo por série + métricas CV completas de todos os modelos  │
     ├───────────────────────────────┼──────────────────────────────────────────────────────────────────────┤
     │ dados/projecoes_brutas.rds    │ Projeções 2024–2031 (ponto + IC 80% e 95%) para cada série modelada  │
     ├───────────────────────────────┼──────────────────────────────────────────────────────────────────────┤
     │ dados/projecoes_derivadas.rds │ VAB nominal, PIB nominal, crescimento real, deflator — todos os geos │
     └───────────────────────────────┴──────────────────────────────────────────────────────────────────────┘

     ---
     Pacotes a instalar (se ausentes)

     if (!requireNamespace("prophet", quietly=TRUE)) install.packages("prophet")
     if (!requireNamespace("bsts",    quietly=TRUE)) install.packages("bsts")

     ---
     Arquivos envolvidos

     - Criar: R/03_projecao.R
     - Ler: dados/especiais.rds, dados/conta_producao.rds
     - Salvar: dados/selecao_modelos.rds, dados/projecoes_brutas.rds, dados/projecoes_derivadas.rds
     - Referência: R/01_leitura_dados.R (padrões de código), plano_projeto.md

     ---
     Verificação pós-execução

     1. selecao_modelos.rds: confirmar que tem 297 linhas (uma por série) e que todos os 9 modelos aparecem
     como vencedor em pelo menos alguma série
     2. projecoes_brutas.rds: confirmar anos 2024–2031 para todas as 297 séries
     3. projecoes_derivadas.rds: confirmar identidade PIB = VAB + impostos nos anos projetados (verificação
     análoga ao 02_consistencia.R)
     4. Inspecionar visualmente as projeções de PIB para Brasil e Roraima (séries mais e menos estáveis)

● Agora implemento o script.
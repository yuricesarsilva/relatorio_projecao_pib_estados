# Plano: VAB por atividade econômica — projeção direta

**Revisão:** abordagem baseada nos dados brutos de `conta_da_producao_2002_2023`,
modelando cada atividade com seus próprios índices de volume e preço.

---

## Abordagem metodológica

**Fonte de dados**: `dados/conta_producao.rds`, já construído em `01_leitura_dados.R`
a partir de `base_bruta/Conta_da_Producao_2002_2023_xls/`. Contém, por
atividade × geo × ano:

| Coluna | Conteúdo |
|--------|----------|
| `val_corrente` | VAB nominal (preço corrente, R$ milhões) |
| `idx_volume` | Índice de volume yoy (= 1 + tx. cresc. real) |
| `idx_preco` | Índice de preço yoy (≈ 1 + inflação setorial) |

**O que muda em relação ao plano anterior:**
- ~~Distribuir o VAB macro projetado por participações fixas 2019–2023~~
- **Novo**: modelar `idx_volume` e `idx_preco` de **cada atividade individualmente**,
  da mesma forma que hoje os macrossetores são modelados no `03_projecao.R`.
- Resultado: séries projetadas com IC 95% para cada atividade, sem assumir
  participações fixas dentro do macrossetor.

**Número de séries adicionais**: 12 atividades × 33 geos × 2 variáveis = **792 séries**.
Somadas às 297 atuais (macrossetores), o CV total passa a ~1.089 séries.
Avaliar cache e tempo de execução antes de rodar.

---

## Atividades a modelar (12 — excluindo "total")

| Código interno | Nome IBGE | Macrossetor |
|----------------|-----------|-------------|
| `agropecuaria` | Agropecuária | agropecuaria |
| `ind_extrativa` | Indústrias extrativas | industria |
| `ind_transformacao` | Indústrias de transformação | industria |
| `eletricidade_gas_agua` | Eletricidade, gás, água, esgoto | industria |
| `construcao` | Construção | industria |
| `comercio_veiculos` | Comércio e reparação de veículos | servicos |
| `transporte_armazenagem` | Transporte, armazenagem e correio | servicos |
| `informacao_comunicacao` | Informação e comunicação | servicos |
| `financeiro_seguros` | Atividades financeiras e seguros | servicos |
| `imobiliaria` | Atividades imobiliárias | servicos |
| `adm_publica` | Adm. pública, defesa, saúde e educação | adm_publica |
| `outros_servicos` | Outros serviços | servicos |

> `atividade == "total"` não é modelada (é a soma; já coberta pelo macrossetor).

---

## Mudanças por script

### 1. `R/03_projecao.R` — Parte 1 e Partes 2–6

**Parte 1 — preparação dos dados:**

```r
# Séries de atividade (análogo ao que hoje é feito para macrossetores)
ATIVIDADES <- c("agropecuaria", "ind_extrativa", "ind_transformacao",
                "eletricidade_gas_agua", "construcao", "comercio_veiculos",
                "transporte_armazenagem", "informacao_comunicacao",
                "financeiro_seguros", "imobiliaria", "adm_publica",
                "outros_servicos")

series_ativ <- cp |>
  filter(bloco == "vab", atividade %in% ATIVIDADES) |>
  select(geo, geo_tipo, regiao, atividade, ano, idx_volume, idx_preco) |>
  filter(!is.na(idx_volume), !is.na(idx_preco)) |>
  pivot_longer(c(idx_volume, idx_preco), names_to = "variavel", values_to = "valor") |>
  filter(!is.na(valor)) |>
  mutate(
    macrossetor = NA_character_,   # campo presente mas vazio (atividade direta)
    serie_id = paste(geo, atividade, variavel, sep = "|")
  )

todas_series <- bind_rows(todas_series, series_ativ)
# todas_series agora tem ~1.089 séries (297 macro + 792 atividade)
```

**Parte 7 — Derivações (projeção do VAB nominal por atividade):**

```r
# Base 2023 por atividade
base_2023_ativ <- cp |>
  filter(bloco == "vab", atividade %in% ATIVIDADES, ano == ANO_FIM) |>
  select(geo, atividade, vab_2023 = val_corrente)

# Índices projetados por atividade
proj_vol_ativ <- projecoes_brutas |>
  filter(variavel == "idx_volume", !is.na(macrossetor) | atividade %in% ATIVIDADES) |>
  # filtrar apenas séries de atividade (macrossetor = NA ou atividade explícita)
  ...

# VAB nominal por atividade = val_corrente_2023 × cumprod(idx_vol × idx_prc)
vab_ativ_proj <- proj_vol_ativ |>
  inner_join(proj_prc_ativ, by = c("geo", "atividade", "ano")) |>
  left_join(base_2023_ativ, by = c("geo", "atividade")) |>
  group_by(geo, atividade) |>
  mutate(
    fator_acum  = cumprod(idx_volume * idx_preco),
    vab_nominal = vab_2023 * fator_acum,
    # CI
    flo         = cumprod(coalesce(lo95_vol, idx_volume) * coalesce(lo95_prc, idx_preco)),
    fhi         = cumprod(coalesce(hi95_vol, idx_volume) * coalesce(hi95_prc, idx_preco)),
    vab_lo95    = vab_2023 * flo,
    vab_hi95    = vab_2023 * fhi
  ) |>
  ungroup()

saveRDS(vab_ativ_proj, "dados/vab_atividade_proj.rds")
```

> **Atenção ao `serie_id`**: o campo `macrossetor` em `projecoes_brutas` estará `NA`
> para atividades diretas; o campo `atividade` (a adicionar no tibble de projeções)
> identificará a atividade. Rever a estrutura do tibble `projecoes_brutas` na Parte 6
> para incluir coluna `atividade` além de `macrossetor`.

### 2. `R/04_reconciliacao.R` — reconciliação das atividades

```r
# Carregar projeções brutas por atividade
vab_ativ_proj <- readRDS("dados/vab_atividade_proj.rds")

# O VAB total por atividade deve somar ao VAB total reconciliado por geo × ano.
# Fator = vab_total_reconciliado / sum(vab_atividade_proj) por geo × ano.
vab_total_rec_geo <- projecoes_rec |>
  select(geo, ano, vab_total_rec = vab_nominal_total)

vab_ativ_rec <- vab_ativ_proj |>
  group_by(geo, ano) |>
  mutate(soma_ativ = sum(vab_nominal, na.rm = TRUE)) |>
  ungroup() |>
  left_join(vab_total_rec_geo, by = c("geo", "ano")) |>
  mutate(
    fator_ativ  = vab_total_rec / soma_ativ,
    vab_nominal = vab_nominal * coalesce(fator_ativ, 1),
    vab_lo95    = vab_lo95    * coalesce(fator_ativ, 1),
    vab_hi95    = vab_hi95    * coalesce(fator_ativ, 1)
  ) |>
  select(-soma_ativ, -vab_total_rec, -fator_ativ)

saveRDS(vab_ativ_rec, "dados/vab_atividade_reconciliada.rds")
```

> **Consistência**: `sum(vab_ativ_rec por geo × ano)` deve igualar `vab_nominal_total`
> de `projecoes_reconciliadas.rds`. Adicionar verificação análoga à Parte 7 de
> `04_reconciliacao.R`.

### 3. `R/05_output.R`

**Carregar:**
```r
vab_ativ <- if (file.exists("dados/vab_atividade_reconciliada.rds"))
  readRDS("dados/vab_atividade_reconciliada.rds") else NULL
```

**Nova aba Excel `VAB_atividade`:**
- Estrutura: `atividade | ano | Brasil | Norte | ... | Distrito Federal`
- Inclui histórico 2002–2023 (`cp |> filter(bloco=="vab", atividade %in% ATIVIDADES)`)
  concatenado com projetado 2024–2031.
- Linha separadora histórico/projetado (mesmo padrão das outras abas).

**Aba `Intervalos_Confianca`:** adicionar linhas com `variavel = paste0("vab_", atividade)`.

**Gráficos `output/graficos/todas_geos/`:**
- `vab_{atividade}.png` para cada uma das 12 atividades (33 geos facetados, ribbon IC).
- Total: 12 arquivos novos.

**Gráficos `output/graficos/por_geo/`:**
- Substituir o painel de VAB macro (4 linhas) por stacked area mostrando
  composição do VAB por atividade, histórico + projetado.

---

## Pontos críticos a resolver na implementação

1. **Estrutura do tibble `projecoes_brutas`**: hoje tem coluna `macrossetor` mas não
   `atividade`. Na Parte 6 do `03_projecao.R`, ao iterar sobre as novas séries de
   atividade, o campo `macrossetor` ficará `NA` e um novo campo `atividade` deverá
   ser preenchido. Rever o `meta` extraído por `slice(1)`.

2. **NAs em Acre 2002**: atividades de serviços têm `val_corrente = NA`. O índice
   `idx_volume` e `idx_preco` para 2003 (primeiro ano dos índices) ficará `NA`
   nesses casos. Tratar com `filter(!is.na(idx_volume), !is.na(idx_preco))` antes
   de montar as séries (já feito no código acima).

3. **Séries muito curtas**: algumas atividades em estados menores podem ter séries
   com muitos NAs. O `MIN_TRAIN = 15` filtrará séries com menos de 15 obs válidas.
   Verificar cobertura antes de rodar.

4. **Tempo de execução**: ~792 séries adicionais × 9 modelos × CV = carga
   computacional ~3× maior que o pipeline atual. Garantir que o cache
   (`selecao_modelos.rds`) seja deletado para incluir as novas séries.

5. **Consistência com VAB macro**: o VAB total por atividade deve igualar o VAB
   total por macrossetor (ambos somam ao total). Após reconciliação, verificar
   `sum(vab_ativ) == sum(vab_macro) == vab_nominal_total` por geo × ano.

---

## Arquivos afetados

| Arquivo | Mudança |
|---------|---------|
| `R/03_projecao.R` | Adicionar séries de atividade à `todas_series`; Parte 7 deriva VAB por atividade |
| `R/04_reconciliacao.R` | Reconciliar VAB por atividade pelo total reconciliado |
| `R/05_output.R` | Nova aba `VAB_atividade`; 12 gráficos `todas_geos`; atualizar `por_geo` |
| `dados/selecao_modelos.rds` | **Deletar** antes de re-executar (cache deve incluir novas séries) |
| `dados/vab_atividade_proj.rds` | Novo intermediário |
| `dados/vab_atividade_reconciliada.rds` | Novo output reconciliado |
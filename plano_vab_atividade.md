# Plano: VAB por atividade econômica nos outputs

## Contexto

O pipeline atual projeta por **macrossetor** (4 grupos). O VAB por **atividade**
(13 categorias IBGE) é obtido distribuindo proporcionalmente o VAB do macrossetor
usando participações históricas médias — conforme já descrito em `plano_03_projecao.md`.

Dados disponíveis: `dados/conta_producao.rds` tem VAB nominal (`val_corrente`)
por atividade × geo × ano para 2002–2023.

---

## Mudanças necessárias (por script)

### 1. `R/03_projecao.R` — Parte 7 (Derivações)

Adicionar após o bloco existente de derivações:

```r
# --- Participações médias de atividade dentro de cada macrossetor (2019–2023)
ANOS_REF <- 2019:2023

participacoes <- cp |>          # conta_producao.rds, já carregado no Parte 1
  filter(bloco == "vab", atividade != "total",
         ano %in% ANOS_REF) |>
  inner_join(ativ_macro, by = "atividade") |>
  group_by(geo, macrossetor, atividade, ano) |>
  summarise(vab = sum(val_corrente, na.rm = TRUE), .groups = "drop") |>
  group_by(geo, macrossetor, ano) |>
  mutate(part = vab / sum(vab, na.rm = TRUE)) |>
  group_by(geo, macrossetor, atividade) |>
  summarise(part_media = mean(part, na.rm = TRUE), .groups = "drop")

# --- Aplicar participações ao VAB projetado por macrossetor
vab_atividade_proj <- vab_proj |>            # resultado já calculado na Parte 7
  select(geo, macrossetor, ano, vab_nominal) |>
  left_join(participacoes, by = c("geo", "macrossetor"),
            relationship = "many-to-many") |>
  mutate(vab_atividade = vab_nominal * part_media)

# --- CI por atividade (mesma proporção sobre o CI do macrossetor)
vab_atividade_ci <- vab_proj |>
  # vab_proj tem vab_lo95 e vab_hi95 se adicionarmos na Parte 6 (ver abaixo)
  select(geo, macrossetor, ano, vab_lo95, vab_hi95) |>
  left_join(participacoes, by = c("geo", "macrossetor"),
            relationship = "many-to-many") |>
  mutate(
    ativ_lo95 = vab_lo95 * part_media,
    ativ_hi95 = vab_hi95 * part_media
  )

vab_atividade_proj <- vab_atividade_proj |>
  left_join(vab_atividade_ci |> select(geo, macrossetor, atividade, ano,
                                        ativ_lo95, ativ_hi95),
            by = c("geo", "macrossetor", "atividade", "ano"))

saveRDS(vab_atividade_proj, "dados/vab_atividade_proj.rds")
```

**Dependência**: `vab_proj` precisará ter `vab_lo95` e `vab_hi95` — adicionar ao
`vab_proj` na Parte 7 atual (propagação dos CI dos índices, idêntica ao que já
fazemos em `05_output.R` mas guardando no RDS).

### 2. `R/04_reconciliacao.R` — adicionar reconciliação das atividades

Após a reconciliação do VAB macro, adicionar bloco análogo para atividades:

```r
# Reconciliar VAB por atividade (escalonar pelo mesmo fator do macrossetor)
vab_atividade_proj <- readRDS("dados/vab_atividade_proj.rds")

fator_mac_por_geo <- vab_macro_rec |>     # vab_macro_rec ainda em memória
  mutate(fator_mac = vab_nominal / (vab_2023 * fator_acum)) |>
  select(geo, macrossetor, ano, fator_mac)

vab_ativ_rec <- vab_atividade_proj |>
  left_join(fator_mac_por_geo, by = c("geo", "macrossetor", "ano")) |>
  mutate(
    vab_atividade = vab_atividade * coalesce(fator_mac, 1),
    ativ_lo95     = ativ_lo95     * coalesce(fator_mac, 1),
    ativ_hi95     = ativ_hi95     * coalesce(fator_mac, 1)
  ) |>
  select(-fator_mac)

saveRDS(vab_ativ_rec, "dados/vab_atividade_reconciliada.rds")
```

### 3. `R/05_output.R` — adicionar aba Excel + gráficos

**Carregar no Parte 1:**
```r
vab_ativ <- if (file.exists("dados/vab_atividade_reconciliada.rds"))
  readRDS("dados/vab_atividade_reconciliada.rds") else NULL
```

**Nova aba Excel `VAB_atividade`** (wide: atividade × ano × geo):
```r
# Estrutura: macrossetor | atividade | ano | Brasil | Norte | ... | Distrito Federal
```

**Adicionar à aba `Intervalos_Confianca`:** linhas com `variavel = paste0("vab_", atividade)`.

**Novos gráficos em `output/graficos/todas_geos/`:**
- `vab_{atividade}.png` — 13 arquivos (1 por atividade, todos os 33 geos facetados)

**Novos gráficos em `output/graficos/por_geo/`:**
- Adicionar ao plot existente um painel de decomposição do VAB por atividade
  (stacked bar ou linhas com 13 séries)

---

## Mapeamento atividade → macrossetor (referência)

| Atividade (código) | Nome | Macrossetor |
|--------------------|------|-------------|
| agropecuaria | Agropecuária | agropecuaria |
| ind_extrativa | Ind. extrativas | industria |
| ind_transformacao | Ind. de transformação | industria |
| eletricidade_gas_agua | Eletricidade/gás/água | industria |
| construcao | Construção | industria |
| adm_publica | Adm. pública | adm_publica |
| comercio_veiculos | Comércio/veículos | servicos |
| transporte_armazenagem | Transporte/armazenagem | servicos |
| informacao_comunicacao | Informação/comunicação | servicos |
| financeiro_seguros | Financeiro/seguros | servicos |
| imobiliaria | Atividades imobiliárias | servicos |
| outros_servicos | Outros serviços | servicos |

> Nota: `atividade = "total"` é ignorado (é a soma, não individual).

---

## Arquivos afetados

| Arquivo | Tipo de mudança |
|---------|----------------|
| `R/03_projecao.R` | Adicionar bloco de derivação de atividades + CI |
| `R/04_reconciliacao.R` | Adicionar reconciliação das atividades |
| `R/05_output.R` | Nova aba Excel + 13 gráficos `todas_geos` + atualização `por_geo` |
| `dados/vab_atividade_proj.rds` | Novo arquivo intermediário |
| `dados/vab_atividade_reconciliada.rds` | Novo arquivo de saída reconciliada |

---

## Observações importantes

- As participações são **fixas** (média 2019–2023): a tendência de longo prazo de
  cada atividade dentro do macrossetor não é modelada individualmente. Isso é uma
  limitação explícita do modelo.
- Para Acre 2002, há NAs conhecidos em algumas atividades de serviços (ver Etapa 1).
  Ao calcular `part_media`, filtrar anos com NAs ou usar `na.rm = TRUE`.
- O CI por atividade é uma **aproximação**: assume que a participação de cada atividade
  dentro do macrossetor é constante e igual ao ponto central. A incerteza real por
  atividade é maior.
- Considerar limitar os gráficos `por_geo` de atividades a uma visualização
  agregada (ex.: stacked area do VAB nominal, mostrando a composição) para não
  criar painéis excessivamente pequenos.

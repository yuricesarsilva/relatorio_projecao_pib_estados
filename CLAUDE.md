# Instruções para Claude — Projeto Projeções PIBs Estaduais

## Regra obrigatória após qualquer alteração no projeto

**A cada nova alteração realizada neste projeto, você deve:**

1. **Atualizar `progresso.md`** — registre o que foi feito, sob qual etapa pertence,
   quais arquivos foram criados ou modificados, e os outputs gerados (com nº de linhas
   quando aplicável). Siga o padrão de formatação já estabelecido no arquivo.

2. **Fazer commit** com mensagem descritiva em português, no formato:
   ```
   <verbo no imperativo>: <descrição do que foi feito>
   ```
   Exemplos: `Adiciona aba Selecao_Modelos ao output Excel`,
   `Corrige cálculo do deflator projetado`.

3. **Fazer push** para o repositório remoto:
   `https://github.com/yuricesarsilva/painel_projecao_pib_estados.git`

   Comando: `git push origin main`

Isso garante que o repositório GitHub reflita sempre o estado atual do projeto.

---

## Contexto do projeto

- **Objetivo:** projetar PIB nominal, VAB, impostos, deflatores e crescimento real
  para 27 UFs + 5 regiões + Brasil (2024–2031), com restrições de agregação contábil.
- **Pipeline:** `run_all.R` → executa em sequência `R/01` a `R/05`.
- **Horizonte histórico:** 2002–2023 (IBGE Contas Regionais).
- **Dados brutos em `base_bruta/`** — excluídos do git via `.gitignore`.
- **Dados processados em `dados/`** — excluídos do git.
- **Outputs em `output/`** — excluídos do git.
- Scripts em `R/` e arquivos `.md` são versionados.

---

## Estrutura dos scripts

| Script | Função |
|--------|--------|
| `R/01_leitura_dados.R` | Lê todos os dados brutos → `dados/*.rds` |
| `R/02_consistencia.R` | Verifica identidades contábeis nos dados históricos |
| `R/03_projecao.R` | Modela séries (9 modelos, CV expanding window) e projeta 2024–2031 |
| `R/04_reconciliacao.R` | Impõe restrições de agregação (benchmarking top-down) |
| `R/05_output.R` | Gera Excel (tabelas) e gráficos PNG |

---

## Padrão de commit

Sempre ao final de uma sessão de alterações, ou após completar uma etapa:

```bash
git add R/ progresso.md CLAUDE.md   # nunca adicione base_bruta/, dados/, output/
git commit -m "mensagem descritiva"
git push origin main
```

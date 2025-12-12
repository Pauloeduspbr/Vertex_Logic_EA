# FGM Trend Rider - Versão Platina

**Expert Advisor Profissional para B3 (WIN/WDO) e Forex**

Este projeto contém o código-fonte do **FGM Trend Rider**, um robô de investimento sofisticado desenvolvido para operar tendências com múltiplos filtros de confirmação e gestão de risco avançada.

## 🚀 Status do Projeto
**Versão Atual:** 1.00 (Platinum Final)
**Estado:** 🟡 Pronto para Refinamento e Testes em Conta Real (Monitorada)

O EA passou por correções críticas de lógica e arquitetura e agora compila sem erros. A lógica de horários foi ajustada para permitir operações na virada do dia (00:00+), essencial para o mercado Forex.

## 📋 Funcionalidades Principais

### 1. Estratégia de Entrada
*   **Trend Following:** Baseado em cruzamento de médias móveis (EMAs) e força de tendência.
*   **Indicador FGM:** Algoritmo proprietário que mede a força da tendência (1 a 5) e confluência.
*   **Filtros de Confirmação:**
    *   **Slope:** Inclinação das médias.
    *   **Volume:** Análise de volume (essencial para B3).
    *   **RSIOMA:** Filtro de momentum (RSI of Moving Average).
    *   **Spread:** Proteção contra spreads altos.
    *   **Regime de Mercado:** Detecta se o mercado está em Tendência, Lateral ou Volátil e ajusta os parâmetros automaticamente.

### 2. Gestão de Risco (Risk Manager)
*   **Stop Loss Híbrido:** Fixo ou baseado em ATR (Volatilidade).
*   **Take Profit Dinâmico:** Baseado em Risco/Retorno ou ATR.
*   **Proteção Diária:** Limites de perda diária (Drawdown) e meta de lucro.
*   **Proteção de Sequência:** Pausa após `N` perdas consecutivas (Cooldown).

### 3. Gestão de Posição
*   **Break Even:** Move o Stop Loss para o preço de entrada após atingir certo lucro.
*   **Trailing Stop:** Segue o preço para proteger lucros em tendências longas.
*   **Saídas Parciais:** (Configurável na lógica interna).

### 4. Filtro de Horário (Time Filter)
*   **Sessões Forex:** Suporte a sessões (Sydney, Tokyo, London, New York).
*   **Horário B3:** Configuração específica para pregão brasileiro.
*   **Hard/Soft Exit:** Fechamento forçado de posições no fim do dia/sessão.
*   **Correção Recente:** Lógica ajustada para permitir trading contínuo através da meia-noite (00:00).

## 🛠️ Estrutura do Projeto

```
Vertex_Logic_EA/
├── Experts/
│   └── FGM_TrendRider_EA/
│       └── FGM_TrendRider.mq5       # Arquivo Principal do EA
├── Include/
│   └── FGM_TrendRider_EA/
│       ├── CAssetSpecs.mqh          # Especificações do Ativo
│       ├── CBreakEvenManager.mqh    # Gestão de Break Even
│       ├── CFilters.mqh             # Filtros de Entrada
│       ├── CRegimeDetector.mqh      # Detecção de Regime de Mercado
│       ├── CRiskManager.mqh         # Gestão de Risco e Lote
│       ├── CSignalFGM.mqh           # Lógica de Sinal (Indicador)
│       ├── CStats.mqh               # Estatísticas e Logging
│       ├── CTimeFilter.mqh          # Filtro de Horário (Corrigido)
│       ├── CTradeEngine.mqh         # Execução de Ordens
│       └── CTrailingStopManager.mqh # Gestão de Trailing Stop
└── Indicators/
    └── FGM_TrendRider_EA/
        ├── FGM_Indicator.mq5        # Indicador Visual
        └── RSIOMA_v2HHLSX_MT5.mq5   # Indicador Auxiliar
```

## 📝 Notas de Atualização (Últimas Correções)

1.  **Correção de Compilação:** Adicionados "Include Guards" (`#ifndef`...) em todos os arquivos `.mqh` para resolver conflitos de redefinição de classes.
2.  **Correção de Horário (00:30):**
    *   Ajuste na classe `CTimeFilter` para priorizar o horário do servidor (`Inp_StartTime` / `Inp_EndTime`) sobre a lógica restritiva de sessões.
    *   Desativação padrão do filtro de "Rollover" para evitar bloqueios desnecessários na virada do dia.
3.  **Debug:** Adicionados logs detalhados (`[DEBUG]`) para rastrear motivos de entrada/saída e rejeição de sinais.

## ⚠️ Aviso Legal

Este software é uma ferramenta de automação de trading. **Resultados passados não garantem resultados futuros.**
*   Recomenda-se testar extensivamente em conta DEMO antes de utilizar em conta REAL.
*   Monitore o EA constantemente durante a fase de refinamento.

---
**Copyright © 2025 FGM Trading Systems**
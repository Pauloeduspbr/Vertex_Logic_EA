//+------------------------------------------------------------------+
//| OBV MACD INTEGRATION - NEXUS LOGIC SEQUENTIAL SYNCHRONIZATION    |
//| Integração profissional do indicador OBV MACD ao EA FGM           |
//+------------------------------------------------------------------+

ARQUIVO CRIADO: COBVMACD.mqh
MODIFICADO: CFilters.mqh 
MODIFICADO: FGM_TrendRider.mq5

═══════════════════════════════════════════════════════════════════════

1. NOVO INDICADOR: OBV_MACD_v3.mq5 (Subjanela 2)
   ├─ Arquivo: Indicators/FGM_TrendRider_EA/OBV_MACD_v3.mq5
   ├─ Localização: Subjanela separada (não sobrepõe outros indicadores)
   ├─ Buffers:
   │  ├─ [0] Histograma (Plot: cores alternadas)
   │  ├─ [1] Índice de Cor (0,1,2,3: POS_STRONG, NEG_STRONG, POS_WEAK, NEG_WEAK)
   │  ├─ [2] Linha MACD (Plot: Laranja)
   │  ├─ [3] Linha de Sinal (Plot: Azul)
   │  └─ [4] Threshold (Buffer de leitura para EA - Filtro de ruído)
   └─ Parâmetros: FastEMA=12, SlowEMA=26, SignalSMA=9, ObvSmooth=5

2. NOVA CLASSE: COBVMACD
   └─ Arquivo: Include/FGM_TrendRider_EA/COBVMACD.mqh
   └─ Funções principais:
      ├─ Init()              - Inicializa handle do indicador
      ├─ Update()            - Carrega dados da barra (shift=1 para barra fechada)
      ├─ GetSignal()         - Retorna sinal (SIGNAL_BUY, SELL, HOLD_B, HOLD_S, NONE)
      ├─ IsNoiseFiltered()   - Verifica se |Histogram| > Threshold
      ├─ IsVolumeRelevant()  - Verifica volume relevante (>1.5x Threshold)
      ├─ IsSideways()        - Detecta lateralização (Death Zone)
      ├─ IsSignalStrong()    - Verifica se sinal é forte (não fraco)
      └─ GetSignalStrength() - Retorna força do sinal (0-5)

3. LÓGICA NEXUS (Nexus Confluence EA)
   
   A. FILTRO DE RUÍDO (Regra de Ouro):
      ├─ Se |Histogram| < Threshold ⟹ Mercado LATERAL (bloqueado)
      ├─ Se |Histogram| > Threshold ⟹ Volume RELEVANTE (permitido)
      └─ Threshold = EMA(|Histogram|) × 0.6

   B. SINAIS (Baseado na Cor):
      ├─ COLOR_POS_STRONG (0):  SINAL_BUY    - Compra máxima (verde forte)
      ├─ COLOR_NEG_STRONG (1):  SINAL_SELL   - Venda máxima (vermelho forte)
      ├─ COLOR_POS_WEAK   (2):  SINAL_HOLD_B - Compra enfraquecendo (verde fraco)
      └─ COLOR_NEG_WEAK   (3):  SINAL_HOLD_S - Venda enfraquecendo (vermelho fraco)

   C. DETECÇÃO DE LATERALIZAÇÃO (Death Zone):
      └─ Se Histogram BAIXO E MACD ≈ Signal ⟹ Mercado em compressão (bloqueado)

4. SINCRONISMO SEQUENCIAL (ORDEM DE EXECUÇÃO)

   Fluxo de validação de entrada:
   
   ┌─────────────────────────────────────────────────────┐
   │ 1. SPREAD (Spread < limite?)                        │
   ├─────────────────────────────────────────────────────┤
   │ 2. FORCE/STRENGTH (Força ≥ mínima?)                 │
   ├─────────────────────────────────────────────────────┤
   │ 3. PHASE (Fase de mercado adequada?)                │
   ├─────────────────────────────────────────────────────┤
   │ 4. EMA200 (Preço vs EMA200 alinhado?)               │
   ├─────────────────────────────────────────────────────┤
   │ 5. CONFLUENCE (EMAs não muito comprimidas?)         │
   ├─────────────────────────────────────────────────────┤
   │ 6. SLOPE (Inclinação adequada?)                     │
   ├─────────────────────────────────────────────────────┤
   │ 7. VOLUME (Volume adequado?)                        │
   ├─────────────────────────────────────────────────────┤
   │ 8. COOLDOWN (Respeitado após stop?)                 │
   ├─────────────────────────────────────────────────────┤
   │ 9. RSI/OMA (RSI não overbought/oversold?)           │ ← Sincronismo
   ├─────────────────────────────────────────────────────┤
   │ 10. OBV MACD (Sinal correto + sem ruído?) ✓ NOVO   │ ← Sincronismo
   └─────────────────────────────────────────────────────┘

5. SINCRONISMO SEQUENTIAL (OBV MACD ↔ RSI)
   
   A ordem é CRÍTICA para evitar sinais falsos:
   
   Ordem Sequencial (tal como implementado):
   ┌──────────────────────────────────────────────────────────┐
   │ Filtro 1-8: Validações de Preço/Volume/Técnicas         │
   ├──────────────────────────────────────────────────────────┤
   │ Filtro 9: RSI/OMA (Validação de Momentum)                │
   │           └─ Se RSI falhar, STOP aqui (não prossegue)   │
   ├──────────────────────────────────────────────────────────┤
   │ Filtro 10: OBV MACD (Validação de Volume/Energia)        │
   │            └─ Se OBV MACD falhar, STOP aqui (não abre)  │
   └──────────────────────────────────────────────────────────┘

   Exemplo:
   • Filtros 1-8 ✓ PASS
   • RSI em overbought ✗ FAIL   ⟹ Não checa OBV MACD, ORDEM BLOQUEADA
   
   • Filtros 1-8 ✓ PASS
   • RSI OK ✓ PASS
   • OBV MACD em lateralização ✗ FAIL ⟹ ORDEM BLOQUEADA

6. SINCRONISMO DIREÇÃO (BUY ↔ SELL)
   
   Compra (isBuy = true):
   ├─ RSI: Não overbought (<70) E momentum para cima
   ├─ OBV MACD: SIGNAL_BUY (verde forte) OU SIGNAL_HOLD_B (verde fraco se permitido)
   └─ Resultado: Entrada de compra sincronizada com volume compradora

   Venda (isBuy = false):
   ├─ RSI: Não oversold (>30) E momentum para baixo
   ├─ OBV MACD: SIGNAL_SELL (vermelho forte) OU SIGNAL_HOLD_S (vermelho fraco se permitido)
   └─ Resultado: Entrada de venda sincronizada com volume vendedora

7. PARÂMETROS DE ENTRADA NO EA

   Grupo: "═══════════════ FILTRO OBV MACD (NEXUS) ═══════════════"
   
   ├─ Inp_UseOBVMACD (true)
   │  └─ Ativar/desativar filtro OBV MACD
   │
   ├─ Inp_OBVMACD_RequireBuy (false)
   │  └─ false: Permite SIGNAL_HOLD_B (verde fraco) para compra
   │  └─ true:  Exige SIGNAL_BUY (verde forte) para compra
   │
   ├─ Inp_OBVMACD_RequireSell (false)
   │  └─ false: Permite SIGNAL_HOLD_S (vermelho fraco) para venda
   │  └─ true:  Exige SIGNAL_SELL (vermelho forte) para venda
   │
   ├─ Inp_OBVMACD_AllowWeak (true)
   │  └─ true: Permite sinais fracos (HOLD_B/HOLD_S)
   │  └─ false: Bloqueia sinais fracos, exigindo força máxima
   │
   └─ Inp_OBVMACD_CheckVolume (false)
   │  └─ false: Apenas filtra ruído (Histogram > Threshold)
   │  └─ true:  Exige volume RELEVANTE (Histogram > 1.5×Threshold)

8. CONFIGURAÇÃO RECOMENDADA

   Para máxima segurança (menos sinais, melhor qualidade):
   ├─ Inp_UseOBVMACD           = true
   ├─ Inp_OBVMACD_RequireBuy   = false   (permite verde fraco)
   ├─ Inp_OBVMACD_RequireSell  = false   (permite vermelho fraco)
   ├─ Inp_OBVMACD_AllowWeak    = true    (aceita fracos se passar outros testes)
   └─ Inp_OBVMACD_CheckVolume  = false   (filtro de ruído suficiente)

   Para agressividade (mais sinais, maior risco):
   ├─ Inp_UseOBVMACD           = true
   ├─ Inp_OBVMACD_RequireBuy   = false
   ├─ Inp_OBVMACD_RequireSell  = false
   ├─ Inp_OBVMACD_AllowWeak    = true
   └─ Inp_OBVMACD_CheckVolume  = false

9. MENSAGENS DE LOG DO EA

   Ao abrir um BUY:
   [OK] OBV MACD: COMPRA FORTE (Green Strong) - APROVADO para BUY
   ou
   [OK] OBV MACD: COMPRA ENFRAQUECENDO (Green Weak) - ACEITO para BUY (fraco)
   
   [BLOQUEADO] OBV MACD: Mercado em lateralização (Death Zone) - BLOQUEADO
   ou
   [BLOQUEADO] OBV MACD: Sem sinal de compra - BLOQUEADO para BUY

10. INDICADOR NA PLATAFORMA

    Ao adicionar o EA, você verá:
    ├─ Subjanela 1: FGM Indicator (EMAs)
    ├─ Subjanela 2: OBV_MACD_v3 ✓ NOVO (OBV MACD + Threshold)
    │              ├─ Histogram (barras coloridas)
    │              │  ├─ Verde Forte: Compra máxima
    │              │  ├─ Verde Fraco: Compra enfraquecendo
    │              │  ├─ Vermelho Forte: Venda máxima
    │              │  └─ Vermelho Fraco: Venda enfraquecendo
    │              ├─ Linha Laranja: MACD (12EMA - 26EMA do OBV)
    │              ├─ Linha Azul: Signal (SMA-9 do MACD)
    │              ├─ Linha Cinza (imaginária): Threshold (filtro de ruído)
    │              └─ Nível Zero: Linha de referência
    ├─ Subjanela 3: RSIOMA (se ativado)
    └─ Subjanela 4: Outros (se houver)

11. INTERPRETAÇÃO VISUAL

    Verde Forte + Laranja acima de Zero ⟹ COMPRA MÁXIMA
    Verde Fraco + Laranja próx a Zero ⟹ Compra enfraquecendo
    
    Vermelho Forte + Laranja abaixo de Zero ⟹ VENDA MÁXIMA
    Vermelho Fraco + Laranja próx a Zero ⟹ Venda enfraquecendo
    
    Histogram < Linha Cinza (Threshold) ⟹ Mercado em compressão/lateral

12. DIVERGÊNCIAS (Sniper Strategy)

    O OBV MACD é excelente para detectar divergências:
    
    Divergência de ALTA:
    ├─ Preço: Tocando novos mínimos (baixando)
    ├─ OBV MACD: Subindo acima de zero
    └─ Interpretação: Smart Money comprando em pânico do varejo
    
    Divergência de BAIXA:
    ├─ Preço: Tocando novos máximos (subindo)
    ├─ OBV MACD: Caindo abaixo de zero
    └─ Interpretação: Preço sobe por inércia, mas volume comprador secou

13. ESTRUTURA DE ARQUIVOS AFETADOS

    Include/FGM_TrendRider_EA/
    ├─ COBVMACD.mqh ✓ NOVO (classe de integração)
    ├─ CFilters.mqh ✓ MODIFICADO (CheckOBVMACD adicionado)
    └─ (outros arquivos intactos)

    Experts/FGM_TrendRider_EA/
    └─ FGM_TrendRider.mq5 ✓ MODIFICADO (inputs + configuração)

    Indicators/FGM_TrendRider_EA/
    └─ OBV_MACD_v3.mq5 ✓ EXISTENTE (usado pela COBVMACD)

14. COMPILAÇÃO E TESTE

    1. Compilar o EA: FGM_TrendRider.mq5
       └─ Deve compilar sem erros
    
    2. Verificar indicadores:
       ├─ OBV_MACD_v3.mq5 deve estar compilado
       ├─ FGM_Indicator.mq5 deve estar compilado
       └─ RSIOMA_v2HHLSX_MT5.mq5 deve estar compilado (se usar RSIOMA)
    
    3. Testar no Strategy Tester:
       ├─ Adicionar EA ao gráfico
       ├─ Verificar se OBV MACD aparece em subjanela separada
       ├─ Observar sincronismo entre sinais
       └─ Validar ordens abertas coincidindo com sinais forte

15. TROUBLESHOOTING

    Problema: "OBV_MACD_v3 não encontrado"
    Solução: Verificar se arquivo está em Indicators/FGM_TrendRider_EA/
    
    Problema: "Handle INVALID_HANDLE"
    Solução: Verificar parâmetros do indicador (EMA/SMA periods)
    
    Problema: Muitas ordens bloqueadas por OBV MACD
    Solução: Aumentar Inp_OBVMACD_AllowWeak para true (mais permissivo)
    
    Problema: Nenhum sinal OBV MACD
    Solução: Verificar se mercado está em lateralização (Histogram < Threshold)

═══════════════════════════════════════════════════════════════════════
Desenvolvido por: Paulo Educação SP Broker (PesB) - Nexus Trading Logic
Versão: 1.00
Data: Dezembro 2025
═══════════════════════════════════════════════════════════════════════

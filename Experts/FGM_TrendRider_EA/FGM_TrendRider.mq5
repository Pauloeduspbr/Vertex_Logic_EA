//+------------------------------------------------------------------+
//|                                              FGM_TrendRider.mq5 |
//|                         FGM Trend Rider - Versão Platina         |
//|                           Expert Advisor Principal               |
//+------------------------------------------------------------------+
#property copyright "FGM Trading Systems"
#property link      "https://www.fgmtrade.com"
#property version   "1.00"
#property description "FGM Trend Rider - Versão Platina Consolidada"
#property description "Expert Advisor para B3 (WIN/WDO) e Forex"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include "..\..\Include\FGM_TrendRider_EA\CAssetSpecs.mqh"
#include "..\..\Include\FGM_TrendRider_EA\CSignalFGM.mqh"
#include "..\..\Include\FGM_TrendRider_EA\CRiskManager.mqh"
#include "..\..\Include\FGM_TrendRider_EA\CTradeEngine.mqh"
#include "..\..\Include\FGM_TrendRider_EA\CTimeFilter.mqh"
#include "..\..\Include\FGM_TrendRider_EA\CRegimeDetector.mqh"
#include "..\..\Include\FGM_TrendRider_EA\CFilters.mqh"
#include "..\..\Include\FGM_TrendRider_EA\CStats.mqh"

//+------------------------------------------------------------------+
//| Enumerações de Input                                             |
//+------------------------------------------------------------------+
enum ENUM_EA_MODE
{
   MODE_AGGRESSIVE = 0,   // Agressivo - Mais entradas
   MODE_MODERATE   = 1,   // Moderado - Equilibrado
   MODE_CONSERVATIVE = 2  // Conservador - Menos entradas
};

enum ENUM_SL_MODE
{
   SL_FIXED = 0,          // Fixo em pontos
   SL_ATR   = 1,          // Baseado em ATR
   SL_HYBRID = 2          // Híbrido (maior entre fixo e ATR)
};

enum ENUM_TP_MODE
{
   TP_FIXED = 0,          // Fixo em pontos
   TP_RR_RATIO = 1,       // Razão Risco/Retorno
   TP_ATR = 2             // Baseado em ATR
};

//+------------------------------------------------------------------+
//| Input Parameters - BLOCO 4: Parâmetros Chave                     |
//+------------------------------------------------------------------+
//--- Identificação
input group "═══════════════ IDENTIFICAÇÃO ═══════════════"
input ulong    Inp_MagicNumber     = 240001;           // Magic Number Base
input string   Inp_EAComment       = "FGM_Platina";    // Comentário das Ordens

//--- Modo de Operação
input group "═══════════════ MODO DE OPERAÇÃO ═══════════════"
input ENUM_EA_MODE Inp_EAMode      = MODE_MODERATE;    // Modo do EA
input bool     Inp_AllowBuy        = true;             // Permitir Compras
input bool     Inp_AllowSell       = true;             // Permitir Vendas
input bool     Inp_TradeOnNewBar   = true;             // Operar apenas em nova barra
input int      Inp_MaxSpread       = 30;               // Spread máximo (pontos)

//--- Gestão de Risco
input group "═══════════════ GESTÃO DE RISCO ═══════════════"
input double   Inp_RiskPercent     = 1.0;              // Risco Base (%)
input double   Inp_MaxDailyDD      = 3.0;              // Drawdown Diário Máximo (%)
input double   Inp_MaxTotalDD      = 10.0;             // Drawdown Total Máximo (%)
input int      Inp_MaxConsecLoss   = 3;                // Máx perdas consecutivas
input double   Inp_ForceMultF3     = 0.5;              // Multiplicador F3
input double   Inp_ForceMultF4     = 1.0;              // Multiplicador F4
input double   Inp_ForceMultF5     = 1.5;              // Multiplicador F5

//--- Stop Loss
input group "═══════════════ STOP LOSS ═══════════════"
input ENUM_SL_MODE Inp_SLMode      = SL_HYBRID;        // Modo do Stop Loss
input int      Inp_SL_Points       = 150;              // SL Fixo (pontos)
input double   Inp_SL_ATR_Mult     = 1.5;              // Multiplicador ATR para SL
input int      Inp_SL_Min          = 50;               // SL Mínimo (pontos)
input int      Inp_SL_Max          = 500;              // SL Máximo (pontos)

//--- Take Profit
input group "═══════════════ TAKE PROFIT ═══════════════"
input ENUM_TP_MODE Inp_TPMode      = TP_RR_RATIO;      // Modo do Take Profit
input int      Inp_TP_Points       = 300;              // TP Fixo (pontos)
input double   Inp_TP_RR_Ratio     = 2.0;              // Razão Risco/Retorno
input double   Inp_TP_ATR_Mult     = 3.0;              // Multiplicador ATR para TP

//--- Sistema Triple Exit
input group "═══════════════ TRIPLE EXIT ═══════════════"
input bool     Inp_UseTripleExit   = true;             // Usar Triple Exit
input double   Inp_TP1_Percent     = 50.0;             // TP1: Percentual do volume (%)
input double   Inp_TP1_RR          = 1.0;              // TP1: Razão R:R
input double   Inp_TP2_Percent     = 30.0;             // TP2: Percentual do volume (%)
input double   Inp_TP2_RR          = 2.0;              // TP2: Razão R:R
input double   Inp_TP3_Percent     = 20.0;             // TP3: Percentual do volume (%)

//--- Break-Even
input group "═══════════════ BREAK-EVEN ═══════════════"
input bool     Inp_UseBE           = true;             // Usar Break-Even
input int      Inp_BE_Trigger      = 100;              // Trigger BE (pontos de lucro)
input int      Inp_BE_Offset       = 10;               // Offset após BE (pontos)

//--- Trailing Stop
input group "═══════════════ TRAILING STOP ═══════════════"
input bool     Inp_UseTrailing     = true;             // Usar Trailing Stop
input int      Inp_Trail_Trigger   = 150;              // Trigger Trailing (pontos)
input int      Inp_Trail_Step      = 50;               // Step do Trailing (pontos)
input int      Inp_Trail_Distance  = 100;              // Distância do Trailing (pontos)

//--- Horários de Operação
input group "═══════════════ HORÁRIOS ═══════════════"
input bool     Inp_UseTimeFilter   = true;             // Usar Filtro de Horário
input bool     Inp_CloseEOD        = true;             // Fechar posições fim do dia
input int      Inp_BrokerOffset    = 0;                // Offset do broker (horas)

//--- Parâmetros do Indicador FGM
input group "═══════════════ INDICADOR FGM ═══════════════"
input int      Inp_FGM_Period1     = 8;                // Período EMA 1
input int      Inp_FGM_Period2     = 21;               // Período EMA 2
input int      Inp_FGM_Period3     = 50;               // Período EMA 3
input int      Inp_FGM_Period4     = 100;              // Período EMA 4
input int      Inp_FGM_Period5     = 200;              // Período EMA 5
input int      Inp_MinStrength     = 3;                // Força Mínima (3-5)
input double   Inp_MaxConf_F3      = 60.0;             // Máx Confluência para F3 (%)
input double   Inp_MaxConf_F4      = 100.0;            // Máx Confluência para F4 (%)
input double   Inp_MaxConf_F5      = 100.0;            // Máx Confluência para F5 (%)

//--- Filtros Adicionais
input group "═══════════════ FILTROS ═══════════════"
input bool     Inp_UseSlopeFilter  = true;             // Usar Filtro de Slope
input bool     Inp_UseVolumeFilter = true;             // Usar Filtro de Volume (B3)
input bool     Inp_UseATRFilter    = true;             // Usar Filtro ATR
input int      Inp_CooldownBars    = 3;                // Cooldown após trade (barras)

//--- Regime de Mercado
input group "═══════════════ REGIME DE MERCADO ═══════════════"
input bool     Inp_UseRegime       = true;             // Usar Detecção de Regime
input double   Inp_TrendMult       = 1.0;              // Multiplicador Trending
input double   Inp_RangeMult       = 0.5;              // Multiplicador Ranging
input double   Inp_VolatileMult    = 0.3;              // Multiplicador Volatile

//--- Logging e Estatísticas
input group "═══════════════ LOGGING ═══════════════"
input ENUM_LOG_LEVEL Inp_LogLevel  = LOG_NORMAL;       // Nível de Log
input bool     Inp_TrackByDay      = true;             // Estatísticas por Dia
input bool     Inp_TrackByHour     = true;             // Estatísticas por Hora
input bool     Inp_TrackByStrength = true;             // Estatísticas por Força
input bool     Inp_TrackBySession  = true;             // Estatísticas por Sessão
input bool     Inp_ExportStats     = false;            // Exportar para Arquivo

//+------------------------------------------------------------------+
//| Variáveis Globais                                                |
//+------------------------------------------------------------------+
//--- Módulos
CAssetSpecs       g_AssetSpecs;
CSignalFGM        g_SignalFGM;
CRiskManager      g_RiskManager;
CTradeEngine      g_TradeEngine;
CTimeFilter       g_TimeFilter;
CRegimeDetector   g_RegimeDetector;
CFilters          g_Filters;
CStats            g_Stats;

//--- Estado
datetime          g_lastBarTime = 0;
int               g_currentStrength = 0;
string            g_currentSession = "";
bool              g_isInitialized = false;
double            g_dailyStartBalance = 0;
int               g_todayTrades = 0;

//--- Tracking de posição
bool              g_hasPosition = false;
datetime          g_positionOpenTime = 0;
double            g_positionOpenPrice = 0;
double            g_positionSL = 0;
double            g_positionVolume = 0;
ENUM_POSITION_TYPE g_positionType;
int               g_partialCloseStep = 0; // 0=nenhum, 1=TP1 fechado, 2=TP2 fechado

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Validar parâmetros
   if(Inp_RiskPercent <= 0 || Inp_RiskPercent > 10)
   {
      Print("[FGM] Erro: Risco deve estar entre 0.1% e 10%");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   if(Inp_MinStrength < 3 || Inp_MinStrength > 5)
   {
      Print("[FGM] Erro: Força mínima deve estar entre 3 e 5");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   //--- Inicializar Asset Specs
   if(!g_AssetSpecs.Init(Symbol()))
   {
      Print("[FGM] Erro ao inicializar Asset Specs");
      return INIT_FAILED;
   }
   
   //--- Inicializar Signal FGM
   if(!g_SignalFGM.Init(Symbol(), Period(),
                        Inp_FGM_Period1, Inp_FGM_Period2, Inp_FGM_Period3,
                        Inp_FGM_Period4, Inp_FGM_Period5))
   {
      Print("[FGM] Erro ao inicializar indicador FGM");
      return INIT_FAILED;
   }
   
   //--- Inicializar Risk Manager
   if(!g_RiskManager.Init(&g_AssetSpecs, 14))
   {
      Print("[FGM] Erro ao inicializar Risk Manager");
      return INIT_FAILED;
   }
   
   //--- Configurar parâmetros de risco
   RiskParams riskParams;
   riskParams.riskPercent = Inp_RiskPercent;
   riskParams.riskMultF5 = Inp_ForceMultF5;
   riskParams.riskMultF4 = Inp_ForceMultF4;
   riskParams.riskMultF3 = Inp_ForceMultF3;
   riskParams.maxDailyDD = Inp_MaxDailyDD;
   riskParams.maxConsecStops = Inp_MaxConsecLoss;
   riskParams.tp1RR = Inp_TP1_RR;
   riskParams.tp2RR = Inp_TP2_RR;
   riskParams.tp1ClosePercent = (int)Inp_TP1_Percent;
   riskParams.tp2ClosePercent = (int)Inp_TP2_Percent;
   riskParams.tp3ClosePercent = (int)Inp_TP3_Percent;
   riskParams.beActive = Inp_UseBE;
   riskParams.beOffsetWIN = Inp_BE_Offset;
   riskParams.beOffsetWDO = Inp_BE_Offset;
   riskParams.beOffsetForex = Inp_BE_Offset;
   riskParams.dailyProtection = true;
   g_RiskManager.SetRiskParams(riskParams);
   
   //--- Inicializar Trade Engine
   if(!g_TradeEngine.Init(&g_AssetSpecs, (long)Inp_MagicNumber, Inp_EAComment, 10))
   {
      Print("[FGM] Erro ao inicializar Trade Engine");
      return INIT_FAILED;
   }
   
   //--- Inicializar Time Filter
   if(!g_TimeFilter.Init(&g_AssetSpecs, Inp_BrokerOffset))
   {
      Print("[FGM] Erro ao inicializar Time Filter");
      return INIT_FAILED;
   }
   
   //--- Inicializar Regime Detector
   if(!g_RegimeDetector.Init(&g_AssetSpecs))
   {
      Print("[FGM] Erro ao inicializar Regime Detector");
      return INIT_FAILED;
   }
   
   //--- Inicializar Filters
   if(!g_Filters.Init(&g_AssetSpecs, &g_SignalFGM, &g_RegimeDetector))
   {
      Print("[FGM] Erro ao inicializar Filters");
      return INIT_FAILED;
   }
   
   //--- Inicializar Stats
   if(!g_Stats.Init(Inp_MagicNumber, Inp_LogLevel,
               Inp_TrackByDay, Inp_TrackByHour,
               Inp_TrackByStrength, Inp_TrackBySession,
               Inp_ExportStats, "FGM_Stats"))
   {
      Print("[FGM] Erro ao inicializar Stats");
      return INIT_FAILED;
   }
   
   //--- Salvar balance inicial
   g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   //--- Verificar posição existente
   CheckExistingPosition();
   
   g_isInitialized = true;
   g_Stats.LogNormal(StringFormat("FGM Trend Rider v%s inicializado - %s %s", 
                                  "1.00", Symbol(), EnumToString(Period())));
   g_Stats.LogNormal(StringFormat("Tipo de ativo: %s | Magic: %d", 
                                  EnumToString(g_AssetSpecs.GetAssetType()), Inp_MagicNumber));
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Exportar estatísticas se configurado
   if(Inp_ExportStats)
      g_Stats.ExportStats();
   
   //--- Imprimir relatório final
   g_Stats.PrintReport();
   
   g_Stats.LogNormal(StringFormat("FGM Trend Rider desinicializado. Razão: %d", reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_isInitialized)
      return;
   
   //--- Verificar se é nova barra (se configurado)
   bool isNewBar = IsNewBar();
   
   if(Inp_TradeOnNewBar && !isNewBar && !g_hasPosition)
      return;
   
   //--- Atualizar cooldown dos filtros
   if(isNewBar)
      g_Filters.OnNewBar();
   
   //--- Verificar proteção diária
   if(!g_RiskManager.CheckDailyProtection())
   {
      if(isNewBar)
         g_Stats.LogMinimal("Proteção diária ativada - Trading pausado");
      return;
   }
   
   //--- Gerenciar posição existente
   if(g_hasPosition)
   {
      ManagePosition();
   }
   
   //--- Verificar hard exit
   if(Inp_UseTimeFilter && g_TimeFilter.IsHardExitPeriod())
   {
      if(g_hasPosition)
      {
         g_Stats.LogNormal("Hard Exit ativado - Fechando posição");
         CloseAllPositions("Hard Exit");
      }
      return;
   }
   
   //--- Processar sinais apenas em nova barra
   if(!isNewBar && Inp_TradeOnNewBar)
      return;
   
   //--- Verificar cooldown
   if(g_Filters.IsInCooldown())
   {
      g_Stats.LogDebug("Cooldown ativo - Aguardando");
      return;
   }
   
   //--- Buscar novos sinais se não tem posição
   if(!g_hasPosition)
   {
      ProcessSignals();
   }
}

//+------------------------------------------------------------------+
//| Verificar se é nova barra                                        |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(Symbol(), Period(), 0);
   
   if(currentBarTime != g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Verificar posição existente                                      |
//+------------------------------------------------------------------+
void CheckExistingPosition()
{
   g_hasPosition = false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == Inp_MagicNumber &&
            PositionGetString(POSITION_SYMBOL) == Symbol())
         {
            g_hasPosition = true;
            g_positionOpenTime = (datetime)PositionGetInteger(POSITION_TIME);
            g_positionOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            g_positionSL = PositionGetDouble(POSITION_SL);
            g_positionVolume = PositionGetDouble(POSITION_VOLUME);
            g_positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Processar sinais do indicador FGM                                |
//+------------------------------------------------------------------+
void ProcessSignals()
{
   //--- Verificar horário de trading
   if(Inp_UseTimeFilter)
   {
      if(!g_TimeFilter.CanOpenNewPosition())
      {
         g_Stats.LogDebug("Fora do horário de trading ou Soft Exit ativo");
         return;
      }
   }
   
   //--- Atualizar buffers do indicador
   if(!g_SignalFGM.Update(5))
   {
      g_Stats.LogDebug("Erro ao atualizar dados do indicador");
      return;
   }
   
   //--- Verificar sinal de entrada em AMBAS as barras (0 e 1)
   //--- Ajuste: priorizar barra 0 (barra atual / fechamento recente)
   //--- para reduzir atraso na entrada em relação ao início da tendência.
   FGM_DATA fgmData;
   int signalBar = -1;
   
   //--- Primeiro verificar barra 0 (barra atual). Se o cruzamento ocorreu
   //--- nesta barra, o EA pode entrar imediatamente ao início da nova barra
   //--- (com Inp_TradeOnNewBar=true) ou até intrabar (se TradeOnNewBar=false).
   fgmData = g_SignalFGM.GetData(0);
   if(fgmData.isValid && fgmData.entry != 0)
   {
      signalBar = 0;
   }
   else
   {
      //--- Se não há sinal na barra 0, verificar barra 1 (barra recém-fechada)
      fgmData = g_SignalFGM.GetData(1);
      if(fgmData.isValid && fgmData.entry != 0)
      {
         signalBar = 1;
      }
   }
   
   if(signalBar < 0 || !fgmData.isValid)
   {
      // Não há sinal de entrada em nenhuma das barras
      return;
   }
   
   //--- DEBUG: Log valores lidos do indicador
   g_Stats.LogDebug(StringFormat("FGM Data (bar %d): Strength=%.0f, Entry=%.0f, Confluence=%.1f%%", 
                                 signalBar, fgmData.strength, fgmData.entry, fgmData.confluence));
   
   //--- Verificar sinal de entrada
   double entrySignal = fgmData.entry;
   
   //--- Log sinal detectado
   g_Stats.LogNormal(StringFormat("Sinal detectado! Bar=%d, Entry=%.0f, Strength=%.0f, Confluence=%.1f%%",
                                  signalBar, entrySignal, fgmData.strength, fgmData.confluence));
   
   //--- Verificar força mínima do sinal (usar valor absoluto - negativo para SELL)
   int signalStrength = (int)MathAbs(fgmData.strength);
   if(signalStrength < Inp_MinStrength)
   {
      g_Stats.LogNormal(StringFormat("Força insuficiente: F%d (mín: F%d)", 
                                    signalStrength, Inp_MinStrength));
      return;
   }
   
   //--- Verificar confluência (compressão das EMAs)
   //--- IMPORTANTE: neste indicador, confluência ALTA = EMAs MUITO próximas = MERCADO LATERAL
   //---              confluência BAIXA = EMAs afastadas = TENDÊNCIA FORTE
   double confluence = fgmData.confluence;

   //--- Limite máximo de confluência aceitável por força do sinal.
   //--- Estes limites são ajustáveis por input para não descaracterizar
   //--- o EA em outros ativos/mercados.
   double maxConfluenceAllowed = 100.0;

   if(signalStrength >= 5)
      maxConfluenceAllowed = Inp_MaxConf_F5;
   else if(signalStrength == 4)
      maxConfluenceAllowed = Inp_MaxConf_F4;
   else if(signalStrength == 3)
      maxConfluenceAllowed = Inp_MaxConf_F3;

   if(confluence > maxConfluenceAllowed)
   {
      g_Stats.LogNormal(StringFormat("Confluência alta demais (mercado lateral) para F%d: %.1f%% (máx: %.1f%%)",
                                    signalStrength, confluence, maxConfluenceAllowed));
      return;
   }

   g_Stats.LogNormal(StringFormat("Sinal aprovado! F%d, Confluência=%.1f%% (máx: %.1f%%)",
                                  signalStrength, confluence, maxConfluenceAllowed));
   
   //--- Determinar direção
   bool isBuy = (entrySignal > 0);
   bool isSell = (entrySignal < 0);
   
   //--- Verificar permissões de direção
   if(isBuy && !Inp_AllowBuy)
   {
      g_Stats.LogDebug("Sinal de compra bloqueado por configuração");
      return;
   }
   
   if(isSell && !Inp_AllowSell)
   {
      g_Stats.LogDebug("Sinal de venda bloqueado por configuração");
      return;
   }
   
   //--- Aplicar filtros
   FilterResult filterResult = g_Filters.CheckAll(isBuy, Inp_MinStrength);
   if(!filterResult.passed)
   {
      g_Stats.LogNormal(StringFormat("FILTRO BLOQUEOU: %s", filterResult.failReason));
      return;
   }
   
   g_Stats.LogNormal("Todos os filtros passaram - Preparando ordem...");
   
   //--- Detectar regime de mercado
   ENUM_MARKET_REGIME regime = REGIME_TRENDING;
   double regimeMultiplier = 1.0;
   
   if(Inp_UseRegime)
   {
      regime = g_RegimeDetector.GetCurrentRegime();
      
      switch(regime)
      {
         case REGIME_TRENDING:
            regimeMultiplier = Inp_TrendMult;
            break;
         case REGIME_RANGING:
            regimeMultiplier = Inp_RangeMult;
            break;
         case REGIME_VOLATILE:
            regimeMultiplier = Inp_VolatileMult;
            break;
      }
      
      g_Stats.LogDebug(StringFormat("Regime: %s | Mult: %.2f", 
                                    g_RegimeDetector.GetRegimeString(regime), regimeMultiplier));
   }
   
   //--- Log do sinal
   g_Stats.LogSignal(signalStrength, confluence / 100.0, isBuy ? "BUY" : "SELL");
   
   //--- Calcular posição usando RiskManager
   double entryPrice = isBuy ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) 
                            : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   
   bool isVolatile = (regime == REGIME_VOLATILE);
   PositionCalcResult posCalc = g_RiskManager.CalculatePosition(entryPrice, isBuy, signalStrength, isVolatile);
   
   if(!posCalc.isValid)
   {
      g_Stats.LogError(StringFormat("Cálculo de posição inválido: %s", posCalc.errorMessage));
      return;
   }
   
   //--- Armazenar força e sessão
   g_currentStrength = signalStrength;
   g_currentSession = g_TimeFilter.GetSessionName(g_TimeFilter.GetCurrentForexSession());
   
   //--- Executar entrada
   TradeResult tradeResult;
   
   if(isBuy)
      tradeResult = g_TradeEngine.OpenBuy(posCalc.lotSize, posCalc.slPrice, posCalc.tp1Price);
   else
      tradeResult = g_TradeEngine.OpenSell(posCalc.lotSize, posCalc.slPrice, posCalc.tp1Price);
   
   if(tradeResult.success)
   {
      g_hasPosition = true;
      g_positionOpenTime = TimeCurrent();
      g_positionOpenPrice = tradeResult.price > 0 ? tradeResult.price : entryPrice;
      g_positionSL = posCalc.slPrice;
      g_positionVolume = posCalc.lotSize;
      g_positionType = isBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      g_partialCloseStep = 0;
      g_todayTrades++;
      
      //--- Armazenar TPs no trade engine
      g_TradeEngine.SetTP1Price(posCalc.tp1Price);
      g_TradeEngine.SetTP2Price(posCalc.tp2Price);
      g_TradeEngine.SetBEPrice(posCalc.bePrice);
      g_TradeEngine.SetOriginalVolume(posCalc.lotSize);
      
      g_Stats.LogTrade(isBuy ? "BUY" : "SELL", g_positionOpenPrice, posCalc.lotSize, 
                       posCalc.slPrice, posCalc.tp1Price);
   }
   else
   {
      g_Stats.LogError(StringFormat("Falha ao abrir posição: %s", tradeResult.message));
   }
}

//+------------------------------------------------------------------+
//| Gerenciar posição aberta                                         |
//+------------------------------------------------------------------+
void ManagePosition()
{
   //--- Atualizar informações da posição
   CheckExistingPosition();
   
   if(!g_hasPosition)
   {
      //--- Posição foi fechada (SL/TP hit)
      OnPositionClosed();
      return;
   }
   
   double currentPrice = (g_positionType == POSITION_TYPE_BUY) 
                        ? SymbolInfoDouble(Symbol(), SYMBOL_BID)
                        : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double profitPoints = 0;
   
   if(g_positionType == POSITION_TYPE_BUY)
      profitPoints = (currentPrice - g_positionOpenPrice) / point;
   else
      profitPoints = (g_positionOpenPrice - currentPrice) / point;
   
   //--- Sistema Triple Exit
   if(Inp_UseTripleExit)
   {
      ManageTripleExit(profitPoints, currentPrice);
   }
   
   //--- Break-Even
   if(Inp_UseBE && g_partialCloseStep >= 1) // Após TP1
   {
      ManageBreakEven(profitPoints, currentPrice);
   }
   
   //--- Trailing Stop
   if(Inp_UseTrailing && g_partialCloseStep >= 2) // Após TP2
   {
      ManageTrailingStop(profitPoints, currentPrice);
   }
   
   //--- Verificar sinal de saída do indicador
   if(g_SignalFGM.Update(2))
   {
      FGM_DATA fgmData = g_SignalFGM.GetData(0);
      
      if(fgmData.isValid && fgmData.exitSignal != 0)
      {
         bool shouldExit = false;
         
         if(g_positionType == POSITION_TYPE_BUY && fgmData.exitSignal > 0)
            shouldExit = true;
         else if(g_positionType == POSITION_TYPE_SELL && fgmData.exitSignal < 0)
            shouldExit = true;
         
         if(shouldExit && profitPoints > 0) // Apenas se em lucro
         {
            g_Stats.LogNormal("Sinal de saída do indicador detectado");
            CloseAllPositions("FGM Exit Signal");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gerenciar Triple Exit                                            |
//+------------------------------------------------------------------+
void ManageTripleExit(double profitPoints, double currentPrice)
{
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double slDistance = MathAbs(g_positionOpenPrice - g_positionSL);
   
   //--- TP1: Fechar percentual em R:R 1
   if(g_partialCloseStep == 0)
   {
      double tp1Distance = slDistance * Inp_TP1_RR;
      double tp1Points = tp1Distance / point;
      
      if(profitPoints >= tp1Points)
      {
         double closeVolume = g_positionVolume * (Inp_TP1_Percent / 100.0);
         closeVolume = g_AssetSpecs.NormalizeLot(closeVolume);
         
         if(closeVolume > 0)
         {
            TradeResult result = g_TradeEngine.ClosePositionPartial(closeVolume);
            if(result.success)
            {
               g_Stats.LogNormal(StringFormat("TP1 atingido - Fechado %.2f lotes (%.0f%%)",
                                             closeVolume, Inp_TP1_Percent));
               g_partialCloseStep = 1;
               g_positionVolume -= closeVolume;
               g_TradeEngine.SetTP1Hit(true);
            }
         }
      }
   }
   
   //--- TP2: Fechar percentual em R:R 2
   if(g_partialCloseStep == 1)
   {
      double tp2Distance = slDistance * Inp_TP2_RR;
      double tp2Points = tp2Distance / point;
      
      if(profitPoints >= tp2Points)
      {
         double closeVolume = g_positionVolume * (Inp_TP2_Percent / (Inp_TP2_Percent + Inp_TP3_Percent));
         closeVolume = g_AssetSpecs.NormalizeLot(closeVolume);
         
         if(closeVolume > 0)
         {
            TradeResult result = g_TradeEngine.ClosePositionPartial(closeVolume);
            if(result.success)
            {
               g_Stats.LogNormal(StringFormat("TP2 atingido - Fechado %.2f lotes", closeVolume));
               g_partialCloseStep = 2;
               g_positionVolume -= closeVolume;
               g_TradeEngine.SetTP2Hit(true);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gerenciar Break-Even                                             |
//+------------------------------------------------------------------+
void ManageBreakEven(double profitPoints, double currentPrice)
{
   //--- Verificar se já está em BE
   if(g_TradeEngine.IsBEActivated())
      return;
   
   //--- Mover para BE se trigger atingido
   if(profitPoints >= Inp_BE_Trigger)
   {
      if(g_TradeEngine.MoveToBreakeven(Inp_BE_Offset))
      {
         g_Stats.LogNormal("Break-Even ativado");
      }
   }
}

//+------------------------------------------------------------------+
//| Gerenciar Trailing Stop                                          |
//+------------------------------------------------------------------+
void ManageTrailingStop(double profitPoints, double currentPrice)
{
   if(profitPoints < Inp_Trail_Trigger)
      return;
   
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double distance = Inp_Trail_Distance * point;
   double step = Inp_Trail_Step * point;
   
   if(g_TradeEngine.TrailingByFixed(distance, step))
   {
      g_Stats.LogDebug("Trailing Stop atualizado");
   }
}

//+------------------------------------------------------------------+
//| Handler quando posição é fechada                                 |
//+------------------------------------------------------------------+
void OnPositionClosed()
{
   //--- Buscar último deal no histórico
   datetime from = g_positionOpenTime;
   datetime to = TimeCurrent();
   
   HistorySelect(from, to);
   
   int totalDeals = HistoryDealsTotal();
   double lastProfit = 0;
   string closeReason = "Unknown";
   
   for(int i = totalDeals - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == Inp_MagicNumber &&
         HistoryDealGetString(ticket, DEAL_SYMBOL) == Symbol())
      {
         ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
         
         if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
         {
            lastProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            
            ENUM_DEAL_REASON reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(ticket, DEAL_REASON);
            
            switch(reason)
            {
               case DEAL_REASON_SL: closeReason = "Stop Loss"; break;
               case DEAL_REASON_TP: closeReason = "Take Profit"; break;
               case DEAL_REASON_CLIENT: closeReason = "Manual/EA"; break;
               default: closeReason = "Other"; break;
            }
            
            break;
         }
      }
   }
   
   //--- Atualizar estatísticas de risco
   bool isWin = (lastProfit > 0);
   g_RiskManager.UpdateDailyStats(lastProfit, isWin);
   
   //--- Iniciar cooldown se foi stop
   if(closeReason == "Stop Loss")
   {
      g_Filters.StartCooldownAfterStop();
   }
   
   //--- Registrar trade nas estatísticas
   g_Stats.RecordTrade(
      g_positionOpenTime,
      TimeCurrent(),
      (g_positionType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
      g_positionOpenPrice,
      (g_positionType == POSITION_TYPE_BUY) ? SymbolInfoDouble(Symbol(), SYMBOL_BID) 
                                            : SymbolInfoDouble(Symbol(), SYMBOL_ASK),
      g_positionVolume,
      lastProfit,
      g_currentStrength,
      g_currentSession,
      closeReason
   );
   
   //--- Reset variáveis
   g_hasPosition = false;
   g_partialCloseStep = 0;
   g_positionOpenTime = 0;
   g_positionOpenPrice = 0;
   g_positionSL = 0;
   g_positionVolume = 0;
   
   g_Stats.LogNormal(StringFormat("Posição fechada - Lucro: %.2f | Razão: %s", 
                                  lastProfit, closeReason));
}

//+------------------------------------------------------------------+
//| Fechar todas as posições                                         |
//+------------------------------------------------------------------+
void CloseAllPositions(const string reason)
{
   TradeResult result = g_TradeEngine.CloseAllByMagic((long)Inp_MagicNumber);
   
   if(result.success)
   {
      g_Stats.LogNormal(StringFormat("Posições fechadas - Razão: %s | %s", reason, result.message));
   }
   
   g_hasPosition = false;
}

//+------------------------------------------------------------------+
//| Evento de trade                                                  |
//+------------------------------------------------------------------+
void OnTrade()
{
   //--- Verificar mudanças de posição
   CheckExistingPosition();
}

//+------------------------------------------------------------------+
//| Timer event - Reset diário                                       |
//+------------------------------------------------------------------+
void OnTimer()
{
   static datetime lastResetDay = 0;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00:00", 
                                              dt.year, dt.mon, dt.day));
   
   if(today != lastResetDay)
   {
      //--- Novo dia
      g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_RiskManager.ResetDailyProtection();
      g_Stats.ResetDailyStats();
      g_Filters.ResetCooldown();
      g_todayTrades = 0;
      
      lastResetDay = today;
      g_Stats.LogNormal("Reset diário executado");
   }
}
//+------------------------------------------------------------------+

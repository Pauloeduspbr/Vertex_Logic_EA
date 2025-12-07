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
input string   Inp_StartTime       = "09:15";          // Horário Início
input string   Inp_EndTime         = "17:30";          // Horário Fim (Soft Exit)
input string   Inp_HardExit        = "17:50";          // Hard Exit (força fechamento)
input bool     Inp_CloseEOD        = true;             // Fechar posições fim do dia

//--- Parâmetros do Indicador FGM
input group "═══════════════ INDICADOR FGM ═══════════════"
input string   Inp_FGM_Path        = "FGM_TrendRider_EA\\FGM_Indicator"; // Caminho do Indicador
input int      Inp_FGM_Period1     = 8;                // Período EMA 1
input int      Inp_FGM_Period2     = 21;               // Período EMA 2
input int      Inp_FGM_Period3     = 50;               // Período EMA 3
input int      Inp_FGM_Period4     = 100;              // Período EMA 4
input int      Inp_FGM_Period5     = 200;              // Período EMA 5
input int      Inp_MinStrength     = 3;                // Força Mínima (3-5)
input double   Inp_MinConfluence   = 60.0;             // Confluência Mínima (%)

//--- Filtros Adicionais
input group "═══════════════ FILTROS ═══════════════"
input bool     Inp_UseSlopeFilter  = true;             // Usar Filtro de Slope
input double   Inp_MinSlope        = 0.0001;           // Slope Mínimo
input bool     Inp_UseVolumeFilter = true;             // Usar Filtro de Volume (B3)
input double   Inp_VolumeMultMin   = 0.5;              // Volume Mínimo (x média)
input bool     Inp_UseATRFilter    = true;             // Usar Filtro ATR
input int      Inp_CooldownBars    = 3;                // Cooldown após trade (barras)

//--- Regime de Mercado
input group "═══════════════ REGIME DE MERCADO ═══════════════"
input bool     Inp_UseRegime       = true;             // Usar Detecção de Regime
input double   Inp_RegimeTrend     = 1.2;              // Threshold Trending (ATR ratio)
input double   Inp_RegimeVolatile  = 2.0;              // Threshold Volatile (ATR ratio)
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
   if(!g_SignalFGM.Init(Symbol(), Period(), Inp_FGM_Path,
                        Inp_FGM_Period1, Inp_FGM_Period2, Inp_FGM_Period3,
                        Inp_FGM_Period4, Inp_FGM_Period5))
   {
      Print("[FGM] Erro ao inicializar indicador FGM");
      return INIT_FAILED;
   }
   
   //--- Inicializar Risk Manager
   g_RiskManager.Init(Symbol(), Inp_MagicNumber, Inp_RiskPercent,
                     Inp_MaxDailyDD, Inp_MaxTotalDD, Inp_MaxConsecLoss,
                     Inp_ForceMultF3, Inp_ForceMultF4, Inp_ForceMultF5);
   
   //--- Inicializar Trade Engine
   if(!g_TradeEngine.Init(Symbol(), Inp_MagicNumber, Inp_EAComment,
                         3, 10)) // 3 tentativas, 10 slippage
   {
      Print("[FGM] Erro ao inicializar Trade Engine");
      return INIT_FAILED;
   }
   
   //--- Inicializar Time Filter
   g_TimeFilter.Init(Inp_StartTime, Inp_EndTime, Inp_HardExit, Inp_CloseEOD);
   
   //--- Inicializar Regime Detector
   g_RegimeDetector.Init(Symbol(), Period(), 14, 50, 
                        Inp_RegimeTrend, Inp_RegimeVolatile);
   
   //--- Inicializar Filters
   g_Filters.Init(Symbol(), Period(),
                 Inp_MinSlope, Inp_MaxSpread,
                 Inp_VolumeMultMin, 1.5,   // Volume min/max
                 0.5, 2.5,                  // ATR min/max ratio
                 Inp_CooldownBars);
   
   //--- Inicializar Stats
   g_Stats.Init(Inp_MagicNumber, Inp_LogLevel,
               Inp_TrackByDay, Inp_TrackByHour,
               Inp_TrackByStrength, Inp_TrackBySession,
               Inp_ExportStats, "FGM_Stats");
   
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
   
   //--- Atualizar métricas de risco
   g_RiskManager.UpdateDailyDrawdown(g_dailyStartBalance);
   
   //--- Verificar drawdown
   if(g_RiskManager.IsMaxDailyDDReached() || g_RiskManager.IsMaxTotalDDReached())
   {
      if(isNewBar)
         g_Stats.LogMinimal("Drawdown máximo atingido - Trading pausado");
      return;
   }
   
   //--- Verificar perdas consecutivas
   if(g_RiskManager.ShouldPauseTrading())
   {
      if(isNewBar)
         g_Stats.LogNormal("Máximo de perdas consecutivas atingido - Aguardando");
      return;
   }
   
   //--- Gerenciar posição existente
   if(g_hasPosition)
   {
      ManagePosition();
   }
   
   //--- Verificar hard exit
   if(Inp_UseTimeFilter && g_TimeFilter.IsHardExit())
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
   if(!g_Filters.CanTradeAfterCooldown())
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
      if(!g_TimeFilter.IsTradingAllowed())
      {
         g_Stats.LogDebug("Fora do horário de trading");
         return;
      }
      
      if(g_TimeFilter.IsSoftExit())
      {
         g_Stats.LogDebug("Soft Exit - Não abrindo novas posições");
         return;
      }
   }
   
   //--- Ler dados do indicador
   FGM_DATA fgmData;
   if(!g_SignalFGM.ReadData(fgmData, 1)) // Candle fechado
   {
      g_Stats.LogDebug("Erro ao ler dados do indicador");
      return;
   }
   
   //--- Verificar força mínima do sinal
   int signalStrength = fgmData.Strength;
   if(signalStrength < Inp_MinStrength)
   {
      g_Stats.LogDebug(StringFormat("Força insuficiente: F%d (mín: F%d)", 
                                    signalStrength, Inp_MinStrength));
      return;
   }
   
   //--- Verificar confluência mínima
   double confluence = fgmData.Confluence;
   if(confluence < Inp_MinConfluence / 100.0)
   {
      g_Stats.LogDebug(StringFormat("Confluência insuficiente: %.1f%% (mín: %.1f%%)",
                                    confluence * 100, Inp_MinConfluence));
      return;
   }
   
   //--- Verificar sinal de entrada
   int entrySignal = fgmData.Entry;
   if(entrySignal == 0)
   {
      g_Stats.LogDebug("Sem sinal de entrada");
      return;
   }
   
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
   if(!ApplyFilters(isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL))
   {
      return;
   }
   
   //--- Detectar regime de mercado
   ENUM_MARKET_REGIME regime = REGIME_TRENDING;
   double regimeMultiplier = 1.0;
   
   if(Inp_UseRegime)
   {
      regime = g_RegimeDetector.DetectRegime();
      
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
                                    EnumToString(regime), regimeMultiplier));
   }
   
   //--- Log do sinal
   g_Stats.LogSignal(signalStrength, confluence, isBuy ? "BUY" : "SELL");
   
   //--- Calcular Stop Loss
   double sl = CalculateStopLoss(isBuy);
   
   //--- Calcular Take Profit
   double tp = CalculateTakeProfit(isBuy, sl);
   
   //--- Calcular lote
   double slDistance = MathAbs(SymbolInfoDouble(Symbol(), SYMBOL_ASK) - sl);
   double lot = g_RiskManager.CalculateLot(slDistance, signalStrength, regimeMultiplier);
   lot = g_AssetSpecs.NormalizeLot(lot);
   
   if(lot <= 0)
   {
      g_Stats.LogError("Lote calculado inválido");
      return;
   }
   
   //--- Armazenar força e sessão
   g_currentStrength = signalStrength;
   g_currentSession = g_TimeFilter.GetCurrentSession();
   
   //--- Executar entrada
   bool success = false;
   
   if(isBuy)
      success = g_TradeEngine.OpenPosition(ORDER_TYPE_BUY, lot, sl, tp);
   else
      success = g_TradeEngine.OpenPosition(ORDER_TYPE_SELL, lot, sl, tp);
   
   if(success)
   {
      g_hasPosition = true;
      g_positionOpenTime = TimeCurrent();
      g_positionOpenPrice = isBuy ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) 
                                  : SymbolInfoDouble(Symbol(), SYMBOL_BID);
      g_positionSL = sl;
      g_positionVolume = lot;
      g_positionType = isBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      g_partialCloseStep = 0;
      g_todayTrades++;
      
      g_Filters.RegisterTrade(); // Ativar cooldown
      
      g_Stats.LogTrade(isBuy ? "BUY" : "SELL", g_positionOpenPrice, lot, sl, tp);
   }
   else
   {
      g_Stats.LogError("Falha ao abrir posição");
   }
}

//+------------------------------------------------------------------+
//| Aplicar filtros de entrada                                       |
//+------------------------------------------------------------------+
bool ApplyFilters(ENUM_ORDER_TYPE orderType)
{
   //--- Filtro de spread
   if(!g_Filters.CheckSpread(Inp_MaxSpread))
   {
      g_Stats.LogFilter("Spread", false, StringFormat("%.1f > %d", 
                       SymbolInfoInteger(Symbol(), SYMBOL_SPREAD), Inp_MaxSpread));
      return false;
   }
   g_Stats.LogFilter("Spread", true);
   
   //--- Filtro de slope
   if(Inp_UseSlopeFilter)
   {
      bool slopeOK = g_Filters.CheckSlope(orderType, Inp_MinSlope);
      if(!slopeOK)
      {
         g_Stats.LogFilter("Slope", false);
         return false;
      }
      g_Stats.LogFilter("Slope", true);
   }
   
   //--- Filtro de volume (apenas B3)
   if(Inp_UseVolumeFilter && g_AssetSpecs.GetAssetType() != ASSET_FOREX)
   {
      bool volumeOK = g_Filters.CheckVolume();
      if(!volumeOK)
      {
         g_Stats.LogFilter("Volume", false);
         return false;
      }
      g_Stats.LogFilter("Volume", true);
   }
   
   //--- Filtro ATR
   if(Inp_UseATRFilter)
   {
      bool atrOK = g_Filters.CheckATR();
      if(!atrOK)
      {
         g_Stats.LogFilter("ATR", false);
         return false;
      }
      g_Stats.LogFilter("ATR", true);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calcular Stop Loss                                               |
//+------------------------------------------------------------------+
double CalculateStopLoss(bool isBuy)
{
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double price = isBuy ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) 
                       : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double sl = 0;
   
   switch(Inp_SLMode)
   {
      case SL_FIXED:
         if(isBuy)
            sl = price - Inp_SL_Points * point;
         else
            sl = price + Inp_SL_Points * point;
         break;
         
      case SL_ATR:
         {
            double atr = g_RegimeDetector.GetCurrentATR();
            double atrSL = atr * Inp_SL_ATR_Mult;
            
            if(isBuy)
               sl = price - atrSL;
            else
               sl = price + atrSL;
         }
         break;
         
      case SL_HYBRID:
         {
            double fixedSL = Inp_SL_Points * point;
            double atr = g_RegimeDetector.GetCurrentATR();
            double atrSL = atr * Inp_SL_ATR_Mult;
            double slDistance = MathMax(fixedSL, atrSL);
            
            // Aplicar limites
            slDistance = MathMax(slDistance, Inp_SL_Min * point);
            slDistance = MathMin(slDistance, Inp_SL_Max * point);
            
            if(isBuy)
               sl = price - slDistance;
            else
               sl = price + slDistance;
         }
         break;
   }
   
   return NormalizeDouble(sl, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
//| Calcular Take Profit                                             |
//+------------------------------------------------------------------+
double CalculateTakeProfit(bool isBuy, double sl)
{
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double price = isBuy ? SymbolInfoDouble(Symbol(), SYMBOL_ASK) 
                       : SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double tp = 0;
   double slDistance = MathAbs(price - sl);
   
   switch(Inp_TPMode)
   {
      case TP_FIXED:
         if(isBuy)
            tp = price + Inp_TP_Points * point;
         else
            tp = price - Inp_TP_Points * point;
         break;
         
      case TP_RR_RATIO:
         {
            double tpDistance = slDistance * Inp_TP_RR_Ratio;
            
            if(isBuy)
               tp = price + tpDistance;
            else
               tp = price - tpDistance;
         }
         break;
         
      case TP_ATR:
         {
            double atr = g_RegimeDetector.GetCurrentATR();
            double tpDistance = atr * Inp_TP_ATR_Mult;
            
            if(isBuy)
               tp = price + tpDistance;
            else
               tp = price - tpDistance;
         }
         break;
   }
   
   return NormalizeDouble(tp, (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
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
   FGM_DATA fgmData;
   if(g_SignalFGM.ReadData(fgmData, 0))
   {
      if(fgmData.Exit != 0)
      {
         bool shouldExit = false;
         
         if(g_positionType == POSITION_TYPE_BUY && fgmData.Exit < 0)
            shouldExit = true;
         else if(g_positionType == POSITION_TYPE_SELL && fgmData.Exit > 0)
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
         
         if(closeVolume > 0 && g_TradeEngine.ClosePartial(closeVolume))
         {
            g_Stats.LogNormal(StringFormat("TP1 atingido - Fechado %.2f lotes (%.0f%%)",
                                          closeVolume, Inp_TP1_Percent));
            g_partialCloseStep = 1;
            g_positionVolume -= closeVolume;
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
         
         if(closeVolume > 0 && g_TradeEngine.ClosePartial(closeVolume))
         {
            g_Stats.LogNormal(StringFormat("TP2 atingido - Fechado %.2f lotes",
                                          closeVolume));
            g_partialCloseStep = 2;
            g_positionVolume -= closeVolume;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gerenciar Break-Even                                             |
//+------------------------------------------------------------------+
void ManageBreakEven(double profitPoints, double currentPrice)
{
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   
   //--- Verificar se já está em BE
   double currentSL = 0;
   if(PositionSelect(Symbol()))
      currentSL = PositionGetDouble(POSITION_SL);
   
   bool alreadyInBE = false;
   if(g_positionType == POSITION_TYPE_BUY && currentSL >= g_positionOpenPrice)
      alreadyInBE = true;
   else if(g_positionType == POSITION_TYPE_SELL && currentSL <= g_positionOpenPrice && currentSL > 0)
      alreadyInBE = true;
   
   if(alreadyInBE)
      return;
   
   //--- Mover para BE se trigger atingido
   if(profitPoints >= Inp_BE_Trigger)
   {
      double newSL;
      
      if(g_positionType == POSITION_TYPE_BUY)
         newSL = g_positionOpenPrice + Inp_BE_Offset * point;
      else
         newSL = g_positionOpenPrice - Inp_BE_Offset * point;
      
      if(g_TradeEngine.MoveToBreakEven(g_positionOpenPrice, Inp_BE_Offset * point))
      {
         g_Stats.LogNormal(StringFormat("Break-Even ativado @ %.5f", newSL));
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
   
   //--- Obter SL atual
   double currentSL = 0;
   if(PositionSelect(Symbol()))
      currentSL = PositionGetDouble(POSITION_SL);
   
   double newSL = 0;
   bool shouldUpdate = false;
   
   if(g_positionType == POSITION_TYPE_BUY)
   {
      newSL = currentPrice - Inp_Trail_Distance * point;
      
      if(newSL > currentSL && (newSL - currentSL) >= Inp_Trail_Step * point)
         shouldUpdate = true;
   }
   else
   {
      newSL = currentPrice + Inp_Trail_Distance * point;
      
      if((newSL < currentSL || currentSL == 0) && (currentSL - newSL) >= Inp_Trail_Step * point)
         shouldUpdate = true;
   }
   
   if(shouldUpdate)
   {
      if(g_TradeEngine.UpdateTrailingStop(newSL))
      {
         g_Stats.LogDebug(StringFormat("Trailing Stop atualizado para %.5f", newSL));
      }
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
   
   //--- Atualizar contadores de risco
   if(lastProfit < 0)
      g_RiskManager.RegisterLoss();
   else
      g_RiskManager.RegisterWin();
   
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
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == Inp_MagicNumber &&
            PositionGetString(POSITION_SYMBOL) == Symbol())
         {
            if(g_TradeEngine.ClosePosition())
            {
               g_Stats.LogNormal(StringFormat("Posição fechada - Razão: %s", reason));
            }
         }
      }
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
      g_RiskManager.ResetDailyStats();
      g_Stats.ResetDailyStats();
      g_todayTrades = 0;
      
      lastResetDay = today;
      g_Stats.LogNormal("Reset diário executado");
   }
}
//+------------------------------------------------------------------+

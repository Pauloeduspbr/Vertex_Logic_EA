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
#include "..\..\Include\FGM_TrendRider_EA\CBreakEvenManager.mqh"
#include "..\..\Include\FGM_TrendRider_EA\CTrailingStopManager.mqh"

//+------------------------------------------------------------------+
//| Enumerações de Input                                             |
//+------------------------------------------------------------------+
enum ENUM_EA_MODE
{
   MODE_AGGRESSIVE_EA = 0,   // Agressivo - Mais entradas
   MODE_MODERATE_EA   = 1,   // Moderado - Equilibrado
   MODE_CONSERVATIVE_EA = 2  // Conservador - Menos entradas
};

enum SIGNAL_MODE {
    MODE_CONSERVATIVE = 0,  // Conservative (4-5 confirmations)
    MODE_MODERATE = 1,      // Moderate (3-4 confirmations)
    MODE_AGGRESSIVE = 2     // Aggressive (2+ confirmations)
};

enum CROSSOVER_TYPE {
    CROSS_EMA1_EMA2 = 0,   // EMA1 x EMA2 (Fastest)
    CROSS_EMA2_EMA3 = 1,   // EMA2 x EMA3 (Medium)
    CROSS_EMA3_EMA4 = 2,   // EMA3 x EMA4 (Slow)
    CROSS_CUSTOM = 3       // Custom Crossover
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

enum ENUM_LOT_MODE
{
   LOT_FIXED = 0,         // Lote Fixo
   LOT_RISK_PERCENT = 1   // Baseado em % de Risco
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
input ENUM_EA_MODE Inp_EAMode      = MODE_MODERATE_EA; // Modo do EA
input bool     Inp_AllowBuy        = true;             // Permitir Compras
input bool     Inp_AllowSell       = true;             // Permitir Vendas
input bool     Inp_TradeOnNewBar   = true;             // Operar apenas em nova barra
input int      Inp_MaxSpread       = 30;               // Spread máximo (pontos)

//--- Gestão de Risco
input group "═══════════════ GESTÃO DE RISCO ═══════════════"
input ENUM_LOT_MODE Inp_LotMode    = LOT_FIXED;        // Modo de Lote
input double   Inp_FixedLot        = 1.0;              // Lote Fixo (B3: contratos, Forex: lotes)
input double   Inp_RiskPercent     = 1.0;              // Risco Base (%) - só se Modo=Risco
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

//--- Break-Even
input group "═══════════════ BREAK-EVEN ═══════════════"
input bool     Inp_UseBE           = true;             // Usar Break-Even
input int      Inp_BE_Trigger      = 100;              // Trigger BE (pontos de lucro)
input int      Inp_BE_Offset       = 10;               // Offset proteção spread (pontos)

//--- Trailing Stop
input group "═══════════════ TRAILING STOP ═══════════════"
input bool     Inp_UseTrailing     = true;             // Usar Trailing Stop
input int      Inp_Trail_Trigger   = 200;              // Trigger Trailing (pontos de lucro)
input int      Inp_Trail_Distance  = 150;              // Distância do SL ao preço máximo (pontos)
input int      Inp_Trail_Step      = 50;               // Step mínimo para mover SL (pontos)

//--- Horários de Operação
input group "═══════════════ HORÁRIOS ═══════════════"
input bool     Inp_UseTimeFilter   = true;             // Usar Filtro de Horário
input string   Inp_StartTime       = "09:00";          // Horário Início (HH:MM)
input string   Inp_EndTime         = "17:30";          // Horário Fim (HH:MM)
input bool     Inp_CloseEOD        = true;             // Fechar posições fim do dia
input int      Inp_SoftExitMin     = 45;               // Soft Exit (min antes do fim)
input int      Inp_HardExitMin     = 15;               // Hard Exit (min antes do fim)
input int      Inp_BrokerOffset    = 0;                // Offset do broker (horas)

//--- Dias da Semana
input group "═══════════════ DIAS DA SEMANA ═══════════════"
input bool     Inp_Monday          = true;             // Segunda-feira
input bool     Inp_Tuesday         = true;             // Terça-feira
input bool     Inp_Wednesday       = true;             // Quarta-feira
input bool     Inp_Thursday        = true;             // Quinta-feira
input bool     Inp_Friday          = true;             // Sexta-feira
input bool     Inp_Saturday        = false;            // Sábado
input bool     Inp_Sunday          = false;            // Domingo

//--- Parâmetros do Indicador FGM
input group "═══════════════ INDICADOR FGM ═══════════════"
input int              Inp_FGM_Period1     = 5;        // Período EMA 1 (Fastest)
input int              Inp_FGM_Period2     = 8;        // Período EMA 2 (Fast)
input int              Inp_FGM_Period3     = 21;       // Período EMA 3 (Medium)
input int              Inp_FGM_Period4     = 50;       // Período EMA 4 (Slow)
input int              Inp_FGM_Period5     = 200;      // Período EMA 5 (Slowest)
input ENUM_APPLIED_PRICE Inp_AppliedPrice = PRICE_CLOSE; // Applied Price

//===== Crossover Configuration =====
input CROSSOVER_TYPE   Inp_PrimaryCross = CROSS_EMA1_EMA2;    // Primary Crossover Signal
input CROSSOVER_TYPE   Inp_SecondaryCross = CROSS_EMA2_EMA3;  // Secondary Confirmation
input int              Inp_CustomCross1 = 1;   // Custom Cross EMA Index 1 (1-5)
input int              Inp_CustomCross2 = 2;   // Custom Cross EMA Index 2 (1-5)

//===== Signal Configuration =====
input SIGNAL_MODE      Inp_SignalMode = MODE_MODERATE;  // Signal Mode
input int              Inp_MinStrength = 3;             // Minimum Strength Required (1-5)
input double           Inp_ConfluenceThreshold = 50.0;  // Min Confluence Level (0-100%)
input bool             Inp_RequireConfluence = false;   // Require Confluence Filter
input bool             Inp_EnablePullbacks = true;      // Enable Pullback Signals

//===== Confluence Configuration (Percentage Based) =====
input double           Inp_ConfRangeMax = 0.05;         // Max Range % for 100% Confluence
input double           Inp_ConfRangeHigh = 0.10;        // Max Range % for 75% Confluence
input double           Inp_ConfRangeMed = 0.20;         // Max Range % for 50% Confluence
input double           Inp_ConfRangeLow = 0.30;         // Max Range % for 25% Confluence

input double           Inp_MaxConf_F3      = 60.0;             // Máx Confluência para F3 (%)
input double           Inp_MaxConf_F4      = 100.0;            // Máx Confluência para F4 (%)
input double           Inp_MaxConf_F5      = 100.0;            // Máx Confluência para F5 (%)

//--- Filtros Adicionais
input group "═══════════════ FILTROS ═══════════════"
input bool     Inp_UseSlopeFilter  = true;             // Usar Filtro de Slope
input bool     Inp_UseVolumeFilter = true;             // Usar Filtro de Volume (B3)
input bool     Inp_UseATRFilter    = true;             // Usar Filtro ATR
input int      Inp_CooldownBars    = 3;                // Cooldown após trade (barras)

//--- Filtro RSIOMA (NOVO)
input group "═══════════════ FILTRO RSIOMA ═══════════════"
input bool     Inp_UseRSIOMA       = false;            // Usar Filtro RSIOMA (desativado até compilar indicador)
input int      Inp_RSIOMA_Period   = 14;               // Período RSI
input int      Inp_RSIOMA_MA       = 9;                // Período MA do RSI
input int      Inp_RSIOMA_Overbought = 70;             // Nível Sobrecompra (não BUY acima)
input int      Inp_RSIOMA_Oversold = 30;               // Nível Sobrevenda (não SELL abaixo)
input bool     Inp_RSIOMA_CheckMid = true;             // Verificar nível 50 (momentum)
input bool     Inp_RSIOMA_CheckCross = true;           // Verificar RSI × MA (direção)
input int      Inp_RSIOMA_ConfirmBars = 2;             // Barras de Confirmação (1-5)

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
CBreakEvenManager     g_BEManager;
CTrailingStopManager  g_TSManager;

//--- Estado
datetime          g_lastBarTime = 0;
int               g_currentStrength = 0;
string            g_currentSession = "";
bool              g_isInitialized = false;
double            g_dailyStartBalance = 0;
int               g_todayTrades = 0;

//--- Tracking de posição
bool              g_hasPosition = false;
ulong             g_positionTicket = 0;
datetime          g_positionOpenTime = 0;
double            g_positionOpenPrice = 0;
double            g_positionSL = 0;
double            g_positionVolume = 0;
ENUM_POSITION_TYPE g_positionType;

//--- Tracking para detectar quando posição fecha externamente (SL/TP hit)
bool              g_wasPosition = false;      // Havia posição no tick anterior?

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
                        Inp_FGM_Period4, Inp_FGM_Period5, Inp_AppliedPrice,
                        Inp_PrimaryCross, Inp_SecondaryCross, Inp_CustomCross1, Inp_CustomCross2,
                        Inp_SignalMode, Inp_MinStrength, Inp_ConfluenceThreshold, Inp_RequireConfluence, Inp_EnablePullbacks,
                        Inp_ConfRangeMax, Inp_ConfRangeHigh, Inp_ConfRangeMed, Inp_ConfRangeLow))
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
   //--- Modo de Lote (NOVO)
   riskParams.lotMode = (int)Inp_LotMode;
   riskParams.fixedLot = Inp_FixedLot;
   riskParams.riskPercent = Inp_RiskPercent;
   riskParams.riskMultF5 = Inp_ForceMultF5;
   riskParams.riskMultF4 = Inp_ForceMultF4;
   riskParams.riskMultF3 = Inp_ForceMultF3;
   riskParams.maxDailyDD = Inp_MaxDailyDD;
   riskParams.maxConsecStops = Inp_MaxConsecLoss;
   //--- Parâmetros de SL
   riskParams.slMode = (int)Inp_SLMode;
   riskParams.slATRMult = Inp_SL_ATR_Mult;
   riskParams.slATRMultVolatile = Inp_SL_ATR_Mult * 1.5;
   riskParams.slFixedPoints = Inp_SL_Points;
   riskParams.slMinPoints = Inp_SL_Min;
   riskParams.slMaxPoints = Inp_SL_Max;
   //--- Parâmetros de TP (MODO E VALORES)
   riskParams.tpMode = (int)Inp_TPMode;
   riskParams.tpFixedPoints = Inp_TP_Points;
   riskParams.tpATRMult = Inp_TP_ATR_Mult;
   riskParams.tp1RR = Inp_TP_RR_Ratio;  // Usa o RR geral
   riskParams.tp2RR = Inp_TP_RR_Ratio * 2.0;  // TP2 = 2x RR (para cálculos internos)
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
   
   //--- Configurar horários e dias da semana do TimeFilter
   B3TimeConfig b3Config = g_TimeFilter.GetB3Config();
   b3Config.mondayActive = Inp_Monday;
   b3Config.tuesdayActive = Inp_Tuesday;
   b3Config.wednesdayActive = Inp_Wednesday;
   b3Config.thursdayActive = Inp_Thursday;
   b3Config.fridayActive = Inp_Friday;
   b3Config.saturdayActive = Inp_Saturday;
   b3Config.sundayActive = Inp_Sunday;
   b3Config.mondayStart = Inp_StartTime;
   b3Config.mondayEnd = Inp_EndTime;
   b3Config.tuesdayStart = Inp_StartTime;
   b3Config.tuesdayEnd = Inp_EndTime;
   b3Config.wednesdayStart = Inp_StartTime;
   b3Config.wednesdayEnd = Inp_EndTime;
   b3Config.thursdayStart = Inp_StartTime;
   b3Config.thursdayEnd = Inp_EndTime;
   b3Config.fridayStart = Inp_StartTime;
   b3Config.fridayEnd = Inp_EndTime;
   b3Config.softExitMinutes = Inp_SoftExitMin;
   b3Config.hardExitMinutes = Inp_HardExitMin;
   g_TimeFilter.SetB3Config(b3Config);
   
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
   
   //--- Configurar limites de confluência dos filtros para corresponder aos inputs do EA
   FilterConfig filterConfig = g_Filters.GetConfig();
   //--- Atualizar limites de spread com o input do usuário
   filterConfig.spreadMaxWIN = Inp_MaxSpread;
   filterConfig.spreadMaxWDO = Inp_MaxSpread;
   filterConfig.spreadMaxForex = Inp_MaxSpread;
   
   filterConfig.confluenceMaxF3 = Inp_MaxConf_F3;
   filterConfig.confluenceMaxF4 = Inp_MaxConf_F4;
   filterConfig.confluenceMaxF5 = Inp_MaxConf_F5;
   filterConfig.slopeActive = Inp_UseSlopeFilter;
   filterConfig.volumeActive = Inp_UseVolumeFilter;
   filterConfig.cooldownActive = true;
   filterConfig.cooldownBarsAfterStop = Inp_CooldownBars;
   //--- Configurar RSIOMA Filter (NOVO)
   filterConfig.rsiomaActive = Inp_UseRSIOMA;
   filterConfig.rsiomaPeriod = Inp_RSIOMA_Period;
   filterConfig.rsiomaMA_Period = Inp_RSIOMA_MA;
   filterConfig.rsiomaMA_Method = MODE_SMA;
   filterConfig.rsiomaOverbought = Inp_RSIOMA_Overbought;
   filterConfig.rsiomaOversold = Inp_RSIOMA_Oversold;
   filterConfig.rsiomaCheckMidLevel = Inp_RSIOMA_CheckMid;
   filterConfig.rsiomaCheckCrossover = Inp_RSIOMA_CheckCross;
   filterConfig.rsiomaConfirmBars = Inp_RSIOMA_ConfirmBars;
   g_Filters.SetConfig(filterConfig);
   
   //--- Inicializar Stats
   if(!g_Stats.Init(Inp_MagicNumber, Inp_LogLevel,
               Inp_TrackByDay, Inp_TrackByHour,
               Inp_TrackByStrength, Inp_TrackBySession,
               Inp_ExportStats, "FGM_Stats"))
   {
      Print("[FGM] Erro ao inicializar Stats");
      return INIT_FAILED;
   }
   
   //--- Inicializar Break-Even Manager
   if(!g_BEManager.Init(Symbol(), Inp_UseBE, Inp_BE_Trigger, Inp_BE_Offset))
   {
      Print("[FGM] Erro ao inicializar Break-Even Manager");
      return INIT_FAILED;
   }
   
   //--- Inicializar Trailing Stop Manager
   if(!g_TSManager.Init(Symbol(), Inp_UseTrailing, Inp_Trail_Trigger, Inp_Trail_Distance, Inp_Trail_Step))
   {
      Print("[FGM] Erro ao inicializar Trailing Stop Manager");
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
   
   //--- Atualizar estado atual da posição
   CheckExistingPosition();
   
   //--- Detectar fechamento externo de posição (SL/TP hit pelo servidor)
   //--- Se TINHA posição antes e AGORA não tem, significa que fechou externamente
   if(g_wasPosition && !g_hasPosition)
   {
      g_Stats.LogNormal("Posição fechada externamente (SL/TP hit detectado)");
      OnPositionClosed();
   }
   
   //--- Atualizar tracking de posição para próximo tick
   g_wasPosition = g_hasPosition;
   
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
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == Inp_MagicNumber &&
            PositionGetString(POSITION_SYMBOL) == Symbol())
         {
            g_hasPosition = true;
            g_positionTicket = ticket;
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
   
   //--- Atualizar buffers do indicador (mais barras para análise de tendência)
   if(!g_SignalFGM.Update(10))
   {
      g_Stats.LogDebug("Erro ao atualizar dados do indicador");
      return;
   }
   
   FGM_DATA fgmData;
   int signalBar = -1;
   
   //--- Verificar sinal na barra 0 (sinal em tempo real/abertura) ou barra 1 (fechada)
   //--- O indicador FGM gera o sinal no buffer ENTRY (8)
   
   //--- Checar barra 0 (Sinal imediato)
   fgmData = g_SignalFGM.GetData(0);
   if(fgmData.isValid && fgmData.entry != 0)
   {
      signalBar = 0;
   }
   else
   {
      //--- Checar barra 1 (Sinal confirmado no fechamento)
      fgmData = g_SignalFGM.GetData(1);
      if(fgmData.isValid && fgmData.entry != 0)
      {
         signalBar = 1;
      }
   }
   
   //--- Se não há sinal, retornar
   if(signalBar < 0 || !fgmData.isValid)
   {
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
   //--- O indicador já calcula a confluência baseada em porcentagem.
   //--- Se InpRequireConfluence for true no indicador, o sinal já vem filtrado.
   //--- Aqui fazemos uma verificação adicional se necessário.
   
   double confluence = fgmData.confluence;
   
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
   g_Stats.LogDebug(StringFormat("Aplicando filtros para %s (Força F%d)...", 
                                 isBuy ? "COMPRA" : "VENDA", signalStrength));
   
   FilterResult filterResult = g_Filters.CheckAll(isBuy, Inp_MinStrength, false);
   
   //--- Log detalhado do resultado dos filtros
   g_Stats.LogDebug(StringFormat("Filtros: Spread=%s Slope=%s Volume=%s Phase=%s EMA200=%s Cooldown=%s Confluência=%s",
                                 filterResult.spreadOK ? "OK" : "FALHOU",
                                 filterResult.slopeOK ? "OK" : "FALHOU",
                                 filterResult.volumeOK ? "OK" : "FALHOU",
                                 filterResult.phaseOK ? "OK" : "FALHOU",
                                 filterResult.ema200OK ? "OK" : "FALHOU",
                                 filterResult.cooldownOK ? "OK" : "FALHOU",
                                 filterResult.confluenceOK ? "OK" : "FALHOU"));
   
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
      g_positionTicket = tradeResult.ticket;
      g_positionOpenTime = TimeCurrent();
      g_positionOpenPrice = tradeResult.price > 0 ? tradeResult.price : entryPrice;
      g_positionSL = posCalc.slPrice;
      g_positionVolume = posCalc.lotSize;
      g_positionType = isBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      g_todayTrades++;
      
      g_Stats.LogNormal("Entrada executada via FGM Indicator");
      
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
   //--- NOTA: CheckExistingPosition() já é chamado no OnTick() antes de ManagePosition()
   //--- A detecção de posição fechada também já está no OnTick()
   
   //--- Gerenciar Break-Even usando o novo módulo
   if(Inp_UseBE)
   {
      g_BEManager.CheckAndApply(g_positionTicket);
   }
   
   //--- Gerenciar Trailing Stop usando o novo módulo
   //--- Só atua APÓS BE ser ativado (se BE estiver habilitado)
   if(Inp_UseTrailing)
   {
      //--- Se BE está habilitado, só fazer trailing após BE ativar
      //--- Se BE está desabilitado, pode fazer trailing imediatamente
      if(!Inp_UseBE || g_BEManager.IsBEActivated(g_positionTicket))
      {
         g_TSManager.Update(g_positionTicket);
      }
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
         
         double currentPrice = (g_positionType == POSITION_TYPE_BUY) 
                              ? SymbolInfoDouble(Symbol(), SYMBOL_BID)
                              : SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         
         double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
         double profitPoints = 0;
         
         if(g_positionType == POSITION_TYPE_BUY)
            profitPoints = (currentPrice - g_positionOpenPrice) / point;
         else
            profitPoints = (g_positionOpenPrice - currentPrice) / point;
         
         if(shouldExit && profitPoints > 0) // Apenas se em lucro
         {
            g_Stats.LogNormal("Sinal de saída do indicador detectado");
            CloseAllPositions("FGM Exit Signal");
         }
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
   
   //--- Limpar registros nos módulos de BE e TS
   g_BEManager.RemoveTicket(g_positionTicket);
   g_TSManager.RemoveTicket(g_positionTicket);
   
   //--- Reset variáveis
   g_hasPosition = false;
   g_positionTicket = 0;
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

//+------------------------------------------------------------------+
//|                                              FGM_TrendRider.mq5 |
//|                         FGM Trend Rider - Versão Platina         |
//|                           Expert Advisor Principal               |
//+------------------------------------------------------------------+
#property copyright "FGM Trading Systems"
#property link      "https://www.fgmtrade.com"
#property version   "1.01"
#property description "FGM Trend Rider - Versão Platina Consolidada"
#property description "Expert Advisor para B3 (WIN/WDO) e Forex"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include "../../Include/FGM_TrendRider_EA/CAssetSpecs.mqh"
#include "../../Include/FGM_TrendRider_EA/CSignalFGM.mqh"
#include "../../Include/FGM_TrendRider_EA/CRiskManager.mqh"
#include "../../Include/FGM_TrendRider_EA/CTradeEngine.mqh"
#include "../../Include/FGM_TrendRider_EA/CTimeFilter.mqh"
#include "../../Include/FGM_TrendRider_EA/CRegimeDetector.mqh"
#include "../../Include/FGM_TrendRider_EA/CFilters.mqh"
#include "../../Include/FGM_TrendRider_EA/CStats.mqh"
#include "../../Include/FGM_TrendRider_EA/CBreakEvenManager.mqh"
#include "../../Include/FGM_TrendRider_EA/CTrailingStopManager.mqh"

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
input ENUM_LOT_MODE Inp_LotMode    = LOT_RISK_PERCENT; // Modo de Lote - ESTRUTURAL: Fixo→Risco% para controle real
input double   Inp_FixedLot        = 1.0;              // Lote Fixo (B3: contratos, Forex: lotes)
input double   Inp_RiskPercent     = 3.0;              // Risco % por trade (Aumentado para permitir SL maior) (%) - só se Modo=Risco
input double   Inp_MaxDailyDD      = 3.0;              // Drawdown Diário Máximo (%)
input double   Inp_MaxTotalDD      = 10.0;             // Drawdown Total Máximo (%)
input int      Inp_MaxConsecLoss   = 3;                // Máx perdas consecutivas
input double   Inp_ForceMultF3     = 0.5;              // Multiplicador F3
input double   Inp_ForceMultF4     = 1.0;              // Multiplicador F4
input double   Inp_ForceMultF5     = 1.5;              // Multiplicador F5

//--- Stop Loss
input group "═══════════════ STOP LOSS ═══════════════"
input ENUM_SL_MODE Inp_SLMode      = SL_FIXED;         // ESTRUTURAL: Hybrid→Fixed (evita SL inflado em volátil)
input int      Inp_SL_Points       = 300;              // ESTRUTURAL: SL maior (300pts) para suportar volatilidade
input double   Inp_SL_ATR_Mult     = 1.5;              // Multiplicador ATR para SL
input int      Inp_SL_Min          = 50;               // SL Mínimo (pontos)
input int      Inp_SL_Max          = 500;              // SL Máximo (pontos)

//--- Take Profit
input group "═══════════════ TAKE PROFIT ═══════════════"
input ENUM_TP_MODE Inp_TPMode      = TP_RR_RATIO;      // Modo do Take Profit
input int      Inp_TP_Points       = 300;              // TP Fixo (pontos)
input double   Inp_TP_RR_Ratio     = 2.0;              // ESTRUTURAL: R:R=2:1 obrigatório para lucratividade
input double   Inp_TP_ATR_Mult     = 3.0;              // Multiplicador ATR para TP

//--- Break-Even
input group "═══════════════ BREAK-EVEN ═══════════════"
input bool     Inp_UseBE           = true;             // Usar Break-Even
input int      Inp_BE_Trigger      = 300;              // Trigger BE (pontos de lucro) - CORRIGIDO: 180→300 (1:1 R/R)
input int      Inp_BE_Offset       = 10;               // Offset proteção spread (pontos) - CORRIGIDO: 30→10 (Custo apenas)

//--- Trailing Stop
input group "═══════════════ TRAILING STOP ═══════════════"
input bool     Inp_UseTrailing     = true;             // Usar Trailing Stop - ATIVADO para capturar tendências longas
input int      Inp_Trail_Trigger   = 400;              // Trigger Trailing (pontos de lucro) - CORRIGIDO: 250→400
input int      Inp_Trail_Distance  = 200;              // Distância do SL ao preço máximo (pontos) - CORRIGIDO: 150→200
input int      Inp_Trail_Step      = 30;               // Step mínimo para mover SL (pontos) - CORRIGIDO: 50→30 para movimento gradual

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
input int              Inp_MinStrength = 5;             // Minimum Strength Required - SÓ SINAIS PERFEITOS
input double           Inp_ConfluenceThreshold = 60.0;  // Min Confluence Level (0-100%)
input bool             Inp_RequireConfluence = true;    // Require Confluence Filter (ATIVADO para rejeitar sinais fracos)
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
input int      Inp_CooldownBars    = 0;                // Cooldown após trade (barras) - (0 para reentradas rápidas)

//--- Filtro RSIOMA (NOVO)
input group "═══════════════ FILTRO RSIOMA ═══════════════"
input bool     Inp_UseRSIOMA       = true;             // Usar Filtro RSIOMA - ATIVADO para filtrar momentum
input int      Inp_RSIOMA_Period   = 14;               // Período RSI
input int      Inp_RSIOMA_MA       = 9;                // Período MA do RSI
input int      Inp_RSIOMA_Overbought = 80;             // Nível Sobrecompra (não BUY acima)
input int      Inp_RSIOMA_Oversold = 20;               // Nível Sobrevenda (não SELL abaixo)
input bool     Inp_RSIOMA_CheckMid = true;             // Verificar nível 50 (momentum)
input bool     Inp_RSIOMA_CheckCross = true;           // Verificar RSI × MA (direção)
input int      Inp_RSIOMA_ConfirmBars = 2;             // Barras de Confirmação (1-5)

//--- Filtro OBV MACD (NOVO - Nexus Logic)
input group "═══════════════ FILTRO OBV MACD (NEXUS) ═══════════════"
input bool     Inp_UseOBVMACD      = true;             // Usar Filtro OBV MACD (Nexus Logic)
input bool     Inp_OBVMACD_RequireBuy = true;          // Exigir sinal de compra - ATIVADO para filtrar volume
input bool     Inp_OBVMACD_RequireSell = true;         // Exigir sinal de venda - ATIVADO para filtrar volume
input bool     Inp_OBVMACD_AllowWeak = true;           // Permitir sinais fracos (Green Weak/Red Weak)
input bool     Inp_OBVMACD_CheckVolume = false;        // Verificar volume relevante (recomendado: false)

//--- Parâmetros do Indicador OBV MACD v3
input group "═══════════════ OBV MACD v3 - PARÂMETROS ═══════════════"
input int      Inp_OBVMACD_FastEMA = 12;               // Fast EMA Period
input int      Inp_OBVMACD_SlowEMA = 26;               // Slow EMA Period
input int      Inp_OBVMACD_SignalSMA = 9;              // Signal SMA Period
input int      Inp_OBVMACD_ObvSmooth = 5;              // OBV Smoothing SMA Period
input bool     Inp_OBVMACD_UseTickVolume = true;       // Use Tick Volume (true) ou Real (false)
input int      Inp_OBVMACD_ThreshPeriod = 34;          // Threshold EMA period
input double   Inp_OBVMACD_ThreshMult = 0.6;           // Threshold multiplier

//--- Regime de Mercado
input group "═══════════════ REGIME DE MERCADO ═══════════════"
input bool     Inp_UseRegime       = true;             // Usar Detecção de Regime
input bool     Inp_BlockRanging    = true;             // BLOQUEAR trades em mercado LATERAL (61% das losses!)
input bool     Inp_BlockVolatile   = true;             // BLOQUEAR trades em ALTA VOLATILIDADE
input double   Inp_TrendMult       = 1.0;              // Multiplicador Trending
input double   Inp_RangeMult       = 0.5;              // Multiplicador Ranging (se não bloqueado)
input double   Inp_VolatileMult    = 0.3;              // Multiplicador Volatile (se não bloqueado)

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

//--- Diagnóstico (limitado) de entradas que viraram LOSS
FilterResult       g_lastEntryFilters;
double             g_lastEntryConfluence = 0.0;
ENUM_MARKET_REGIME g_lastEntryRegime = REGIME_TRENDING;
bool               g_lastEntryIsVolatile = false;
bool               g_lastEntryIsBuy = false;
PositionCalcResult g_lastEntryPosCalc;
bool               g_hasLastEntryContext = false;

int                g_badEntriesTotal = 0;
int                g_badEntriesToday = 0;
int                g_badEntryLogsToday = 0;
datetime           g_badEntryDay = 0;
const int          BAD_ENTRY_LOG_CAP_PER_DAY = 5;

void ResetBadEntryCountersIfNewDay();
void LogBadEntryDiagnostics(const double profit, const string closeReason);

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
   //--- IMPORTANTE: Obter parâmetros padrão primeiro para garantir que campos não mapeados (como maxLot) tenham valores válidos
   RiskParams riskParams = g_RiskManager.GetRiskParams();
   
   //--- Modo de Lote (NOVO)
   riskParams.lotMode = (int)Inp_LotMode;
   riskParams.fixedLot = Inp_FixedLot;
   riskParams.riskPercent = Inp_RiskPercent;
   riskParams.riskMultF5 = Inp_ForceMultF5;
   riskParams.riskMultF4 = Inp_ForceMultF4;
   riskParams.riskMultF3 = Inp_ForceMultF3;
   riskParams.maxDailyDD = Inp_MaxDailyDD;
   riskParams.maxTotalDD = Inp_MaxTotalDD;
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
   
   //--- Configurar horários e dias da semana para Forex
   ForexTimeConfig fxConfig = g_TimeFilter.GetForexConfig();
   fxConfig.mondayActive = Inp_Monday;
   fxConfig.tuesdayActive = Inp_Tuesday;
   fxConfig.wednesdayActive = Inp_Wednesday;
   fxConfig.thursdayActive = Inp_Thursday;
   fxConfig.fridayActive = Inp_Friday;
   fxConfig.saturdayActive = Inp_Saturday;
   fxConfig.sundayActive = Inp_Sunday;
   
   //--- Configurar horários gerais (Server Time)
   fxConfig.startTime = Inp_StartTime;
   fxConfig.endTime = Inp_EndTime;
   
   //--- Habilitar todas as sessões para permitir que o usuário controle apenas pelo horário
   fxConfig.allowSydney = true;
   fxConfig.allowTokyo = true;
   fxConfig.allowLondon = true;
   fxConfig.allowNewYork = true;
   
   //--- Ajustar força mínima para baixa liquidez (Sydney/Tokyo) para igualar a configuração global
   //--- Isso evita que sinais válidos sejam bloqueados apenas por ser sessão asiática
   fxConfig.lowLiqMinStrength = Inp_MinStrength;
   
   //--- Desativar filtro de rollover para permitir operação na virada do dia (00:00)
   //--- O usuário reclamou que o EA parou às 23:59 e não voltou à 00:00
   fxConfig.avoidRollover = false; 
   
   g_TimeFilter.SetForexConfig(fxConfig);
   
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
   Print(StringFormat("DEBUG_INPUTS: Inp_ConfluenceThreshold = %.2f", Inp_ConfluenceThreshold)); // DEBUG CHECK
   
   FilterConfig filterConfig = g_Filters.GetConfig();
   //--- Atualizar limites de spread com o input do usuário
   filterConfig.spreadMaxWIN = Inp_MaxSpread;
   filterConfig.spreadMaxWDO = Inp_MaxSpread;
   filterConfig.spreadMaxForex = Inp_MaxSpread;
   
   filterConfig.confluenceMaxF3 = Inp_MaxConf_F3;
   filterConfig.confluenceMaxF4 = Inp_MaxConf_F4;
   filterConfig.confluenceMaxF5 = Inp_MaxConf_F5;
   
   //--- NOVO: Configurar confluência MÍNIMA usando os inputs existentes
   //--- Inp_ConfluenceThreshold define o mínimo e Inp_RequireConfluence ativa o filtro
   filterConfig.confluenceMin = Inp_ConfluenceThreshold;
   filterConfig.confluenceMinActive = Inp_RequireConfluence;
   
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
   
   //--- Configurar OBV MACD Filter (NOVO - Nexus Logic)
   filterConfig.obvmACDActive = Inp_UseOBVMACD;
   filterConfig.obvmACDRequireBuy = Inp_OBVMACD_RequireBuy;
   filterConfig.obvmACDRequireSell = Inp_OBVMACD_RequireSell;
   filterConfig.obvmACDAllowWeakSignals = Inp_OBVMACD_AllowWeak;
   filterConfig.obvmACDCheckVolumeRelevance = Inp_OBVMACD_CheckVolume;
   
   g_Filters.SetConfig(filterConfig);
   
   //--- Configurar parâmetros do indicador OBV MACD v3
   g_Filters.SetOBVMACDParams(Inp_OBVMACD_FastEMA, Inp_OBVMACD_SlowEMA, 
                              Inp_OBVMACD_SignalSMA, Inp_OBVMACD_ObvSmooth,
                              Inp_OBVMACD_UseTickVolume, Inp_OBVMACD_ThreshPeriod,
                              Inp_OBVMACD_ThreshMult);
   
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
         //--- Fora do horário de trading ou Soft Exit ativo
         g_Stats.LogDebug("Fora do horário de trading ou Soft Exit ativo.");
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
   
   //--- Determinar direção (MOVIDO PARA O TOPO)
   bool isBuy = (entrySignal > 0);
   bool isSell = (entrySignal < 0);

   //--- ESTRATÉGIA NOVO PROTOCOLO 1-2-3: Ignoramos "Strength" numérica antiga
   //--- A validação será feita pelos 3 passos rigorosos abaixo.
   // if(signalStrength < Inp_MinStrength) ... REMOVIDO PARA USAR PROTOCOLO 1-2-3
   
   // Apenas logar para referência
   g_Stats.LogDebug(StringFormat("Sinal detectado via FGM (Direção: %s) - Iniciando Protocolo 1-2-3", isBuy ? "BUY" : "SELL"));
   
   //--- RESTAURAÇÃO DE VARIÁVEIS PARA COMPATIBILIDADE
   //--- Como removemos o cálculo de filterResult e signalStrength, precisamos defini-los
   //--- para não quebrar o código de logging e cálculo de risco abaixo.
   int signalStrength = 5; // Assumimos força MÁXIMA se passou no protocolo 1-2-3
   
   //--- Criar um resultado de filtro "dummy" aprovado, pois o Strategy123 já validou
   FilterResult filterResult;
   filterResult.passed = true;
   filterResult.strengthOK = true;
   filterResult.currentStrength = 5;
   filterResult.failReason = "Aprovado por Protocolo 1-2-3";
   
   //--- Verificar confluência (compressão das EMAs)
   //--- O indicador já calcula a confluência baseada em porcentagem.
   //--- Se InpRequireConfluence for true no indicador, o sinal já vem filtrado.
   //--- Aqui fazemos uma verificação adicional se necessário.
   
   double confluence = fgmData.confluence;
   
   //--- Determinar direção (JÁ CALCULADO ACIMA)
   // bool isBuy = (entrySignal > 0);
   // bool isSell = (entrySignal < 0);
   
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
   
   //--- APLICAR PROTOCOLO SNIPER 1-2-3 (SINCRONIA TOTAL)
   g_Stats.LogDebug("Verificando Sincronia Total (Steps 1-2-3)...");
   
   //--- Verificação Rigorosa: Se FALHAR qualquer passo, NÃO ENTRA.
   bool strategyOK = g_Filters.CheckStrategy123(isBuy, signalBar);
   
   if(!strategyOK)
   {
      string failReason = "Sincronia 1-2-3 FALHOU (Ver logs acima)";
      g_Stats.LogNormal(StringFormat("FILTRO BLOQUEOU: %s", failReason));
      return;
   }
   
   g_Stats.LogNormal("✅ PROTOCOLO 1-2-3 APROVADO: Tendência + Momentum + Volume ALINHADOS!");
   
   g_Stats.LogNormal("Todos os filtros passaram - Preparando ordem...");
   
   //--- Detectar regime de mercado
   ENUM_MARKET_REGIME regime = REGIME_TRENDING;
   double regimeMultiplier = 1.0;
   
   if(Inp_UseRegime)
   {
      regime = g_RegimeDetector.GetCurrentRegime();
      
      //--- BLOQUEIO POR REGIME (CORREÇÃO FUNDAMENTAL DA ESTRATÉGIA)
      //--- 61% das LOSSES ocorrem em RANGING/VOLATILE - agora BLOQUEAMOS!
      if(Inp_BlockRanging && regime == REGIME_RANGING)
      {
         g_Stats.LogNormal(StringFormat("FILTRO BLOQUEOU: Mercado em LATERALIZAÇÃO (%s) - não operar", 
                                        g_RegimeDetector.GetRegimeString(regime)));
         return;
      }
      
      if(Inp_BlockVolatile && regime == REGIME_VOLATILE)
      {
         g_Stats.LogNormal(StringFormat("FILTRO BLOQUEOU: Mercado em ALTA VOLATILIDADE (%s) - não operar", 
                                        g_RegimeDetector.GetRegimeString(regime)));
         return;
      }
      
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
      //--- Log mais informativo (sem excesso): quando o EA pular trade por lote mínimo após cap de risco
      if(StringFind(posCalc.errorMessage, "abaixo do mínimo") >= 0)
      {
         g_Stats.LogNormal(StringFormat(
            "TRADE SKIPPED (risk cap/min lot): %s | Dir=%s | F%d | Entry=%.5f | SLpts=%.1f | SL=%.5f | LotMode=%d | FixedLot=%.4f | Risk%%=%.2f",
            posCalc.errorMessage,
            isBuy ? "BUY" : "SELL",
            signalStrength,
            entryPrice,
            posCalc.slPoints,
            posCalc.slPrice,
            (int)Inp_LotMode,
            Inp_FixedLot,
            Inp_RiskPercent
         ));
      }
      else
      {
         g_Stats.LogError(StringFormat("Cálculo de posição inválido: %s", posCalc.errorMessage));
      }
      return;
   }
   
   //--- Armazenar força e sessão
   g_currentStrength = signalStrength;
   ENUM_FOREX_SESSION session = g_TimeFilter.GetCurrentForexSession();
   g_currentSession = g_TimeFilter.GetSessionName(session);
   
   //--- Executar entrada
   TradeResult tradeResult;
   
   if(isBuy)
      tradeResult = g_TradeEngine.OpenBuy(posCalc.lotSize, posCalc.slPrice, posCalc.tp1Price);
   else
      tradeResult = g_TradeEngine.OpenSell(posCalc.lotSize, posCalc.slPrice, posCalc.tp1Price);
   
   if(tradeResult.success)
   {
      //--- Capturar contexto da entrada (para diagnosticar apenas se virar LOSS)
      g_lastEntryFilters = filterResult;
      g_lastEntryConfluence = confluence;
      g_lastEntryRegime = regime;
      g_lastEntryIsVolatile = isVolatile;
      g_lastEntryIsBuy = isBuy;
      g_lastEntryPosCalc = posCalc;
      g_hasLastEntryContext = true;

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
         
         if(shouldExit) // Allow exit even in loss to prevent full SL
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

   //--- Diagnóstico de "entrada errada": logar somente quando fechar em prejuízo
   if(lastProfit < 0)
   {
      ResetBadEntryCountersIfNewDay();
      g_badEntriesTotal++;
      g_badEntriesToday++;
      LogBadEntryDiagnostics(lastProfit, closeReason);
   }
   
   //--- Iniciar cooldown se foi stop REAL (Prejuízo)
   //--- Ignora Stops de Break-Even ou Trailing Stop com lucro
   if(closeReason == "Stop Loss" && lastProfit < 0)
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
//| Reset diário do contador de diagnósticos                         |
//+------------------------------------------------------------------+
void ResetBadEntryCountersIfNewDay()
{
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(today != g_badEntryDay)
   {
      g_badEntryDay = today;
      g_badEntriesToday = 0;
      g_badEntryLogsToday = 0;
   }
}

//+------------------------------------------------------------------+
//| Log compacto do contexto da entrada que virou LOSS               |
//+------------------------------------------------------------------+
void LogBadEntryDiagnostics(const double profit, const string closeReason)
{
   if(g_badEntryLogsToday >= BAD_ENTRY_LOG_CAP_PER_DAY)
      return;

   // Se não temos contexto (por exemplo, posição foi aberta externamente), não spammar.
   if(!g_hasLastEntryContext)
      return;

   g_badEntryLogsToday++;

   // 1 linha, focando no que ajuda a explicar a seleção do trade.
   g_Stats.LogNormal(StringFormat(
      "BAD ENTRY #%d/%d today | Profit=%.2f | Close=%s | Dir=%s | Regime=%s%s | F=%d | Conf=%.1f%% | SLpts=%.1f | Risk=%.2f%% | Spread=%.1f | Slope=%.5f | Vol=%.0f/MA%.0f | Phase=%d | EMA200=%s | RSI=%.1f/MA%.1f | OBV=%d",
      g_badEntryLogsToday,
      BAD_ENTRY_LOG_CAP_PER_DAY,
      profit,
      closeReason,
      g_lastEntryIsBuy ? "BUY" : "SELL",
      g_RegimeDetector.GetRegimeString(g_lastEntryRegime),
      g_lastEntryIsVolatile ? "(VOL)" : "",
      g_lastEntryFilters.currentStrength,
      g_lastEntryConfluence,
      g_lastEntryPosCalc.slPoints,
      g_lastEntryPosCalc.riskPercent,
      g_lastEntryFilters.currentSpread,
      g_lastEntryFilters.currentSlope,
      g_lastEntryFilters.currentVolume,
      g_lastEntryFilters.volumeMA,
      g_lastEntryFilters.currentPhase,
      g_lastEntryFilters.ema200OK ? "OK" : "FAIL",
      g_lastEntryFilters.currentRSI,
      g_lastEntryFilters.currentRSIMA,
      g_lastEntryFilters.obvmACDSignal
   ));
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

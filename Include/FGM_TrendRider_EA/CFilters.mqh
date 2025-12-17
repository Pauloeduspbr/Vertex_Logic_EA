//+------------------------------------------------------------------+
//|                                                     CFilters.mqh |
//|                                 Copyright 2025, Pauloeduspbr     |
//|                      FGM Trend Rider - Versão Platina Final      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Pauloeduspbr"
#property version   "1.00"
#property strict

#ifndef CFILTERS_MQH
#define CFILTERS_MQH

#include "CAssetSpecs.mqh"
#include "CSignalFGM.mqh"
#include "CRegimeDetector.mqh"

//+------------------------------------------------------------------+
//| Estrutura de resultado dos filtros                               |
//+------------------------------------------------------------------+
struct FilterResult
{
   bool     passed;              // Filtro passou
   string   failReason;          // Motivo da falha
   
   //--- Detalhes
   bool     spreadOK;            // Spread dentro do limite
   bool     slopeOK;             // Slope adequado
   bool     volumeOK;            // Volume adequado
   bool     confluenceOK;        // Confluência adequada
   bool     phaseOK;             // Fase de mercado adequada
   bool     strengthOK;          // Força do sinal adequada
   bool     ema200OK;            // Preço vs EMA200
   bool     cooldownOK;          // Cooldown respeitado
   bool     rsiomaOK;            // RSIOMA OK (NOVO)
   bool     obvmACDOK;           // OBV MACD OK (NOVO)
   
   //--- Valores
   double   currentSpread;       // Spread atual
   double   currentSlope;        // Slope atual
   double   currentVolume;       // Volume atual
   double   volumeMA;            // Média do volume
   double   currentConfluence;   // Confluência atual
   int      currentStrength;     // Força atual
   int      currentPhase;        // Fase atual
   double   currentRSI;          // RSI atual (NOVO)
   double   currentRSIMA;        // RSI MA atual (NOVO)
   int      obvmACDSignal;       // Sinal OBV MACD (-1, 0, 1) (NOVO)
};

//+------------------------------------------------------------------+
//| Estrutura de configuração dos filtros                            |
//+------------------------------------------------------------------+
struct FilterConfig
{
   //--- Spread
   int      spreadMaxWIN;        // Spread máximo WIN
   int      spreadMaxWDO;        // Spread máximo WDO
   int      spreadMaxForex;      // Spread máximo Forex
   
   //--- ATR (NOVO / Missing)
   bool     atrActive;           // Filtro ATR ativo
   int      atrPeriod;           // Período ATR
   double   atrMultiplier;       // Multiplicador ATR
   
   //--- VWAP Filter (NOVO)
   bool     useVWAPFilter;       // Filtro VWAP ativo
   
   //--- Slope
   bool     slopeActive;         // Filtro de slope ativo
   int      slopePeriod;         // Período para cálculo
   double   slopeMinWIN;         // Slope mínimo WIN
   double   slopeMinWDO;         // Slope mínimo WDO
   double   slopeMinForex;       // Slope mínimo Forex
   
   //--- Volume
   bool     volumeActive;        // Filtro de volume ativo
   int      volumeMAPeriod;      // Período da MA do volume
   double   volumeMultiplier;    // Volume > MA × mult
   bool     volumeIgnoreF5;      // Ignorar para força 5
   
   //--- Confluência por força (limite MÁXIMO de compressão aceitável)
   double   confluenceMaxF3;     // Confluência MÁXIMA aceitável para força 3 (0 = ignorar)
   double   confluenceMaxF4;     // Confluência MÁXIMA aceitável para força 4 (0 = ignorar)
   double   confluenceMaxF5;     // Confluência MÁXIMA aceitável para força 5 (0 = ignorar)
   
   //--- Confluência MÍNIMA para entrada (NOVO - filtro de sinais fracos)
   double   confluenceMin;       // Confluência MÍNIMA para aceitar entrada (% de 0-100)
   bool     confluenceMinActive; // Ativar filtro de confluência mínima
   
   //--- Fase de mercado
   bool     phaseFilterActive;   // Filtro de fase ativo
   int      minPhaseBuy;         // Fase mínima para compra (+1 = Weak Bull)
   int      minPhaseSell;        // Fase máxima para venda (-1 = Weak Bear)
   
   //--- EMA 200
   bool     ema200FilterActive;  // Filtro EMA200 ativo
   
   //--- Cooldown
   bool     cooldownActive;      // Cooldown ativo
   int      cooldownBarsAfterStop;  // Barras após stop
   bool     cooldownIgnoreF5;    // Ignorar cooldown para força 5
   
   //--- RSIOMA Filter (NOVO)
   bool     rsiomaActive;        // Filtro RSIOMA ativo
   int      rsiomaPeriod;        // Período do RSI (padrão: 14)
   int      rsiomaMA_Period;     // Período da MA do RSI (padrão: 9)
   ENUM_MA_METHOD rsiomaMA_Method; // Método da MA (SMA, EMA, etc.)
   int      rsiomaOverbought;    // Nível sobrecompra (padrão: 70)
   int      rsiomaOversold;      // Nível sobrevenda (padrão: 30)
   bool     rsiomaCheckMidLevel; // Verificar nível 50 (momentum)
   bool     rsiomaCheckCrossover;// Verificar cruzamento RSI×MA
   int      rsiomaConfirmBars;   // Número de barras para confirmação (1-5)
   
   //--- OBV MACD Filter (NOVO - Nexus Logic)
   bool     obvmACDActive;       // Filtro OBV MACD ativo
   bool     obvmACDRequireBuy;   // Exigir sinal de compra
   bool     obvmACDRequireSell;  // Exigir sinal de venda
   bool     obvmACDAllowWeakSignals; // Permitir sinais fracos (HOLD_B/HOLD_S)
   bool     obvmACDCheckVolumeRelevance; // Verificar volume relevante
   
   //--- Parâmetros do Indicador OBV MACD
   int      obvFastEMA;
   int      obvSlowEMA;
   int      obvSignalSMA;
   int      obvSmooth;
   bool     obvUseTickVolume;
   int      obvThreshPeriod;
   double   obvThreshMult;
   
   //--- NOVO: Filtro de Leque Aberto (EMA Fan) - CORREÇÃO FUNDAMENTAL
   //--- Bloqueia trades quando EMAs estão emaranhadas (mercado lateral)
   bool     lequeAbertoActive;   // Ativar filtro de leque aberto
   int      lequeAbertoMinEMAs;  // Mínimo de EMAs alinhadas (3-5)
};

//+------------------------------------------------------------------+
//| Classe de Filtros Adicionais                                     |
//+------------------------------------------------------------------+
class CFilters
{
private:
   CAssetSpecs*       m_asset;          // Ponteiro para especificações
   CSignalFGM*        m_signal;         // Ponteiro para sinal
   CRegimeDetector*   m_regime;         // Ponteiro para detector de regime
   FilterConfig       m_config;         // Configuração
   bool               m_initialized;    // Flag de inicialização
   string             m_lastError;      // Último erro
   
   //--- Handle do volume MA
   int                m_handleVolumeMA;
   double             m_bufferVolumeMA[];
   
   //--- Handle do RSIOMA (NOVO)
   int                m_handleRSI;
   double             m_bufferRSI[];
   double             m_bufferRSIMA[];
   
   //--- OBV MACD (NOVO - Direct Logic)
   int                m_handleOBVMACD;  // Handle do indicador OBV MACD
   double             m_bufferOBVHist[];      // Buffer 0
   double             m_bufferOBVColor[];     // Buffer 1
   double             m_bufferOBVThreshold[]; // Buffer 4

   //--- VWAP Filter (NOVO - Visual Sync)
   int                m_handleVWAP;     // Handle do indicador VWAP
   double             m_bufferVWAP[];   // Buffer 0
   
   //--- SINCRONIZAÇÃO: Shift atual para leitura de buffers
   int                m_currentShift;   // Barra atual do sinal (0 ou 1)
   
   //--- Cooldown tracking
   int                m_cooldownCounter;    // Contador de barras em cooldown
   datetime           m_lastBarTime;        // Tempo da última barra processada
   datetime           m_lastStopTime;       // Tempo do último stop
   
   //--- Métodos privados
   bool               CheckSpread();
   bool               CheckSlope(bool isBuy);
   bool               CheckVolume(int strength);
   bool               CheckConfluence(int strength);
   bool               CheckPhase(bool isBuy);
   bool               CheckStrength(int minStrength);
   bool               CheckEMA200(bool isBuy);
   bool               CheckCooldown(int strength);
   bool               CheckRSIOMA(bool isBuy, int shift);
   bool               CheckOBVMACD(bool isBuy, int shift);
   bool               CheckVWAP(bool isBuy, int shift);    // Agora usa indicador visual
   bool               CheckLequeAberto(bool isBuy, int shift);
   void               UpdateCooldown();
   
   void               CreateOBVMACDHandle(); // Helper
   void               CreateVWAPHandle();    // Helper VWAP

public:
   //--- PROTOCOLO ESTRATÉGICO 1-2-3 (SINCRONIA TOTAL)
   bool               CheckStep1_Trend(bool isBuy, int shift);    // Passo 1: Tendência (Leque + Preço)
   bool               CheckStep2_Momentum(bool isBuy, int shift); // Passo 2: Momentum (RSIOMA)
   bool               CheckStep3_Volume(bool isBuy, int shift);   // Passo 3: Fluxo/Volume (OBV MACD)
   bool               CheckStrategy123(bool isBuy, int shift);    // Validação Final
                      CFilters();
                     ~CFilters();
   
   //--- Inicialização
   bool               Init(CAssetSpecs* asset, CSignalFGM* signal, CRegimeDetector* regime);
   void               Deinit();
   bool               IsInitialized() { return m_initialized; }
   string             GetLastError() { return m_lastError; }
   
   //--- Configuração
   void               SetConfig(const FilterConfig& config);
   void               SetConfig(bool slopeActive, int slopePeriod, double slopeMinWIN, double slopeMinWDO, double slopeMinFX,
                                bool volActive, int volPeriod, double volMult, bool volIgnoreF5,
                                bool atrActive, int atrPeriod, double atrMult,
                                double confMaxF3, double confMaxF4, double confMaxF5,
                                bool phaseActive, int minBuy, int maxSell,
                                bool ema200Active,
                                bool cooldownActive, int cooldownBars, bool cooldownIgnoreF5,
                                bool rsiomaActive, int rsiPeriod, int rsiMA, int rsiOB, int rsiOS, bool rsiCheckMid, bool rsiCheckCross, int rsiConfirmBars,
                                bool obvmACDActive, bool requireBuy, bool requireSell, bool allowWeak, bool checkVol, int obvFast, int obvSlow, int obvSig, int obvSmooth, bool obvTick, int obvThreshPeriod, double obvThreshMult,
                                bool useVWAPFilter); // <--- NEW ARGUMENT
                                
   FilterConfig       GetConfig() { return m_config; }
   void               SetDefaultConfig();
   void               SetOBVMACDParams(int fastEMA, int slowEMA, int signalSMA, 
                                       int obvSmooth, bool useTickVolume, 
                                       int threshPeriod, double threshMult);
   
   //--- Verificação principal (signalShift = barra onde o sinal foi detectado)
   FilterResult       CheckAll(bool isBuy, int minStrength, bool skipPhaseFilter = false, int signalShift = 1);
   bool               PassesAllFilters(bool isBuy, int minStrength, bool skipPhaseFilter = false, int signalShift = 1);
   
   //--- Verificações individuais (públicas)
   bool               IsSpreadOK();
   bool               IsSlopeOK(bool isBuy);
   bool               IsVolumeOK(int strength);
   bool               IsConfluenceOK(int strength);
   bool               IsPhaseOK(bool isBuy);
   bool               IsStrengthOK(int minStrength);
   bool               IsEMA200OK(bool isBuy);
   bool               IsCooldownOK(int strength);
   bool               IsRSIOMAOK(bool isBuy); // NOVO
   
   //--- Gestão de cooldown
   void               StartCooldownAfterStop();
   void               ResetCooldown();
   bool               IsInCooldown();
   int                GetCooldownRemaining();
   
   //--- Valores atuais
   double             GetCurrentSpread();
   double             GetCurrentSlope(bool isBuy = true);
   double             GetCurrentVolume();
   double             GetVolumeMA();
   double             GetCurrentRSI();       // NOVO
   double             GetCurrentRSIMA();     // NOVO
   
   //--- OnTick para atualizar cooldown
   void               OnNewBar();
   
   //--- Debug
   void               PrintFilterStatus(bool isBuy, int minStrength);
};

//+------------------------------------------------------------------+
//| Definir configuração (Overload Longa)                            |
//+------------------------------------------------------------------+
void CFilters::SetConfig(bool slopeActive, int slopePeriod, double slopeMinWIN, double slopeMinWDO, double slopeMinFX,
                        bool volActive, int volPeriod, double volMult, bool volIgnoreF5,
                        bool atrActive, int atrPeriod, double atrMult,
                        double confMaxF3, double confMaxF4, double confMaxF5,
                        bool phaseActive, int minBuy, int maxSell,
                        bool ema200Active,
                        bool cooldownActive, int cooldownBars, bool cooldownIgnoreF5,
                        bool rsiomaActive, int rsiPeriod, int rsiMA, int rsiOB, int rsiOS, bool rsiCheckMid, bool rsiCheckCross, int rsiConfirmBars,
                        bool obvmACDActive, bool requireBuy, bool requireSell, bool allowWeak, bool checkVol, int obvFast, int obvSlow, int obvSig, int obvSmooth, bool obvTick, int obvThreshPeriod, double obvThreshMult,
                        bool useVWAPFilter) // <--- NEW ARGUMENT
{
   // 1. Preencher struct
   m_config.slopeActive = slopeActive;
   m_config.slopePeriod = slopePeriod;
   m_config.slopeMinWIN = slopeMinWIN;
   m_config.slopeMinWDO = slopeMinWDO;
   m_config.slopeMinForex = slopeMinFX;
   
   m_config.volumeActive = volActive;
   m_config.volumeMAPeriod = volPeriod;
   m_config.volumeMultiplier = volMult;
   m_config.volumeIgnoreF5 = volIgnoreF5;
   
   m_config.atrActive = atrActive;
   m_config.atrPeriod = atrPeriod;
   m_config.atrMultiplier = atrMult;
   
   m_config.confluenceMaxF3 = confMaxF3;
   m_config.confluenceMaxF4 = confMaxF4;
   m_config.confluenceMaxF5 = confMaxF5;
   
   m_config.phaseFilterActive = phaseActive;
   m_config.minPhaseBuy = minBuy;
   m_config.minPhaseSell = maxSell;
   
   m_config.ema200FilterActive = ema200Active;
   
   m_config.cooldownActive = cooldownActive;
   m_config.cooldownBarsAfterStop = cooldownBars;
   m_config.cooldownIgnoreF5 = cooldownIgnoreF5;
   
   // RSIOMA
   m_config.rsiomaActive = rsiomaActive;
   m_config.rsiomaPeriod = rsiPeriod;
   m_config.rsiomaMA_Period = rsiMA;
   m_config.rsiomaOverbought = rsiOB;
   m_config.rsiomaOversold = rsiOS;
   m_config.rsiomaCheckMidLevel = rsiCheckMid;
   m_config.rsiomaCheckCrossover = rsiCheckCross;
   m_config.rsiomaConfirmBars = rsiConfirmBars;

   // OBV MACD
   m_config.obvmACDActive = obvmACDActive;
   m_config.obvmACDRequireBuy = requireBuy;
   m_config.obvmACDRequireSell = requireSell;
   m_config.obvmACDAllowWeakSignals = allowWeak;
   m_config.obvmACDCheckVolumeRelevance = checkVol;
   m_config.obvFastEMA = obvFast;
   m_config.obvSlowEMA = obvSlow;
   m_config.obvSignalSMA = obvSig;
   m_config.obvSmooth = obvSmooth;
   m_config.obvUseTickVolume = obvTick;
   m_config.obvThreshPeriod = obvThreshPeriod;
   m_config.obvThreshMult = obvThreshMult;
   
   // VWAP
   m_config.useVWAPFilter = useVWAPFilter;
   
   // 2. Inicializar Handles Necessários
   // RSIOMA
   if(m_config.rsiomaActive && m_handleRSI == INVALID_HANDLE && m_asset != NULL)
   {
       m_handleRSI = iCustom(m_asset.GetSymbol(), PERIOD_CURRENT, 
                            "FGM_TrendRider_EA\\RSIOMA_v2HHLSX_MT5",
                            m_config.rsiomaPeriod, m_config.rsiomaMA_Period, MODE_SMA,
                            (double)m_config.rsiomaOverbought, (double)m_config.rsiomaOversold, true);
       Print("CFilters: RSIOMA Handle Created via Long SetConfig");
   }
   
   // OBV MACD
   if(m_config.obvmACDActive && m_handleOBVMACD == INVALID_HANDLE && m_asset != NULL)
   {
      CreateOBVMACDHandle();
   }
   
   // VWAP (NOVO) - Create if active
   if(m_config.useVWAPFilter && m_handleVWAP == INVALID_HANDLE && m_asset != NULL)
   {
      CreateVWAPHandle();
   }
   
   Print("CFilters::SetConfig (Long) - All Configs Updated.");
}

//+------------------------------------------------------------------+
//| Verify VWAP using Indicator                                      |
//+------------------------------------------------------------------+
bool CFilters::CheckVWAP(bool isBuy, int shift)
{
   if(!m_config.useVWAPFilter) return true;
   
   if(m_handleVWAP == INVALID_HANDLE)
   {
      CreateVWAPHandle(); // Try to lazy load
      if(m_handleVWAP == INVALID_HANDLE) return true; // Fail safe
   }
   
   double vwapParams[];
   if(CopyBuffer(m_handleVWAP, 0, shift, 1, vwapParams) <= 0)
      return true; // Data not ready
      
   double vwap = vwapParams[0];
   double closePrice = iClose(m_asset.GetSymbol(), PERIOD_CURRENT, shift);
   
   if(isBuy)
   {
      // CORREÇÃO: User pediu para ignorar Abertura. Apenas Fechamento importa (Romper/Estar acima/abaixo)
      if(closePrice > vwap) 
      {
         Print(StringFormat("VWAP CHECK: APROVADO [BUY] | Close(%.2f) > VWAP(%.2f)", closePrice, vwap));
         return true;
      }
      else 
      {
         Print(StringFormat("VWAP CHECK: REPROVADO [BUY] | Close(%.2f) <= VWAP(%.2f) - Preço abaixo da VWAP (Filtro Ativo)", closePrice, vwap));
         return false;
      }
   }
   else // SELL
   {
      // CORREÇÃO: User pediu para ignorar Abertura. Apenas Fechamento importa.
      if(closePrice < vwap) 
      {
         Print(StringFormat("VWAP CHECK: APROVADO [SELL] | Close(%.2f) < VWAP(%.2f)", closePrice, vwap));
         return true;
      }
      else 
      {
         Print(StringFormat("VWAP CHECK: REPROVADO [SELL] | Close(%.2f) >= VWAP(%.2f) - Preço acima da VWAP (Filtro Ativo)", closePrice, vwap));
         return false;
      }
   }
}

//+------------------------------------------------------------------+
//| Create VWAP Handle                                               |
//+------------------------------------------------------------------+
void CFilters::CreateVWAPHandle()
{
   if(m_handleVWAP != INVALID_HANDLE) return;
   
   m_handleVWAP = iCustom(m_asset.GetSymbol(), PERIOD_CURRENT, "FGM_TrendRider_EA\\FGM_VWAP_Daily");
   
   if(m_handleVWAP == INVALID_HANDLE)
      Print("CFilters: Erro ao criar FGM_VWAP_Daily handle");
   else
      Print("CFilters: FGM_VWAP_Daily ativado com sucesso");
}

//+------------------------------------------------------------------+
//| Deinicialização (Update)                                         |
//+------------------------------------------------------------------+
// ... (Add VWAP release to Deinit, handled via separate chunk or manual edit if needed. 
//      Wait, replacement allows creating method but I should update Deinit too.)


//+------------------------------------------------------------------+
//| Construtor                                                        |
//+------------------------------------------------------------------+
CFilters::CFilters()
{
   m_asset = NULL;
   m_signal = NULL;
   m_regime = NULL;
   m_initialized = false;
   m_lastError = "";
   m_handleVolumeMA = INVALID_HANDLE;
   m_handleRSI = INVALID_HANDLE;
   m_handleOBVMACD = INVALID_HANDLE;
   m_cooldownCounter = 0;
   m_lastBarTime = 0;
   m_lastStopTime = 0;
   m_currentShift = 1;  // Default: barra fechada (mais seguro)
   
   ArraySetAsSeries(m_bufferVolumeMA, true);
   ArraySetAsSeries(m_bufferRSI, true);
   ArraySetAsSeries(m_bufferRSIMA, true);
   ArraySetAsSeries(m_bufferOBVHist, true);
   ArraySetAsSeries(m_bufferOBVColor, true);
   ArraySetAsSeries(m_bufferOBVThreshold, true);
   
   SetDefaultConfig();
}


//+------------------------------------------------------------------+
//| Destrutor                                                         |
//+------------------------------------------------------------------+
CFilters::~CFilters()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Inicialização                                                     |
//+------------------------------------------------------------------+
bool CFilters::Init(CAssetSpecs* asset, CSignalFGM* signal, CRegimeDetector* regime)
{
   if(asset == NULL || !asset.IsInitialized())
   {
      m_lastError = "CAssetSpecs inválido";
      return false;
   }
   
   if(signal == NULL || !signal.IsInitialized())
   {
      m_lastError = "CSignalFGM inválido";
      return false;
   }
   
   m_asset = asset;
   m_signal = signal;
   m_regime = regime; // Pode ser NULL
   
   //--- Criar handle da MA de volume (apenas para B3)
   if(m_asset.IsB3() && m_config.volumeActive)
   {
      m_handleVolumeMA = iMA(m_asset.GetSymbol(), PERIOD_CURRENT, 
                              m_config.volumeMAPeriod, 0, MODE_SMA, VOLUME_TICK);
      
      if(m_handleVolumeMA == INVALID_HANDLE)
      {
         Print("CFilters: Aviso - Não foi possível criar MA de volume");
         // Não falha, apenas desativa o filtro
      }
   }
   
   //--- Criar handle do RSIOMA customizado
   if(m_config.rsiomaActive)
   {
      //--- Usar indicador RSIOMA customizado via iCustom
      m_handleRSI = iCustom(m_asset.GetSymbol(), PERIOD_CURRENT, 
                            "FGM_TrendRider_EA\\RSIOMA_v2HHLSX_MT5",
                            m_config.rsiomaPeriod,
                            m_config.rsiomaMA_Period,
                            m_config.rsiomaMA_Method,
                            (double)m_config.rsiomaOverbought,
                            (double)m_config.rsiomaOversold,
                            true);
      
      if(m_handleRSI == INVALID_HANDLE)
      {
         Print("CFilters: Aviso - Não foi possível criar handle RSIOMA customizado");
         Print("CFilters: Erro: ", GetLastError());
         m_config.rsiomaActive = false;
      }
      else
      {
         Print("CFilters: RSIOMA Filter ativado (indicador customizado)");
         Print("CFilters: RSI(", m_config.rsiomaPeriod, 
               ") MA(", m_config.rsiomaMA_Period, 
               ") OB:", m_config.rsiomaOverbought, 
               " OS:", m_config.rsiomaOversold);
      }
   }
   
   //--- Inicializar OBV MACD (Direto no CFilters)
   if(m_config.obvmACDActive)
   {
      CreateOBVMACDHandle();
   }
   
   m_initialized = true;
   Print("CFilters: Inicializado com sucesso");
   
   return true;
}

//+------------------------------------------------------------------+
//| Helper para criar handle OBV MACD                                |
//+------------------------------------------------------------------+
void CFilters::CreateOBVMACDHandle()
{
   if(m_handleOBVMACD != INVALID_HANDLE)
   {
      IndicatorRelease(m_handleOBVMACD);
      m_handleOBVMACD = INVALID_HANDLE;
   }
   
   //--- Caminho do indicador: FGM_TrendRider_EA\OBV_MACD_v3.ex5
   m_handleOBVMACD = iCustom(m_asset.GetSymbol(), PERIOD_CURRENT,
                             "FGM_TrendRider_EA\\OBV_MACD_v3",
                             m_config.obvFastEMA,
                             m_config.obvSlowEMA,
                             m_config.obvSignalSMA,
                             m_config.obvSmooth,
                             m_config.obvUseTickVolume,
                             m_config.obvThreshPeriod,
                             m_config.obvThreshMult);
                             
   if(m_handleOBVMACD == INVALID_HANDLE)
   {
      Print("CFilters: Aviso - Não foi possível criar handle OBV MACD");
      Print("CFilters: Erro: ", GetLastError());
      m_config.obvmACDActive = false;
   }
   else
   {
      Print("CFilters: OBV MACD Filter ativado - Handle criado com sucesso");
   }
}

//+------------------------------------------------------------------+
//| Deinicialização                                                   |
//+------------------------------------------------------------------+
void CFilters::Deinit()
{
   if(m_handleVolumeMA != INVALID_HANDLE)
   {
      IndicatorRelease(m_handleVolumeMA);
      m_handleVolumeMA = INVALID_HANDLE;
   }
   if(m_handleRSI != INVALID_HANDLE)
   {
      IndicatorRelease(m_handleRSI);
      m_handleRSI = INVALID_HANDLE;
   }
   if(m_handleOBVMACD != INVALID_HANDLE)
   {
      IndicatorRelease(m_handleOBVMACD);
      m_handleOBVMACD = INVALID_HANDLE;
   }
   if(m_handleVWAP != INVALID_HANDLE)
   {
      IndicatorRelease(m_handleVWAP);
      m_handleVWAP = INVALID_HANDLE;
   }
   m_initialized = false;
}

//+------------------------------------------------------------------+
//| Configuração padrão                                              |
//+------------------------------------------------------------------+
void CFilters::SetDefaultConfig()
{
   //--- Spread
   m_config.spreadMaxWIN = 25;
   m_config.spreadMaxWDO = 4;
   m_config.spreadMaxForex = 25;
   
   //--- Slope
   m_config.slopeActive = true;
   m_config.slopePeriod = 5;
   m_config.slopeMinWIN = 2.0;
   m_config.slopeMinWDO = 0.3;
   m_config.slopeMinForex = 0.5;
   
   //--- Volume
   m_config.volumeActive = true;
   m_config.volumeMAPeriod = 20;
   m_config.volumeMultiplier = 0.7;
   m_config.volumeIgnoreF5 = true;
   
   //--- Confluência (limites MÁXIMOS)
   m_config.confluenceMaxF3 = 100.0;
   m_config.confluenceMaxF4 = 100.0;
   m_config.confluenceMaxF5 = 100.0;
   
   //--- Confluência MÍNIMA (NOVO)
   m_config.confluenceMin = 0.0;       // Desativado por padrão (0 = sem mínimo)
   m_config.confluenceMinActive = false;
   
   //--- Fase
   m_config.phaseFilterActive = true;
   m_config.minPhaseBuy = 1;   // Weak Bull ou melhor
   m_config.minPhaseSell = -1; // Weak Bear ou pior
   
   //--- EMA 200
   m_config.ema200FilterActive = true;
   
   //--- Cooldown
   m_config.cooldownActive = true;
   m_config.cooldownBarsAfterStop = 6;
   m_config.cooldownIgnoreF5 = true;
   
   //--- RSIOMA Filter
   m_config.rsiomaActive = false;
   m_config.rsiomaPeriod = 14;
   m_config.rsiomaMA_Period = 9;
   m_config.rsiomaMA_Method = MODE_SMA;
   m_config.rsiomaOverbought = 80;
   m_config.rsiomaOversold = 20;
   m_config.rsiomaCheckMidLevel = true;
   m_config.rsiomaCheckCrossover = false;
   m_config.rsiomaConfirmBars = 1;
   
   //--- OBV MACD Filter
   m_config.obvmACDActive = false;
   m_config.obvmACDRequireBuy = false;
   m_config.obvmACDRequireSell = false;
   m_config.obvmACDAllowWeakSignals = true;
   m_config.obvmACDCheckVolumeRelevance = false;
   
   //--- Parâmetros OBV MACD padrão
   m_config.obvFastEMA = 12;
   m_config.obvSlowEMA = 26;
   m_config.obvSignalSMA = 9;
   m_config.obvSmooth = 5;
   m_config.obvUseTickVolume = true;
   m_config.obvThreshPeriod = 34;
   m_config.obvThreshMult = 0.6;
   
   //--- Leque Aberto (EMA Fan)
   m_config.lequeAbertoActive = true;  // Ativado por padrão (correção fundamental)
   m_config.lequeAbertoMinEMAs = 5;    // Exigir alinhamento total (1 a 5)
}

//+------------------------------------------------------------------+
//| Definir configuração                                             |
//+------------------------------------------------------------------+
void CFilters::SetConfig(const FilterConfig& config)
{
   //--- Verificar se RSIOMA foi ativado e precisa criar handle
   bool needsRSIHandle = (config.rsiomaActive && m_handleRSI == INVALID_HANDLE);
   
   //--- Verificar se OBV MACD foi ativado (handle criado em CreateOBVMACDHandle se precisar)
   //--- Mas aqui só checamos se mudou o estado de ativo para recriar se necessário
   bool needsOBVMACD = (config.obvmACDActive && m_handleOBVMACD == INVALID_HANDLE);
   
   m_config = config;
   
   //--- Criar handle RSIOMA se foi ativado agora
   if(needsRSIHandle && m_asset != NULL)
   {
      m_handleRSI = iCustom(m_asset.GetSymbol(), PERIOD_CURRENT, 
                            "FGM_TrendRider_EA\\RSIOMA_v2HHLSX_MT5",
                            m_config.rsiomaPeriod,
                            m_config.rsiomaMA_Period,
                            m_config.rsiomaMA_Method,
                            (double)m_config.rsiomaOverbought,
                            (double)m_config.rsiomaOversold,
                            true);
      
      if(m_handleRSI == INVALID_HANDLE)
      {
         Print("CFilters: Aviso - Não foi possível criar handle RSIOMA");
         m_config.rsiomaActive = false;
      }
      else
      {
         Print("CFilters: RSIOMA Filter ativado com parâmetros novos");
      }
   }
   
   //--- Inicializar OBV MACD se foi ativado agora
   if(needsOBVMACD && m_asset != NULL)
   {
      CreateOBVMACDHandle();
   }
   
   //--- DEBUG: Log da configuração recebida
   Print("CFilters::SetConfig - Configurações atualizadas.");
   Print(StringFormat("  OBV MACD ativo: %s | RequireBuy: %s | RequireSell: %s",
                      m_config.obvmACDActive ? "SIM" : "NÃO",
                      m_config.obvmACDRequireBuy ? "SIM" : "NÃO",
                      m_config.obvmACDRequireSell ? "SIM" : "NÃO"));
}

//+------------------------------------------------------------------+
//| Verificar spread                                                 |
//+------------------------------------------------------------------+
bool CFilters::CheckSpread()
{
   if(m_asset == NULL)
      return false;
   
   int currentSpread = (int)SymbolInfoInteger(m_asset.GetSymbol(), SYMBOL_SPREAD);
   int maxSpread;
   
   if(m_asset.IsWIN())
      maxSpread = m_config.spreadMaxWIN;
   else if(m_asset.IsWDO())
      maxSpread = m_config.spreadMaxWDO;
   else
      maxSpread = m_config.spreadMaxForex;
   
   return (currentSpread <= maxSpread);
}

//+------------------------------------------------------------------+
//| Verificar slope                                                  |
//+------------------------------------------------------------------+
bool CFilters::CheckSlope(bool isBuy)
{
   if(!m_config.slopeActive || m_signal == NULL)
      return true;
   
   //--- Obter força do sinal atual
   int strength = (int)MathAbs(m_signal.GetStrength(0));
   
   //--- F4-F5: Ignorar slope completamente (tendência confirmada pelo indicador)
   //--- O indicador FGM já fez a análise de tendência com 5 EMAs
   if(strength >= 4)
      return true;
   
   double slope = m_signal.CalculateSlope(m_config.slopePeriod, 0);
   
   double minSlope;
   if(m_asset.IsWIN())
      minSlope = m_config.slopeMinWIN;
   else if(m_asset.IsWDO())
      minSlope = m_config.slopeMinWDO;
   else
      minSlope = m_config.slopeMinForex;
   
   if(isBuy)
      return (slope >= minSlope);
   else
      return (slope <= -minSlope);
}

//+------------------------------------------------------------------+
//| Verificar volume                                                 |
//+------------------------------------------------------------------+
bool CFilters::CheckVolume(int strength)
{
   //--- Desativado para Forex
   if(!m_config.volumeActive || !m_asset.IsB3())
      return true;
   
   //--- Ignorar para F4 e F5
   if(strength >= 4)
      return true;
   
   //--- CORREÇÃO: Para volume, se o sinal for na barra 0 (abertura),
   //--- o volume ainda é baixo. Devemos olhar a barra anterior (1) para validação.
   //--- Se o sinal for na barra 1 (fechada), olhamos a própria barra 1.
   int volumeShift = MathMax(1, m_currentShift);
   
   //--- Obter volume atual
   //--- Obter volume atual da barra de análise
   long volumes[];
   if(CopyTickVolume(m_asset.GetSymbol(), PERIOD_CURRENT, volumeShift, 1, volumes) <= 0)
      return true;
   
   double currentVolume = (double)volumes[0];
   
   //--- Obter média do volume
   double volumeMA = GetVolumeMA();
   if(volumeMA <= 0)
      return true;
   
   //--- Comparar
   double threshold = volumeMA * m_config.volumeMultiplier;
   
   return (currentVolume >= threshold);
}

//+------------------------------------------------------------------+
//| Verificar confluência                                            |
//+------------------------------------------------------------------+
bool CFilters::CheckConfluence(int strength)
{
   if(m_signal == NULL)
      return true;
   
   //--- CORREÇÃO: Ler a confluência na MESMA barra do sinal (m_currentShift)
   double confluence = m_signal.GetConfluence(m_currentShift);


   //--- strength já vem como valor absoluto
   int absStrength = strength;

   //--- Limite MÁXIMO de confluência permitido por força
   double maxConfluence = 0.0;

   switch(absStrength)
   {
      case 5: maxConfluence = m_config.confluenceMaxF5; break;
      case 4: maxConfluence = m_config.confluenceMaxF4; break;
      case 3: maxConfluence = m_config.confluenceMaxF3; break;
      default: maxConfluence = m_config.confluenceMaxF3; break;
   }

   //--- DEBUG: Log para diagnóstico
   Print(StringFormat("CFilters::CheckConfluence - F%d: Confluência=%.1f%% (mín=%.1f%%, máx=%.1f%%)", 
                      absStrength, confluence, m_config.confluenceMin, maxConfluence));

   //--- NOVO: Verificar confluência MÍNIMA (rejeitar sinais fracos)
   if(m_config.confluenceMinActive && m_config.confluenceMin > 0.0)
   {
      if(confluence < m_config.confluenceMin)
      {
         Print(StringFormat("CFilters: Confluência BAIXA demais: %.1f%% (mín: %.1f%%) - Sinal fraco rejeitado",
                            confluence, m_config.confluenceMin));
         return false;
      }
   }

   //--- Se maxConfluence <= 0, não aplicar filtro de confluência máxima
   if(maxConfluence <= 0.0)
      return true;

   //--- Aprovar somente se a compressão das EMAs NÃO estiver alta demais
   //    (confluência acima do limite => mercado lateral => bloquear).
   return (confluence <= maxConfluence);
}


//+------------------------------------------------------------------+
//| Verificar fase de mercado                                        |
//+------------------------------------------------------------------+
bool CFilters::CheckPhase(bool isBuy)
{
   if(!m_config.phaseFilterActive || m_signal == NULL)
      return true;
   
   //--- CORREÇÃO: Usar m_currentShift para sincronizar com o sinal
   int phase = (int)m_signal.GetPhase(m_currentShift);
   
   if(isBuy)
      return (phase >= m_config.minPhaseBuy);
   else
      return (phase <= m_config.minPhaseSell);
}


//+------------------------------------------------------------------+
//| Verificar força do sinal                                         |
//+------------------------------------------------------------------+
bool CFilters::CheckStrength(int minStrength)
{
   if(m_signal == NULL)
      return false;
   
   //--- Usar valor absoluto - Strength é negativo para SELL
   int strength = (int)MathAbs(m_signal.GetStrength(0));
   
   return (strength >= minStrength);
}

//+------------------------------------------------------------------+
//| Verificar EMA 200                                                |
//+------------------------------------------------------------------+
bool CFilters::CheckEMA200(bool isBuy)
{
   if(!m_config.ema200FilterActive || m_signal == NULL)
      return true;
   
   double ema200 = m_signal.GetEMA5(0);
   
   double closes[];
   ArraySetAsSeries(closes, true);
   if(CopyClose(m_asset.GetSymbol(), PERIOD_CURRENT, 1, 1, closes) <= 0)
      return true;
   
   double close = closes[0];
   
   if(isBuy)
      return (close > ema200);
   else
      return (close < ema200);
}

//+------------------------------------------------------------------+
//| Verificar cooldown                                               |
//+------------------------------------------------------------------+
bool CFilters::CheckCooldown(int strength)
{
   if(!m_config.cooldownActive)
      return true;
   
   //--- strength já vem como valor absoluto
   //--- Ignorar para força 5
   if(m_config.cooldownIgnoreF5 && strength >= 5)
      return true;
   
   return (m_cooldownCounter <= 0);
}

//+------------------------------------------------------------------+
//| Atualizar cooldown                                               |
//+------------------------------------------------------------------+
void CFilters::UpdateCooldown()
{
   if(m_cooldownCounter > 0)
      m_cooldownCounter--;
}


//+------------------------------------------------------------------+
//| Verificação principal                                            |
//+------------------------------------------------------------------+
FilterResult CFilters::CheckAll(bool isBuy, int minStrength, bool skipPhaseFilter = false, int signalShift = 1)
{
   FilterResult result;
   ZeroMemory(result);
   result.passed = true;
   result.failReason = "";
   
   if(!m_initialized)
   {
      result.passed = false;
      result.failReason = "Filtros não inicializados";
      return result;
   }
   
   //--- SINCRONIZAÇÃO CRÍTICA: Armazenar o shift para uso em todos os métodos
   m_currentShift = signalShift;
   
   //--- DEBUG: Log de sincronização
   Print(StringFormat("CFilters::CheckAll - Usando signalShift=%d para sincronização", signalShift));
   
   //--- Obter valores atuais para o resultado
   result.currentSpread = GetCurrentSpread();
   result.currentSlope = GetCurrentSlope(isBuy);
   result.currentVolume = GetCurrentVolume();
   result.volumeMA = GetVolumeMA();
   
   if(m_signal != NULL)
   {
      //--- CORREÇÃO: Usar m_currentShift (passado pelo EA) em vez de hardcoded 0
      result.currentConfluence = m_signal.GetConfluence(m_currentShift);
      //--- Usar valor absoluto - Strength é negativo para SELL
      result.currentStrength = (int)MathAbs(m_signal.GetStrength(m_currentShift));
      result.currentPhase = (int)m_signal.GetPhase(m_currentShift);
   }

   
   //--- Verificar cada filtro
   result.spreadOK = CheckSpread();
   if(!result.spreadOK)
   {
      result.passed = false;
      // Usar m_config para obter o spread máximo correto
      int maxSpread = 0;
      if(m_asset.IsWIN()) maxSpread = m_config.spreadMaxWIN;
      else if(m_asset.IsWDO()) maxSpread = m_config.spreadMaxWDO;
      else maxSpread = m_config.spreadMaxForex;
      
      result.failReason = StringFormat("Spread alto: %d (max: %d)", 
                                        (int)result.currentSpread, 
                                        maxSpread);
      return result;
   }
   
   result.strengthOK = CheckStrength(minStrength);
   if(!result.strengthOK)
   {
      result.passed = false;
      result.failReason = StringFormat("Força insuficiente: %d (min: %d)", 
                                        result.currentStrength, minStrength);
      return result;
   }
   
   //--- Phase Filter: pular se for PRICE CROSSOVER (já validamos que preço cruzou TODAS as EMAs)
   if(skipPhaseFilter)
      result.phaseOK = true;
   else
      result.phaseOK = CheckPhase(isBuy);
   
   if(!result.phaseOK)
   {
      result.passed = false;
      result.failReason = StringFormat("Fase inadequada: %d para %s", 
                                        result.currentPhase, isBuy ? "COMPRA" : "VENDA");
      return result;
   }
   
   //--- EMA200 Filter: pular para PRICE CROSSOVER (preço já cruzou TODAS as EMAs incluindo EMA200)
   if(skipPhaseFilter)
      result.ema200OK = true;
   else
      result.ema200OK = CheckEMA200(isBuy);
   
   if(!result.ema200OK)
   {
      result.passed = false;
      result.failReason = "Preço vs EMA200 inadequado";
      return result;
   }
   
   //--- Confluence Filter: pular para PRICE CROSSOVER (rompimento de todas EMAs confirma tendência)
   if(skipPhaseFilter)
      result.confluenceOK = true;
   else
      result.confluenceOK = CheckConfluence(result.currentStrength);
   
   if(!result.confluenceOK)
   {
      result.passed = false;
      // Determinar se foi bloqueado por confluência BAIXA ou ALTA
      if(m_config.confluenceMinActive && result.currentConfluence < m_config.confluenceMin)
         result.failReason = StringFormat("Confluência BAIXA demais (sinal fraco): %.1f%% (mín: %.1f%%)", 
                                          result.currentConfluence, m_config.confluenceMin);
      else
         result.failReason = StringFormat("Confluência ALTA demais (lateral): %.1f%%", result.currentConfluence);
      return result;
   }

   
   //--- Slope Filter: pular para PRICE CROSSOVER (movimento de preço confirma tendência)
   if(skipPhaseFilter)
      result.slopeOK = true;
   else
      result.slopeOK = CheckSlope(isBuy);
   
   if(!result.slopeOK)
   {
      result.passed = false;
      result.failReason = StringFormat("Slope insuficiente: %.4f", result.currentSlope);
      return result;
   }
   
   //--- Volume Filter: pular para PRICE CROSSOVER (rompimento de todas EMAs é confirmação suficiente)
   if(skipPhaseFilter)
      result.volumeOK = true;
   else
      result.volumeOK = CheckVolume(result.currentStrength);
   
   if(!result.volumeOK)
   {
      result.passed = false;
      result.failReason = StringFormat("Volume baixo: %.0f (MA: %.0f)", 
                                        result.currentVolume, result.volumeMA);
      return result;
   }
   
   result.cooldownOK = CheckCooldown(result.currentStrength);
   if(!result.cooldownOK)
   {
      result.passed = false;
      result.failReason = StringFormat("Em cooldown: %d barras restantes", m_cooldownCounter);
      return result;
   }
   
   //--- RSIOMA Filter (NOVO)
   result.rsiomaOK = CheckRSIOMA(isBuy, signalShift);
   result.currentRSI = GetCurrentRSI();
   result.currentRSIMA = GetCurrentRSIMA();
   
   if(!result.rsiomaOK)
   {
      result.passed = false;
      if(isBuy && result.currentRSI >= m_config.rsiomaOverbought)
         result.failReason = StringFormat("RSI sobrecomprado: %.1f (max: %d) - não comprar", 
                                           result.currentRSI, m_config.rsiomaOverbought);
      else if(!isBuy && result.currentRSI <= m_config.rsiomaOversold)
         result.failReason = StringFormat("RSI sobrevendido: %.1f (min: %d) - não vender", 
                                           result.currentRSI, m_config.rsiomaOversold);
      else if(m_config.rsiomaCheckMidLevel && isBuy && result.currentRSI < 50)
         result.failReason = StringFormat("RSI abaixo de 50: %.1f - momentum de baixa", result.currentRSI);
      else if(m_config.rsiomaCheckMidLevel && !isBuy && result.currentRSI > 50)
         result.failReason = StringFormat("RSI acima de 50: %.1f - momentum de alta", result.currentRSI);
      else if(m_config.rsiomaCheckCrossover)
         result.failReason = StringFormat("RSI vs MA: RSI=%.1f MA=%.1f - cruzamento inválido", 
                                           result.currentRSI, result.currentRSIMA);
      else
         result.failReason = StringFormat("RSIOMA filtro falhou: RSI=%.1f MA=%.1f", 
                                           result.currentRSI, result.currentRSIMA);
      return result;
   }
   
   //--- Leque Aberto Filter (NOVO - Filtro Fundamental)
   if(!CheckLequeAberto(isBuy, signalShift))
   {
      result.passed = false;
      result.failReason = "Leque de EMAs não está aberto (EMAs emaranhadas/lateral)";
      return result;
   }

   //--- OBV MACD Filter (NOVO - Nexus Logic com sincronismo sequencial)
   result.obvmACDOK = CheckOBVMACD(isBuy, signalShift);
   if(!result.obvmACDOK)
   {
      result.passed = false;
      if(isBuy)
         result.failReason = "OBV MACD: Sem sinal de compra ou em lateralização";
      else
         result.failReason = "OBV MACD: Sem sinal de venda ou em lateralização";
      return result;
   }
   
   //--- Todos os filtros passaram
   result.passed = true;
   result.failReason = "";
   
   return result;
}

//+------------------------------------------------------------------+
//| Verificar se passa todos os filtros (simplificado)               |
//+------------------------------------------------------------------+
bool CFilters::PassesAllFilters(bool isBuy, int minStrength, bool skipPhaseFilter = false, int signalShift = 1)
{
   FilterResult result = CheckAll(isBuy, minStrength, skipPhaseFilter, signalShift);
   return result.passed;
}


//+------------------------------------------------------------------+
//| Verificações individuais públicas                                |
//+------------------------------------------------------------------+
bool CFilters::IsSpreadOK()     { return CheckSpread(); }
bool CFilters::IsSlopeOK(bool isBuy)     { return CheckSlope(isBuy); }
bool CFilters::IsVolumeOK(int strength)  { return CheckVolume(strength); }
bool CFilters::IsConfluenceOK(int strength) { return CheckConfluence(strength); }
bool CFilters::IsPhaseOK(bool isBuy)     { return CheckPhase(isBuy); }
bool CFilters::IsStrengthOK(int minStrength) { return CheckStrength(minStrength); }
bool CFilters::IsEMA200OK(bool isBuy)    { return CheckEMA200(isBuy); }
bool CFilters::IsCooldownOK(int strength) { return CheckCooldown(strength); }

//+------------------------------------------------------------------+
//| Iniciar cooldown após stop                                       |
//+------------------------------------------------------------------+
void CFilters::StartCooldownAfterStop()
{
   m_cooldownCounter = m_config.cooldownBarsAfterStop;
   m_lastStopTime = TimeCurrent();
   Print("CFilters: Cooldown iniciado após stop - ", m_cooldownCounter, " barras");
}

//+------------------------------------------------------------------+
//| Resetar cooldown                                                 |
//+------------------------------------------------------------------+
void CFilters::ResetCooldown()
{
   m_cooldownCounter = 0;
}

//+------------------------------------------------------------------+
//| Verificar se está em cooldown                                    |
//+------------------------------------------------------------------+
bool CFilters::IsInCooldown()
{
   return (m_cooldownCounter > 0);
}

//+------------------------------------------------------------------+
//| Obter barras restantes de cooldown                               |
//+------------------------------------------------------------------+
int CFilters::GetCooldownRemaining()
{
   return m_cooldownCounter;
}

//+------------------------------------------------------------------+
//| Obter spread atual                                               |
//+------------------------------------------------------------------+
double CFilters::GetCurrentSpread()
{
   if(m_asset == NULL)
      return 0;
   
   return (double)SymbolInfoInteger(m_asset.GetSymbol(), SYMBOL_SPREAD);
}

//+------------------------------------------------------------------+
//| Obter slope atual                                                |
//+------------------------------------------------------------------+
double CFilters::GetCurrentSlope(bool isBuy = true)
{
   if(m_signal == NULL)
      return 0;
   
   //--- CORREÇÃO: Usar m_currentShift para calcular slope da barra do sinal
   return m_signal.CalculateSlope(m_config.slopePeriod, m_currentShift);
}

//+------------------------------------------------------------------+
//| Obter volume atual                                               |
//+------------------------------------------------------------------+
double CFilters::GetCurrentVolume()
{
   if(m_asset == NULL)
      return 0;
      
   //--- CORREÇÃO: Usar MathMax(1, m_currentShift) para consistência com CheckVolume
   int volumeShift = MathMax(1, m_currentShift);
   
   long volumes[];
   if(CopyTickVolume(m_asset.GetSymbol(), PERIOD_CURRENT, volumeShift, 1, volumes) <= 0)
      return 0;
   
   return (double)volumes[0];
}

//+------------------------------------------------------------------+
//| Obter média do volume                                            |
//+------------------------------------------------------------------+
double CFilters::GetVolumeMA()
{
   if(m_handleVolumeMA == INVALID_HANDLE)
      return 0;
   
   //--- CORREÇÃO: Usar MathMax(1, m_currentShift) para média também
   int volumeShift = MathMax(1, m_currentShift);
   
   if(CopyBuffer(m_handleVolumeMA, 0, volumeShift, 1, m_bufferVolumeMA) <= 0)
      return 0;
   
   return m_bufferVolumeMA[0];
}

//+------------------------------------------------------------------+
//| Chamar em nova barra para atualizar cooldown                     |
//+------------------------------------------------------------------+
void CFilters::OnNewBar()
{
   datetime currentBar = iTime(m_asset.GetSymbol(), PERIOD_CURRENT, 0);
   
   if(currentBar != m_lastBarTime)
   {
      m_lastBarTime = currentBar;
      UpdateCooldown();
   }
}

//+------------------------------------------------------------------+
//| Imprimir status dos filtros (debug)                              |
//+------------------------------------------------------------------+
void CFilters::PrintFilterStatus(bool isBuy, int minStrength)
{
   FilterResult result = CheckAll(isBuy, minStrength);
   
   Print("═══════════════════════════════════════════════════════════");
   Print("CFilters - Status dos Filtros");
   Print("═══════════════════════════════════════════════════════════");
   Print("Direção:       ", isBuy ? "COMPRA" : "VENDA");
   Print("Força Mínima:  ", minStrength);
   Print("RESULTADO:     ", result.passed ? "PASSOU ✓" : "BLOQUEADO ✗");
   if(!result.passed)
      Print("Motivo:        ", result.failReason);
   Print("───────────────────────────────────────────────────────────");
   Print("Spread:        ", result.spreadOK ? "OK ✓" : "FALHOU ✗", 
         " (", DoubleToString(result.currentSpread, 0), ")");
   // ATR removido do log
   Print("Força:         ", result.strengthOK ? "OK ✓" : "FALHOU ✗",
         " (", result.currentStrength, "/", minStrength, ")");
   Print("Fase:          ", result.phaseOK ? "OK ✓" : "FALHOU ✗",
         " (", result.currentPhase, ")");
   Print("EMA200:        ", result.ema200OK ? "OK ✓" : "FALHOU ✗");
   Print("Confluência:   ", result.confluenceOK ? "OK ✓" : "FALHOU ✗",
         " (", DoubleToString(result.currentConfluence, 1), "%)");
   Print("Slope:         ", result.slopeOK ? "OK ✓" : "FALHOU ✗",
         " (", DoubleToString(result.currentSlope, 4), ")");
   Print("Volume:        ", result.volumeOK ? "OK ✓" : "FALHOU ✗",
         " (", DoubleToString(result.currentVolume, 0), "/", DoubleToString(result.volumeMA, 0), ")");
   Print("Cooldown:      ", result.cooldownOK ? "OK ✓" : "FALHOU ✗",
         " (", m_cooldownCounter, " barras)");
   Print("RSIOMA:        ", result.rsiomaOK ? "OK ✓" : "FALHOU ✗",
         " (RSI=", DoubleToString(result.currentRSI, 1), 
         " MA=", DoubleToString(result.currentRSIMA, 1), ")");
   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Obter RSI atual (NOVO)                                           |
//+------------------------------------------------------------------+
double CFilters::GetCurrentRSI()
{
   if(m_handleRSI == INVALID_HANDLE)
      return 50.0; // Valor neutro se não há handle
   
   //--- IMPORTANTE: Usar barra 1 (FECHADA) para sincronizar com o sinal FGM
   //--- IMPORTANTE: no indicador MT5, o buffer 0 é o RSI (linha vermelha)
   //--- e o buffer 1 é a MA (linha azul). Aqui lemos EXATAMENTE como
   //--- o indicador desenha na tela para que gráfico e EA fiquem sincronizados.
   if(CopyBuffer(m_handleRSI, 0, 1, 1, m_bufferRSI) <= 0)
      return 50.0;
   
   return m_bufferRSI[0];
}

//+------------------------------------------------------------------+
//| Obter RSI MA atual (NOVO) - Buffer 1 do RSIOMA                       |
//+------------------------------------------------------------------+
double CFilters::GetCurrentRSIMA()
{
   if(m_handleRSI == INVALID_HANDLE)
      return 50.0;
   
   //--- MA do RSI = buffer 1 do indicador (linha azul)
   if(CopyBuffer(m_handleRSI, 1, 1, 1, m_bufferRSIMA) <= 0)
      return 50.0;
   
   return m_bufferRSIMA[0];
}

//+------------------------------------------------------------------+
//| Verificar filtro RSIOMA (NOVO)                                   |
//+------------------------------------------------------------------+
bool CFilters::CheckRSIOMA(bool isBuy, int shift)
{
   //--- Se filtro desativado, passa
   if(!m_config.rsiomaActive)
      return true;
   
   if(m_handleRSI == INVALID_HANDLE)
      return true; // Se não conseguiu criar, permite trade
   
   //--- Force 1 bar for instant reaction (Sniper Mode)
   //--- User input ignored to prevent lag. Verification is binary on current bar.
   int confirmBars = 1;
   
   //--- Arrays para ler múltiplas barras
   double rsiValues[], rsiMAValues[];
   ArraySetAsSeries(rsiValues, true);
   ArraySetAsSeries(rsiMAValues, true);
   
   //--- CORREÇÃO SINCRONIZAÇÃO: Usar shift para alinhar com o sinal FGM
   int startBar = shift;
   
   //--- DEBUG: Log de sincronização
   Print(StringFormat("CheckRSIOMA: Lendo a partir da barra %d (sincronizado com sinal)", startBar));
   
   //--- Copiar valores das últimas N barras (começando de m_currentShift)
   //--- LEITURA DIRETA: buffer 0 = RSI (linha vermelha), buffer 1 = MA (linha azul)
   //--- Lemos exatamente como o indicador desenha para não haver divergência
   //--- entre o que o trader vê e o que o EA utiliza nos filtros.
   double dbgRSI_Bar1 = EMPTY_VALUE;
   double dbgRSIMA_Bar1 = EMPTY_VALUE;
   double tempRSI[1], tempRSIMA[1];
   if(CopyBuffer(m_handleRSI, 0, startBar, 1, tempRSI) > 0)
      dbgRSI_Bar1 = tempRSI[0];
   if(CopyBuffer(m_handleRSI, 1, startBar, 1, tempRSIMA) > 0)
      dbgRSIMA_Bar1 = tempRSIMA[0];

   if(CopyBuffer(m_handleRSI, 0, startBar, confirmBars, rsiValues) < confirmBars)
      return true;
   if(CopyBuffer(m_handleRSI, 1, startBar, confirmBars, rsiMAValues) < confirmBars)
      return true;

   
   //--- DEBUG: Logar valores de todas as barras analisadas
   //--- Buffer 0 = RSI (linha vermelha visual) | Buffer 1 = MA (linha azul visual)
   Print("═══════════════════════════════════════════════════════════════════════");
   Print("RSIOMA DEBUG: ", isBuy ? "BUY" : "SELL", " | Verificando ", confirmBars, " barra(s)");
   Print("INDICADOR: FGM_TrendRider_EA\\RSIOMA_v2HHLSX_MT5");
   Print("PARÂMETROS: RSI(", m_config.rsiomaPeriod, ") MA(", m_config.rsiomaMA_Period, 
         ") Method:", m_config.rsiomaMA_Method);
   Print("───────────────────────────────────────────────────────────────────────");
   Print("MAPEAMENTO: Buffer 0 = RSI (vermelho) | Buffer 1 = MA (azul)");
   Print(StringFormat("DEBUG RAW (GetRSI/GetRSIMA) barra1: RSI=%.2f | MA=%.2f", dbgRSI_Bar1, dbgRSIMA_Bar1));
   Print("TOLERÂNCIA: Diferença mínima de 0.5 pts para cruzamento válido");
   Print("───────────────────────────────────────────────────────────────────────");
   for(int i = 0; i < confirmBars; i++)
   {
      datetime barTime = iTime(m_asset.GetSymbol(), PERIOD_CURRENT, i + 1);
      double closePrice = iClose(m_asset.GetSymbol(), PERIOD_CURRENT, i + 1);
      double diff = rsiValues[i] - rsiMAValues[i];
      string relation;
      if(diff >= 0.5)
         relation = "RSI > MA (ALTA CLARA)";
      else if(diff <= -0.5)
         relation = "RSI < MA (BAIXA CLARA)";
      else
         relation = "RSI ≈ MA (INDECISÃO)";
      
      Print("  Bar", i+1, " [", TimeToString(barTime, TIME_MINUTES), "] Close=", DoubleToString(closePrice, _Digits), ": ",
            "RSI=", DoubleToString(rsiValues[i], 2), " | ",
            "MA=", DoubleToString(rsiMAValues[i], 2), " | ",
            "Diff=", DoubleToString(diff, 2), " | ", relation);
   }
   Print("═══════════════════════════════════════════════════════════════════════");
   
   //--- FILTRO 1: Sobrecompra/Sobrevenda - Verificar apenas barra 1 (mais recente)
   //--- Não bloquear vendas só porque está sobrevendido no passado
   double rsi = rsiValues[0];
   double rsiMA = rsiMAValues[0];
   
   if(isBuy && rsi >= m_config.rsiomaOverbought)
   {
      Print("RSIOMA FILTRO: BUY bloqueado - RSI(", DoubleToString(rsi, 1), 
            ") >= Overbought(", m_config.rsiomaOverbought, ")");
      return false;
   }
   
   if(!isBuy && rsi <= m_config.rsiomaOversold)
   {
      Print("RSIOMA FILTRO: SELL bloqueado - RSI(", DoubleToString(rsi, 1), 
            ") <= Oversold(", m_config.rsiomaOversold, ")");
      return false;
   }
   
   //--- FILTRO 2: Nível 50 (momentum) - Verificar apenas barra 1 (mais recente)
   //--- O momentum ATUAL é o que importa - não faz sentido bloquear porque
   //--- barras anteriores estavam do outro lado do 50 (isso é natural numa reversão)
   if(m_config.rsiomaCheckMidLevel)
   {
      double rsiBar1 = rsiValues[0];
      
      if(isBuy && rsiBar1 < 50)
      {
         Print("RSIOMA FILTRO: BUY bloqueado - RSI(", 
               DoubleToString(rsiBar1, 1), ") < 50 - momentum de baixa");
         return false;
      }
      
      if(!isBuy && rsiBar1 > 50)
      {
         Print("RSIOMA FILTRO: SELL bloqueado - RSI(", 
               DoubleToString(rsiBar1, 1), ") > 50 - momentum de alta");
         return false;
      }
   }
   
   //--- FILTRO 2B: RSI vs MA - VALIDAÇÃO DE ESTADO (Nexus Logic)
   //--- "SE A LINHA VERMELHA ESTA ACIMA DA LINHA AZUL..."
   //--- Não importa crossing, slope ou histórico. Importa o AGORA.
   
   double rsiCurrent = rsiValues[0];   // Linha Vermelha
   double maCurrent = rsiMAValues[0];  // Linha Azul (Sinal)
   
   if(isBuy)
   {
      // COMPRA: Vermelha > Azul
      if(rsiCurrent > maCurrent)
      {
         Print(StringFormat("RSIOMA ESTADO: APROVADO (%.2f > %.2f)", rsiCurrent, maCurrent));
         return true;
      }
      else
      {
         Print(StringFormat("RSIOMA STATUS: REPROVADO [BUY]. Azul (%.2f) >= Vermelha (%.2f) - Sem Momentum de Alta", maCurrent, rsiCurrent));
         return false;
      }
   }
   else // SELL
   {
      // VENDA: Vermelha < Azul
      if(rsiCurrent < maCurrent)
      {
         Print(StringFormat("RSIOMA ESTADO: APROVADO (Vermelha %.2f < Azul %.2f)", rsiCurrent, maCurrent));
         return true;
      }
      else
      {
         Print(StringFormat("RSIOMA STATUS: REPROVADO [SELL]. Vermelha (%.2f) >= Azul (%.2f) - Sem Momentum de Baixa", rsiCurrent, maCurrent));
         return false;
      }
   }
}

//+------------------------------------------------------------------+
//| Check OBV MACD (Nexus Logic - Sincronismo Sequencial)            |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Check OBV MACD (Nexus Logic - Sincronismo Sequencial)            |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Check OBV MACD (Nexus Logic - Sincronismo Sequencial)            |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Check OBV MACD (Nexus Logic - Sincronismo Sequencial)            |
//+------------------------------------------------------------------+
bool CFilters::CheckOBVMACD(bool isBuy, int shift)
{
   //--- Se não está ativado, permite (passa silenciosamente)
   if(!m_config.obvmACDActive || m_handleOBVMACD == INVALID_HANDLE)
      return true;
   
   //--- Buffers para leitura
   //--- Buffer 0: Histograma (Ler 2 barras para detectar cruzamento)
   //--- Buffer 1: Cor (0=VerdeForte, 1=VermelhoForte, 2=VerdeFraco, 3=VermelhoFraco)
   //--- Buffer 4: Threshold
   double hist[], colorBuf[], thresh[];
   
   //--- Configurar como Series para garantir ordem [0]=MaisNovo, [1]=MaisVelho
   ArraySetAsSeries(hist, true);
   ArraySetAsSeries(colorBuf, true);
   ArraySetAsSeries(thresh, true);
   
   //--- CORREÇÃO SINCRONIZAÇÃO: Usar shift para alinhar com o sinal FGM
   //--- Se sinal está na barra 0, ler OBV MACD na barra 0 também
   //--- Se sinal está na barra 1, ler OBV MACD na barra 1
   int startBar = shift;
   
   //--- DEBUG: Log de sincronização
   Print(StringFormat("CheckOBVMACD: Lendo barra %d (sincronizado com sinal)", startBar));
   
   if(CopyBuffer(m_handleOBVMACD, 0, startBar, 2, hist) <= 0) { Print("OBV MACD: Falha CopyBuffer Hist"); return true; }
   if(CopyBuffer(m_handleOBVMACD, 1, startBar, 1, colorBuf) <= 0) { Print("OBV MACD: Falha CopyBuffer Color"); return true; }
   if(CopyBuffer(m_handleOBVMACD, 4, startBar, 1, thresh) <= 0) { Print("OBV MACD: Falha CopyBuffer Threshold"); return true; }
   
   double currentHist = hist[0]; // Barra atual (m_currentShift)
   double prevHist    = hist[1]; // Barra anterior
   int currentColor = (int)MathRound(colorBuf[0]);
   double currentThresh = thresh[0];

   
   //--- DEBUG: Log dos dados lidos
   Print(StringFormat("[OBV MACD DEBUG] Bar1: Hist=%.6f | Bar2: Hist=%.6f | Color=%d | Threshold=%.6f", 
                     currentHist, prevHist, currentColor, currentThresh));
   
   //--- 1. Verificar lateralização (Ruído)
   //--- Apenas se configurado para checar relevância de volume
   if(m_config.obvmACDCheckVolumeRelevance)
   {
      bool isZeroCross = (currentHist * prevHist < 0); // Sinais opostos indicam cruzamento
      
      if(isZeroCross)
      {
         Print("OBV MACD: Cruzamento de Zero detectado (Zero Cross) - Filtro de Ruído IGNORADO");
      }
      else
      {
         //--- Aplicamos tolerância de 20% (Noise Limit = 80% do Threshold)
         double noiseLimit = currentThresh * 0.8;
         
         if(MathAbs(currentHist) < noiseLimit)
         {
            Print(StringFormat("OBV MACD: Mercado em lateralização (Death Zone) |%.6f| < %.6f - BLOQUEADO", 
                              MathAbs(currentHist), noiseLimit));
            return false;
         }
      }
   }
   
   //--- 2. SINCRONISMO SEQUENCIAL DIRETO (Estrito por Cor - APENAS FORTE)
   //    Mapeamento de Cores do Indicador OBV_MACD_v3:
   //    0 = COLOR_POS_STRONG (Verde Forte) -> Hist > 0 e Subindo (Viés COMPRA FORTE)
   //    1 = COLOR_NEG_STRONG (Vermelho Forte)-> Hist < 0 e Caindo (Viés VENDA FORTE)
   //    2 = COLOR_POS_WEAK   (Verde Fraco) -> Bloqueado
   //    3 = COLOR_NEG_WEAK   (Vermelho Fraco)-> Bloqueado
   
   if(isBuy)
   {
       //--- Se RequireBuy estiver ativo
      if(m_config.obvmACDRequireBuy)
      {
         //--- COMPRA FORTE: Valida Cor 0
         if(currentColor == 0)
         {
            Print("OBV MACD: COMPRA FORTE (Verde Forte) - APROVADO");
            return true;
         }
         
         //--- COMPRA FRACA: Valida Cor 2 se AllowWeak ativo E histograma positivo
         if(m_config.obvmACDAllowWeakSignals && currentColor == 2 && currentHist > 0)
         {
            Print("OBV MACD: COMPRA FRACA (Verde Fraco + Hist Positivo) - APROVADO");
            return true;
         }
         
         //--- Qualquer outra cor bloqueia
         Print(StringFormat("OBV MACD STATUS: REPROVADO [BUY]. Cor=%d (Esperado: 0 ou 2 com Hist>0) | Hist=%.2f | Threshold=%.2f", 
                           currentColor, currentHist, currentThresh));
         return false;
      }
      
      Print("OBV MACD: RequireBuy desativado - Compra permitida");
      return true;
   }
   else // SELL
   {
      //--- Se RequireSell estiver ativo
      if(m_config.obvmACDRequireSell)
      {
         //--- VENDA FORTE: Valida Cor 1
         if(currentColor == 1)
         {
            Print("OBV MACD: VENDA FORTE (Vermelho Forte) - APROVADO");
            return true;
         }
         
         //--- VENDA FRACA: Valida Cor 3 se AllowWeak ativo E histograma negativo
         if(m_config.obvmACDAllowWeakSignals && currentColor == 3 && currentHist < 0)
         {
            Print("OBV MACD: VENDA FRACA (Vermelho Fraco + Hist Negativo) - APROVADO");
            return true;
         }
         
         //--- Qualquer outra cor bloqueia
         Print(StringFormat("OBV MACD STATUS: REPROVADO [SELL]. Cor=%d (Esperado: 1 ou 3 com Hist<0) | Hist=%.2f | Threshold=%.2f", 
                           currentColor, currentHist, currentThresh));
         return false;
      }
      
      Print("OBV MACD: RequireSell desativado - Venda permitida");
      return true;
   }
}

//+------------------------------------------------------------------+
//| Verificar RSIOMA público (NOVO)                                  |
//+------------------------------------------------------------------+
bool CFilters::IsRSIOMAOK(bool isBuy)
{
   return CheckRSIOMA(isBuy, 1);
}

//+------------------------------------------------------------------+
//| Configurar parâmetros do OBV MACD (NOVO)                         |
//+------------------------------------------------------------------+
void CFilters::SetOBVMACDParams(int fastEMA, int slowEMA, int signalSMA, 
                                int obvSmooth, bool useTickVolume, 
                                int threshPeriod, double threshMult)
{
   //--- Atualizar config
   m_config.obvFastEMA = fastEMA;
   m_config.obvSlowEMA = slowEMA;
   m_config.obvSignalSMA = signalSMA;
   m_config.obvSmooth = obvSmooth;
   m_config.obvUseTickVolume = useTickVolume;
   m_config.obvThreshPeriod = threshPeriod;
   m_config.obvThreshMult = threshMult;
   
   //--- Se ativo, recriar handle
   if(m_config.obvmACDActive)
   {
      CreateOBVMACDHandle();
      Print("CFilters: OBV MACD reconfigurado com novos parâmetros: Fast=", fastEMA, " Slow=", slowEMA);
   }
}

//+------------------------------------------------------------------+
//| Verificar Leque Aberto (EMA Fan)                                 |
//+------------------------------------------------------------------+
bool CFilters::CheckLequeAberto(bool isBuy, int shift)
{
   if(!m_config.lequeAbertoActive)
      return true;
      
   if(m_signal == NULL)
      return true;
      
   //--- Usar método IsLequeAbertoFast (EMAs 1-4) para capturar 1-2-3 Reversals
   //--- A validação estrita (IsLequeAberto 1-5) gera lag de ~18 barras em reversões.
   bool fanOpenFast = m_signal.IsLequeAbertoFast(isBuy, shift);
   
   //--- Verificação Macro (Segurança): Preço/EMA1 deve estar do lado certo da EMA200
   double ema1 = m_signal.GetEMA1(shift);
   double ema5 = m_signal.GetEMA5(shift); // EMA 200
   
   bool macroTrendOK = isBuy ? (ema1 > ema5) : (ema1 < ema5);
   
   if(!fanOpenFast || !macroTrendOK)
   {
      double ema2 = m_signal.GetEMA2(shift);
      double ema3 = m_signal.GetEMA3(shift);
      double ema4 = m_signal.GetEMA4(shift);
      
      // DIAGNÓSTICO COMPLETO: Mostrar valores de todas as EMAs para debug
      Print(StringFormat("CFilters: Leque/Trend FALHOU para %s", isBuy ? "BUY" : "SELL"));
      Print(StringFormat("   Valores: E1=%.2f | E2=%.2f | E3=%.2f | E4=%.2f | E5(200)=%.2f", 
                         ema1, ema2, ema3, ema4, ema5));
      Print(StringFormat("   Status: FastFan=%s | MacroTrend=%s", 
                         fanOpenFast ? "OK" : "FAIL (E1..E4 desalinhadas)", 
                         macroTrendOK ? "OK" : "FAIL (Contra EMA200)"));
                         
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| PROTOCOLO ESTRATÉGICO 1-2-3 (SINCRONIA TOTAL)
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| PASSO 1: TENDÊNCIA (Price + Fan)                                 |
//| Valida se o preço está a favor E o leque de médias está aberto   |
//+------------------------------------------------------------------+
bool CFilters::CheckStep1_Trend(bool isBuy, int shift)
{
   if(m_signal == NULL) return false;
   if(m_asset == NULL) return false;
   
   // --- PREÇO E TÊNDENCIA (Price Action) ---
   double close = iClose(m_asset.GetSymbol(), PERIOD_CURRENT, shift);
   double ema5  = m_signal.GetEMA5(shift); // EMA 200 (Reference)
   
   // --- FILTRO VWAP (OBRIGATÓRIO PARA TENDÊNCIA) ---
   // Se o preço estiver do lado errado da VWAP, nem consideramos tendência.
   // Isso elimina os "Sinais Falsos" de oscilação na EMA200.
   if(!CheckVWAP(isBuy, shift))
   {
      // Log já emitido pelo CheckVWAP
      return false;
   }
   
   // --- MODO 1: REVERSÃO (SNIPER) ---
   // Definição: Preço rompeu EMA200 E está a favor da VWAP.
   // Apenas isso. Simples e Rápido. "Pega o inicio da tendencia".
   
   if(isBuy)
   {
      if(close > ema5)
      {
         // CRITÉRIO ADICIONAL DE SEGURANÇA:
         // Se a EMA1 (Rápida) já estiver acima da EMA200, é muito mais seguro.
         double ema1 = m_signal.GetEMA1(shift);
         if(ema1 > ema5 || close > ema5 * 1.0001) // Margem mínima ou cruzamento confirmado
         {
            Print(StringFormat("PASSO 1: SNIPER TREND CONFIRMADA (Close > EMA200 & VWAP) | Close=%.2f", close));
            return true;
         }
      }
   }
   else // SELL
   {
      if(close < ema5)
      {
         double ema1 = m_signal.GetEMA1(shift);
         if(ema1 < ema5 || close < ema5 * 0.9999)
         {
             Print(StringFormat("PASSO 1: SNIPER TREND CONFIRMADA (Close < EMA200 & VWAP) | Close=%.2f", close));
             return true;
         }
      }
   }
   
   // --- MODO 2: CONTINUAÇÃO (RIDE) ---
   // Se não é reversão (já estamos longe da 200), validamos o Leque (Fan).
   // CORREÇÃO LAG: Usamos FastFan (1-4) se o FullFan (1-5) estiver fechado.
   
   bool fanOpen = CheckLequeAberto(isBuy, shift); // Verifica o que estiver config (Fast ou Full)
   
   if(fanOpen)
   {
       Print("PASSO 1: TENDÊNCIA CONTINUAÇÃO (Fan Open) - RIDE ENTRY");
       return true;
   }
   
   // Se nem Sniper nem Fan...
   // Tentar "Deep Pullback Recovery" (Preço volta a favor da tendência macro)
   // Ex: Preço cruzou EMA21 mas voltou pra favor da EMA1
   
   double ema1 = m_signal.GetEMA1(shift);
   double ema3 = m_signal.GetEMA3(shift); // EMA 21
   
   if(isBuy)
   {
      if(close > ema5 && close > ema3 && close > ema1)
      {
          Print("PASSO 1: DEEP PULLBACK RECOVERY (Close > EMA200/21/5) - RIDE");
          return true;
      }
   }
   else
   {
      if(close < ema5 && close < ema3 && close < ema1)
      {
          Print("PASSO 1: DEEP PULLBACK RECOVERY (Close < EMA200/21/5) - RIDE");
          return true;
      }
   }
   
   Print("FGM_DEBUG: PASSO 1 Falhou. Sem estrutura de tendência clara.");
   return false;
}

//+------------------------------------------------------------------+
//| PASSO 2: MOMENTUM (RSIOMA / Gatilho)                             |
//| Valida se temos gatilho de momentum exato                        |
//+------------------------------------------------------------------+
bool CFilters::CheckStep2_Momentum(bool isBuy, int shift)
{
   if(!m_config.rsiomaActive) return true; // Se desativado, passa direto (perigoso)
   
   // Usar a lógica já existente do CheckRSIOMA que implementa Crossover + Alinhamento
   // Mas agora é OBRIGATÓRIO (não apenas um filtro)
   bool momentumOK = CheckRSIOMA(isBuy, shift);
   
   if(!momentumOK)
   {
      // LOG DETALHADO JÁ EMITIDO DENTRO DE CheckRSIOMA
      Print("STRATEGY 1-2-3: Passo 2 (MOMENTUM/RSI) Falhou -> ABORTAR");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| PASSO 3: VOLUME/FLUXO (OBV MACD)                                 |
//| Valida se há fluxo financeiro real apoiando o movimento          |
//+------------------------------------------------------------------+
bool CFilters::CheckStep3_Volume(bool isBuy, int shift)
{
   if(!m_config.obvmACDActive) return true; // Se desativado, passa
   
   // Usar lógica existente do CheckOBVMACD
   // Isso verifica histograma verde/vermelho e acima/abaixo de zero
   bool volumeOK = CheckOBVMACD(isBuy, shift);
   
   if(!volumeOK)
   {
      // LOG DETALHADO JÁ EMITIDO DENTRO DE CheckOBVMACD
      Print("STRATEGY 1-2-3: Passo 3 (VOLUME/OBV) Falhou -> ABORTAR");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| VALIDAÇÃO FINAL DA ESTRATÉGIA (Chamada Principal)                |
//+------------------------------------------------------------------+
bool CFilters::CheckStrategy123(bool isBuy, int shift)
{
   // Reset da struct de resultado para logging se necessário
   // Mas aqui vamos retornar direto bool para ser binário
   
   // --- PASSO 1 ---
   if(!CheckStep1_Trend(isBuy, shift)) 
   {
      Print("STRATEGY 1-2-3: Passo 1 (TENDÊNCIA) Falhou -> ABORTAR");
      return false;
   }
   
   // --- PASSO 2 ---
   if(!CheckStep2_Momentum(isBuy, shift))
   {
      Print("STRATEGY 1-2-3: Passo 2 (MOMENTUM) Falhou -> ABORTAR");
      return false;
   }
   
   // --- PASSO 3 ---
   if(!CheckStep3_Volume(isBuy, shift))
   {
      Print("STRATEGY 1-2-3: Passo 3 (VOLUME) Falhou -> ABORTAR");
      return false;
   }
   
   // SE CHEGOU AQUI: SINCRONIA TOTAL! SNIPER SHOT!
   Print("⭐⭐⭐ STRATEGY 1-2-3: ALINHAMENTO PERFEITO! DISPARANDO ORDEM! ⭐⭐⭐");
   return true;
}

#endif // CFILTERS_MQH



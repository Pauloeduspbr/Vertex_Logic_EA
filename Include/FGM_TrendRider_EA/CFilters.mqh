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
#include "COBVMACD.mqh"

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
   //    Lembrando: no indicador FGM, confluência ALTA (75-100%) = EMAs comprimidas = mercado lateral
   //                confluência BAIXA (10-25%) = EMAs afastadas = tendência forte.
   //    Aqui usamos o MESMO conceito do EA: bloquear somente quando a confluência
   //    ultrapassa um limite máximo configurado por força do sinal.
   double   confluenceMaxF3;     // Confluência MÁXIMA aceitável para força 3 (0 = ignorar)
   double   confluenceMaxF4;     // Confluência MÁXIMA aceitável para força 4 (0 = ignorar)
   double   confluenceMaxF5;     // Confluência MÁXIMA aceitável para força 5 (0 = ignorar)
   
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
   
   //--- OBV MACD (NOVO - Nexus Logic)
   COBVMACD*          m_obvmacd;        // Ponteiro para OBV MACD
   
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
   bool               CheckRSIOMA(bool isBuy);  // NOVO
   bool               CheckOBVMACD(bool isBuy); // NOVO
   void               UpdateCooldown();
   
public:
                      CFilters();
                     ~CFilters();
   
   //--- Inicialização
   bool               Init(CAssetSpecs* asset, CSignalFGM* signal, CRegimeDetector* regime);
   void               Deinit();
   bool               IsInitialized() { return m_initialized; }
   string             GetLastError() { return m_lastError; }
   
   //--- Configuração
   void               SetConfig(const FilterConfig& config);
   FilterConfig       GetConfig() { return m_config; }
   void               SetDefaultConfig();
   void               SetOBVMACDParams(int fastEMA, int slowEMA, int signalSMA, 
                                       int obvSmooth, bool useTickVolume, 
                                       int threshPeriod, double threshMult);
   
   //--- Verificação principal
   FilterResult       CheckAll(bool isBuy, int minStrength, bool skipPhaseFilter = false);
   bool               PassesAllFilters(bool isBuy, int minStrength, bool skipPhaseFilter = false);
   
   //--- Verificações individuais (públicas)
   bool               IsSpreadOK();
   bool               IsSlopeOK(bool isBuy);
   bool               IsVolumeOK(int strength);
   bool               IsConfluenceOK(int strength);
   bool               IsPhaseOK(bool isBuy);
   bool               IsStrengthOK(int minStrength);
   bool               IsEMA200OK(bool isBuy);
   bool               IsCooldownOK(int strength);
   
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
   bool               IsRSIOMAOK(bool isBuy); // NOVO
   
   //--- OnTick para atualizar cooldown
   void               OnNewBar();
   
   //--- Debug
   void               PrintFilterStatus(bool isBuy, int minStrength);
};

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
   m_obvmacd = NULL;
   m_cooldownCounter = 0;
   m_lastBarTime = 0;
   m_lastStopTime = 0;
   
   ArraySetAsSeries(m_bufferVolumeMA, true);
   ArraySetAsSeries(m_bufferRSI, true);
   ArraySetAsSeries(m_bufferRSIMA, true);
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
      //--- Parâmetros: RSI_Period, MA_Period, MA_Method, HighLevel, LowLevel, ShowLevels
      m_handleRSI = iCustom(m_asset.GetSymbol(), PERIOD_CURRENT, 
                            "FGM_TrendRider_EA\\RSIOMA_v2HHLSX_MT5",
                            m_config.rsiomaPeriod,           // RSI_Period
                            m_config.rsiomaMA_Period,        // MA_Period
                            m_config.rsiomaMA_Method,        // MA_Method
                            (double)m_config.rsiomaOverbought, // HighLevel
                            (double)m_config.rsiomaOversold,   // LowLevel
                            true);                           // ShowLevels
      
      if(m_handleRSI == INVALID_HANDLE)
      {
         Print("CFilters: Aviso - Não foi possível criar handle RSIOMA customizado");
         Print("CFilters: Erro: ", GetLastError());
         // Não falha, apenas desativa o filtro
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
   
   //--- Inicializar OBV MACD (NOVO - Nexus Logic)
   if(m_config.obvmACDActive)
   {
      m_obvmacd = new COBVMACD();
      if(m_obvmacd != NULL)
      {
         //--- Parâmetros padrão (serão atualizados pelo EA via SetOBVMACDParams)
         if(!m_obvmacd.Init(m_asset.GetSymbol(), PERIOD_CURRENT, 12, 26, 9, 5, true, 34, 0.6))
         {
            Print("CFilters: Aviso - Não foi possível inicializar OBV MACD");
            Print("CFilters: Erro: ", m_obvmacd.GetLastError());
            delete m_obvmacd;
            m_obvmacd = NULL;
            m_config.obvmACDActive = false;
         }
         else
         {
            Print("CFilters: OBV MACD Filter ativado com parâmetros padrão (serão atualizados pelo EA)");
         }
      }
   }
   
   m_initialized = true;
   Print("CFilters: Inicializado com sucesso");
   
   return true;
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
   if(m_obvmacd != NULL)
   {
      m_obvmacd.Deinit();
      delete m_obvmacd;
      m_obvmacd = NULL;
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
   //    NOTA: O EA já valida confluência com seus próprios inputs (Inp_MaxConf_F3/F4/F5)
   //    ANTES de chamar CFilters. Portanto, usamos 100.0 como padrão aqui para 
   //    evitar bloqueio duplo. O EA pode sobrescrever esses valores via SetConfig().
   m_config.confluenceMaxF3 = 100.0;   // Padrão: não bloquear (EA já validou)
   m_config.confluenceMaxF4 = 100.0;   // Padrão: não bloquear (EA já validou)
   m_config.confluenceMaxF5 = 100.0;   // Padrão: não bloquear (EA já validou)
   
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
   
   //--- RSIOMA Filter (NOVO)
   m_config.rsiomaActive = false;           // Desativado por padrão
   m_config.rsiomaPeriod = 14;              // Período RSI padrão
   m_config.rsiomaMA_Period = 9;            // Período MA do RSI
   m_config.rsiomaMA_Method = MODE_SMA;     // Média simples
   m_config.rsiomaOverbought = 70;          // Nível sobrecompra
   m_config.rsiomaOversold = 30;            // Nível sobrevenda
   m_config.rsiomaCheckMidLevel = true;     // Verificar nível 50
   m_config.rsiomaCheckCrossover = false;   // Não verificar cruzamento por padrão
   m_config.rsiomaConfirmBars = 1;          // Padrão: apenas 1 barra (comportamento atual)
   
   //--- OBV MACD Filter (NOVO - Nexus Logic)
   m_config.obvmACDActive = false;          // Desativado por padrão
   m_config.obvmACDRequireBuy = false;      // Não exigir compra por padrão
   m_config.obvmACDRequireSell = false;     // Não exigir venda por padrão
   m_config.obvmACDAllowWeakSignals = true; // Permitir sinais fracos por padrão
   m_config.obvmACDCheckVolumeRelevance = false; // Não verificar volume relevante por padrão
}

//+------------------------------------------------------------------+
//| Definir configuração                                             |
//+------------------------------------------------------------------+
void CFilters::SetConfig(const FilterConfig& config)
{
   //--- Verificar se RSIOMA foi ativado e precisa criar handle
   bool needsRSIHandle = (config.rsiomaActive && m_handleRSI == INVALID_HANDLE);
   
   //--- Verificar se OBV MACD foi ativado e precisa inicializar
   bool needsOBVMACD = (config.obvmACDActive && m_obvmacd == NULL);
   
   m_config = config;
   
   //--- Criar handle RSIOMA se foi ativado agora
   if(needsRSIHandle && m_asset != NULL)
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
         Print("CFilters: Aviso - Não foi possível criar handle RSIOMA");
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
   
   //--- Inicializar OBV MACD se foi ativado agora (NOVO)
   if(needsOBVMACD && m_asset != NULL)
   {
      m_obvmacd = new COBVMACD();
      if(m_obvmacd != NULL)
      {
         //--- Parâmetros padrão (serão atualizados pelo EA via SetOBVMACDParams)
         if(!m_obvmacd.Init(m_asset.GetSymbol(), PERIOD_CURRENT, 12, 26, 9, 5, true, 34, 0.6))
         {
            Print("CFilters: Aviso - Não foi possível inicializar OBV MACD em SetConfig");
            Print("CFilters: Erro: ", m_obvmacd.GetLastError());
            delete m_obvmacd;
            m_obvmacd = NULL;
            m_config.obvmACDActive = false;
         }
         else
         {
            Print("CFilters: OBV MACD Filter ativado em SetConfig com parâmetros padrão (serão atualizados pelo EA)");
         }
      }
   }
   
   //--- DEBUG: Log da configuração recebida
   Print("CFilters::SetConfig - Confluência máxima configurada:");
   Print(StringFormat("  F3: %.1f%% | F4: %.1f%% | F5: %.1f%%", 
                      m_config.confluenceMaxF3, m_config.confluenceMaxF4, m_config.confluenceMaxF5));
   Print(StringFormat("  Slope ativo: %s | Volume ativo: %s | Cooldown: %d barras",
                      m_config.slopeActive ? "SIM" : "NÃO",
                      m_config.volumeActive ? "SIM" : "NÃO",
                      m_config.cooldownBarsAfterStop));
   Print(StringFormat("  RSIOMA ativo: %s | CheckMid: %s | CheckCross: %s | ConfirmBars: %d",
                      m_config.rsiomaActive ? "SIM" : "NÃO",
                      m_config.rsiomaCheckMidLevel ? "SIM" : "NÃO",
                      m_config.rsiomaCheckCrossover ? "SIM" : "NÃO",
                      m_config.rsiomaConfirmBars));
   Print(StringFormat("  OBV MACD ativo: %s | RequireBuy: %s | RequireSell: %s | AllowWeak: %s",
                      m_config.obvmACDActive ? "SIM" : "NÃO",
                      m_config.obvmACDRequireBuy ? "SIM" : "NÃO",
                      m_config.obvmACDRequireSell ? "SIM" : "NÃO",
                      m_config.obvmACDAllowWeakSignals ? "SIM" : "NÃO"));
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
   
   //--- Ignorar para F4 e F5 (sinais fortes já confirmados pelo indicador)
   //--- O indicador FGM já analisa força da tendência com 5 EMAs
   if(strength >= 4)
      return true;
   
   //--- Obter volume atual
   long volumes[];
   if(CopyTickVolume(m_asset.GetSymbol(), PERIOD_CURRENT, 1, 1, volumes) <= 0)
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
   
   //--- Ler a confluência na MESMA barra usada pelo EA (shift 0)
   double confluence = m_signal.GetConfluence(0);

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
   Print(StringFormat("CFilters::CheckConfluence - F%d: Confluência=%.1f%% (máx=%.1f%%)", 
                      absStrength, confluence, maxConfluence));

   //--- Se maxConfluence <= 0, não aplicar filtro de confluência aqui
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
   
   int phase = (int)m_signal.GetPhase(0);
   
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
FilterResult CFilters::CheckAll(bool isBuy, int minStrength, bool skipPhaseFilter = false)
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
   
   //--- Obter valores atuais para o resultado
   result.currentSpread = GetCurrentSpread();
   result.currentSlope = GetCurrentSlope(isBuy);
   result.currentVolume = GetCurrentVolume();
   result.volumeMA = GetVolumeMA();
   
   if(m_signal != NULL)
   {
      // Sempre usar shift 0 para manter alinhamento com o EA (ProcessSignals)
      result.currentConfluence = m_signal.GetConfluence(0);
      //--- Usar valor absoluto - Strength é negativo para SELL
      result.currentStrength = (int)MathAbs(m_signal.GetStrength(0));
      result.currentPhase = (int)m_signal.GetPhase(0);
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
      // Agora a lógica bloqueia quando a confluência está ALTA demais (EMAs comprimidas = lateral).
      // Ajustamos a mensagem para refletir corretamente esse comportamento.
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
   result.rsiomaOK = CheckRSIOMA(isBuy);
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
   
   //--- OBV MACD Filter (NOVO - Nexus Logic com sincronismo sequencial)
   result.obvmACDOK = CheckOBVMACD(isBuy);
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
bool CFilters::PassesAllFilters(bool isBuy, int minStrength, bool skipPhaseFilter = false)
{
   FilterResult result = CheckAll(isBuy, minStrength, skipPhaseFilter);
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
   
   // Usar o MESMO shift 0 que é utilizado em CheckSlope/ProcessSignals
   // para manter o alinhamento dos logs com a lógica real do filtro.
   return m_signal.CalculateSlope(m_config.slopePeriod, 0);
}

//+------------------------------------------------------------------+
//| Obter volume atual                                               |
//+------------------------------------------------------------------+
double CFilters::GetCurrentVolume()
{
   if(m_asset == NULL)
      return 0;
   
   long volumes[];
   if(CopyTickVolume(m_asset.GetSymbol(), PERIOD_CURRENT, 1, 1, volumes) <= 0)
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
   
   if(CopyBuffer(m_handleVolumeMA, 0, 1, 1, m_bufferVolumeMA) <= 0)
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
bool CFilters::CheckRSIOMA(bool isBuy)
{
   //--- Se filtro desativado, passa
   if(!m_config.rsiomaActive)
      return true;
   
   if(m_handleRSI == INVALID_HANDLE)
      return true; // Se não conseguiu criar, permite trade
   
   //--- Número de barras para confirmar (mínimo 1, máximo 5)
   int confirmBars = MathMax(1, MathMin(5, m_config.rsiomaConfirmBars));
   
   //--- Arrays para ler múltiplas barras
   double rsiValues[], rsiMAValues[];
   ArraySetAsSeries(rsiValues, true);
   ArraySetAsSeries(rsiMAValues, true);
   
   //--- Copiar valores das últimas N barras (começando da barra 1 = fechada)
   //--- LEITURA DIRETA: buffer 0 = RSI (linha vermelha), buffer 1 = MA (linha azul)
   //--- Lemos exatamente como o indicador desenha para não haver divergência
   //--- entre o que o trader vê e o que o EA utiliza nos filtros.
   //--- DEBUG EXTRA: também vamos ler os valores brutos do próprio indicador
   //--- via CopyBuffer para a BARRA 1, para garantir que
   //--- não há nenhum deslocamento entre o cálculo interno do indicador e o
   //--- que é retornado pelo CopyBuffer.
   double dbgRSI_Bar1 = EMPTY_VALUE;
   double dbgRSIMA_Bar1 = EMPTY_VALUE;
   double tempRSI[1], tempRSIMA[1];
   if(CopyBuffer(m_handleRSI, 0, 1, 1, tempRSI) > 0)
      dbgRSI_Bar1 = tempRSI[0];
   if(CopyBuffer(m_handleRSI, 1, 1, 1, tempRSIMA) > 0)
      dbgRSIMA_Bar1 = tempRSIMA[0];

   if(CopyBuffer(m_handleRSI, 0, 1, confirmBars, rsiValues) < confirmBars)
      return true;
   if(CopyBuffer(m_handleRSI, 1, 1, confirmBars, rsiMAValues) < confirmBars)
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
      double diff = rsiValues[i] - rsiMAValues[i];
      string relation;
      if(diff >= 0.5)
         relation = "RSI > MA (ALTA CLARA)";
      else if(diff <= -0.5)
         relation = "RSI < MA (BAIXA CLARA)";
      else
         relation = "RSI ≈ MA (INDECISÃO)";
      
      Print("  Bar", i+1, " [", TimeToString(barTime, TIME_MINUTES), "]: ",
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
   
   //--- FILTRO 2B: RSI vs MA - Verificar DIREÇÃO do movimento
   //--- A MA atrasa em relação ao RSI, então verificar posição relativa não funciona bem
   //--- Em vez disso, verificamos se o RSI está se MOVENDO na direção correta:
   //--- Para SELL: RSI deve estar CAINDO (RSI barra atual < RSI barra anterior)
   //--- Para BUY: RSI deve estar SUBINDO (RSI barra atual > RSI barra anterior)
   //--- Isso é mais confiável do que exigir RSI < MA para SELL
   if(m_config.rsiomaCheckCrossover)
   {
      //--- Precisamos de pelo menos 2 barras para verificar direção
      if(confirmBars >= 2)
      {
         double rsiBar1 = rsiValues[0];  // Barra mais recente (fechada)
         double rsiBar2 = rsiValues[1];  // Barra anterior
         double maBar1 = rsiMAValues[0];
         
         double rsiChange = rsiBar1 - rsiBar2; // Positivo = subindo, Negativo = caindo
         
         Print("RSIOMA CROSSOVER: RSI Bar1=", DoubleToString(rsiBar1, 2), 
               " Bar2=", DoubleToString(rsiBar2, 2), 
               " Mudança=", DoubleToString(rsiChange, 2),
               " (", rsiChange > 0 ? "SUBINDO" : "CAINDO", ")");
         
         //--- Para BUY: RSI deve estar SUBINDO ou estável, E acima de 50 (já verificado antes)
         //--- Se RSI está caindo forte, não é bom para compra
         if(isBuy && rsiChange < -2.0)  // RSI caindo mais de 2 pontos
         {
            Print("RSIOMA FILTRO: BUY bloqueado - RSI CAINDO (", 
                  DoubleToString(rsiChange, 1), " pts) - momentum contrário");
            return false;
         }
         
         //--- Para SELL: RSI deve estar CAINDO ou estável, E abaixo de 50 (já verificado antes)
         //--- Se RSI está subindo forte, não é bom para venda
         if(!isBuy && rsiChange > 2.0)  // RSI subindo mais de 2 pontos
         {
            Print("RSIOMA FILTRO: SELL bloqueado - RSI SUBINDO (", 
                  DoubleToString(rsiChange, 1), " pts) - momentum contrário");
            return false;
         }
         
         //--- Log de aprovação
         if(isBuy)
            Print("RSIOMA CROSSOVER: BUY OK - RSI ", rsiChange >= 0 ? "subindo/estável" : "leve queda aceitável");
         else
            Print("RSIOMA CROSSOVER: SELL OK - RSI ", rsiChange <= 0 ? "caindo/estável" : "leve alta aceitável");
      }
   }
   
   //--- PASSOU em todos os filtros
   Print("RSIOMA FILTRO: ", isBuy ? "BUY" : "SELL", " APROVADO");
   
   return true;
}

//+------------------------------------------------------------------+
//| Check OBV MACD (Nexus Logic - Sincronismo Sequencial)            |
//+------------------------------------------------------------------+
bool CFilters::CheckOBVMACD(bool isBuy)
{
   //--- Se não está ativado, permite (passa silenciosamente)
   if(!m_config.obvmACDActive || m_obvmacd == NULL)
      return true;
   
   //--- Obter sinal do OBV MACD (barra fechada)
   ENUM_CUSTOM_SIGNAL signal = m_obvmacd.GetSignal(1);
   
   //--- DEBUG: Log do sinal obtido
   Print(StringFormat("OBV MACD GetSignal retornou: %d (SIGNAL_BUY=1, SIGNAL_SELL=-1, SIGNAL_HOLD_B=2, SIGNAL_HOLD_S=-2, SIGNAL_NONE=0)", signal));
   
   //--- Verificar se o mercado está em lateralização (ruído)
   if(m_obvmacd.IsSideways(1))
   {
      Print("OBV MACD: Mercado em lateralização (Death Zone) - BLOQUEADO");
      return false;
   }
   
   //--- Verificar se há volume relevante
   if(m_config.obvmACDCheckVolumeRelevance)
   {
      if(!m_obvmacd.IsVolumeRelevant(1))
      {
         Print("OBV MACD: Volume não relevante - BLOQUEADO");
         return false;
      }
   }
   
   //--- SINCRONISMO SEQUENCIAL com Sinal FGM
   //    A lógica é: OBV MACD deve estar em sincronismo com a intenção de compra/venda
   
   if(isBuy)
   {
      //--- Para COMPRA: Verificar se RequireBuy está ativado
      if(m_config.obvmACDRequireBuy)
      {
         //--- RequireBuy ativo: exigir sinal de COMPRA válido
         if(signal == SIGNAL_BUY)
         {
            Print("OBV MACD: COMPRA FORTE (Green Strong) - APROVADO para BUY");
            return true;
         }
         else if(signal == SIGNAL_HOLD_B && m_config.obvmACDAllowWeakSignals)
         {
            Print("OBV MACD: COMPRA ENFRAQUECENDO (Green Weak) - ACEITO para BUY (fraco)");
            return true;
         }
         else
         {
            Print("OBV MACD: RequireBuy ativo - Sem sinal de compra válido. Sinal: ", signal);
            return false;
         }
      }
      else
      {
         //--- RequireBuy inativo: permitir compra (validação silenciosa)
         Print("OBV MACD: RequireBuy desativado - Compra permitida (sem verificação OBV)");
         return true;
      }
   }
   else
   {
      //--- Para VENDA: Verificar se RequireSell está ativado
      if(m_config.obvmACDRequireSell)
      {
         //--- RequireSell ativo: exigir sinal de VENDA válido
         if(signal == SIGNAL_SELL)
         {
            Print("OBV MACD: VENDA FORTE (Red Strong) - APROVADO para SELL");
            return true;
         }
         else if(signal == SIGNAL_HOLD_S && m_config.obvmACDAllowWeakSignals)
         {
            Print("OBV MACD: VENDA ENFRAQUECENDO (Red Weak) - ACEITO para SELL (fraco)");
            return true;
         }
         else
         {
            Print("OBV MACD: RequireSell ativo - Sem sinal de venda válido. Sinal: ", signal);
            return false;
         }
      }
      else
      {
         //--- RequireSell inativo: permitir venda (validação silenciosa)
         Print("OBV MACD: RequireSell desativado - Venda permitida (sem verificação OBV)");
         return true;
      }
   }
}

//+------------------------------------------------------------------+
//| Verificar RSIOMA público (NOVO)                                  |
//+------------------------------------------------------------------+
bool CFilters::IsRSIOMAOK(bool isBuy)
{
   return CheckRSIOMA(isBuy);
}

//+------------------------------------------------------------------+
//| Configurar parâmetros do OBV MACD (NOVO)                         |
//+------------------------------------------------------------------+
void CFilters::SetOBVMACDParams(int fastEMA, int slowEMA, int signalSMA, 
                                int obvSmooth, bool useTickVolume, 
                                int threshPeriod, double threshMult)
{
   //--- Se OBV MACD já foi inicializado, reinicializar com novos parâmetros
   if(m_obvmacd != NULL && m_config.obvmACDActive)
   {
      m_obvmacd.Deinit();
      delete m_obvmacd;
      m_obvmacd = NULL;
      
      //--- Recriar com novos parâmetros
      m_obvmacd = new COBVMACD();
      if(m_obvmacd != NULL)
      {
         if(!m_obvmacd.Init(m_asset.GetSymbol(), PERIOD_CURRENT, 
                           fastEMA, slowEMA, signalSMA, obvSmooth, 
                           useTickVolume, threshPeriod, threshMult))
         {
            Print("CFilters: Aviso - Não foi possível reinicializar OBV MACD com novos parâmetros");
            Print("CFilters: Erro: ", m_obvmacd.GetLastError());
            delete m_obvmacd;
            m_obvmacd = NULL;
         }
         else
         {
            Print("CFilters: OBV MACD reconfigurado com novos parâmetros:");
            Print("  FastEMA: ", fastEMA, " SlowEMA: ", slowEMA, 
                  " SignalSMA: ", signalSMA, " ObvSmooth: ", obvSmooth);
         }
      }
   }
}

#endif // CFILTERS_MQH

#endif // CFILTERS_MQH

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                     CFilters.mqh |
//|                                 Copyright 2025, Pauloeduspbr     |
//|                      FGM Trend Rider - Versão Platina Final      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Pauloeduspbr"
#property version   "1.00"
#property strict

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
   bool     atrOK;               // ATR dentro do range
   bool     slopeOK;             // Slope adequado
   bool     volumeOK;            // Volume adequado
   bool     confluenceOK;        // Confluência adequada
   bool     phaseOK;             // Fase de mercado adequada
   bool     strengthOK;          // Força do sinal adequada
   bool     ema200OK;            // Preço vs EMA200
   bool     cooldownOK;          // Cooldown respeitado
   
   //--- Valores
   double   currentSpread;       // Spread atual
   double   currentATR;          // ATR atual
   double   currentSlope;        // Slope atual
   double   currentVolume;       // Volume atual
   double   volumeMA;            // Média do volume
   double   currentConfluence;   // Confluência atual
   int      currentStrength;     // Força atual
   int      currentPhase;        // Fase atual
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
   int      cooldownBarsAfterTP3;   // Barras após TP3 completo
   bool     cooldownIgnoreF5;    // Ignorar cooldown para força 5
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
   
   //--- Cooldown tracking
   int                m_cooldownCounter;    // Contador de barras em cooldown
   datetime           m_lastBarTime;        // Tempo da última barra processada
   datetime           m_lastStopTime;       // Tempo do último stop
   datetime           m_lastTP3Time;        // Tempo do último TP3
   
   //--- Métodos privados
   bool               CheckSpread();
   bool               CheckATR();
   bool               CheckSlope(bool isBuy);
   bool               CheckVolume(int strength);
   bool               CheckConfluence(int strength);
   bool               CheckPhase(bool isBuy);
   bool               CheckStrength(int minStrength);
   bool               CheckEMA200(bool isBuy);
   bool               CheckCooldown(int strength);
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
   
   //--- Verificação principal
   FilterResult       CheckAll(bool isBuy, int minStrength);
   bool               PassesAllFilters(bool isBuy, int minStrength);
   
   //--- Verificações individuais (públicas)
   bool               IsSpreadOK();
   bool               IsATROK();
   bool               IsSlopeOK(bool isBuy);
   bool               IsVolumeOK(int strength);
   bool               IsConfluenceOK(int strength);
   bool               IsPhaseOK(bool isBuy);
   bool               IsStrengthOK(int minStrength);
   bool               IsEMA200OK(bool isBuy);
   bool               IsCooldownOK(int strength);
   
   //--- Gestão de cooldown
   void               StartCooldownAfterStop();
   void               StartCooldownAfterTP3();
   void               ResetCooldown();
   bool               IsInCooldown();
   int                GetCooldownRemaining();
   
   //--- Valores atuais
   double             GetCurrentSpread();
   double             GetCurrentATR();
   double             GetCurrentSlope(bool isBuy = true);
   double             GetCurrentVolume();
   double             GetVolumeMA();
   
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
   m_cooldownCounter = 0;
   m_lastBarTime = 0;
   m_lastStopTime = 0;
   m_lastTP3Time = 0;
   
   ArraySetAsSeries(m_bufferVolumeMA, true);
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
   m_config.cooldownBarsAfterTP3 = 0;
   m_config.cooldownIgnoreF5 = true;
}

//+------------------------------------------------------------------+
//| Definir configuração                                             |
//+------------------------------------------------------------------+
void CFilters::SetConfig(const FilterConfig& config)
{
   m_config = config;
   
   //--- DEBUG: Log da configuração recebida
   Print("CFilters::SetConfig - Confluência máxima configurada:");
   Print(StringFormat("  F3: %.1f%% | F4: %.1f%% | F5: %.1f%%", 
                      m_config.confluenceMaxF3, m_config.confluenceMaxF4, m_config.confluenceMaxF5));
   Print(StringFormat("  Slope ativo: %s | Volume ativo: %s | Cooldown: %d barras",
                      m_config.slopeActive ? "SIM" : "NÃO",
                      m_config.volumeActive ? "SIM" : "NÃO",
                      m_config.cooldownBarsAfterStop));
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
//| Verificar ATR                                                    |
//+------------------------------------------------------------------+
bool CFilters::CheckATR()
{
   if(m_asset == NULL || m_regime == NULL)
      return true; // Se não tem detector de regime, assume OK
   
   double atr = m_regime.GetATR(1);
   
   double minATR = m_asset.GetATRMin();
   double maxATR = m_asset.GetATRMax();
   
   return (atr >= minATR && atr <= maxATR);
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
FilterResult CFilters::CheckAll(bool isBuy, int minStrength)
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
   result.currentATR = GetCurrentATR();
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
      result.failReason = StringFormat("Spread alto: %d (max: %d)", 
                                        (int)result.currentSpread, 
                                        m_asset.GetSpreadMax());
      return result;
   }
   
   result.atrOK = CheckATR();
   if(!result.atrOK)
   {
      result.passed = false;
      result.failReason = StringFormat("ATR fora do range: %.2f", result.currentATR);
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
   
   result.phaseOK = CheckPhase(isBuy);
   if(!result.phaseOK)
   {
      result.passed = false;
      result.failReason = StringFormat("Fase inadequada: %d para %s", 
                                        result.currentPhase, isBuy ? "COMPRA" : "VENDA");
      return result;
   }
   
   result.ema200OK = CheckEMA200(isBuy);
   if(!result.ema200OK)
   {
      result.passed = false;
      result.failReason = "Preço vs EMA200 inadequado";
      return result;
   }
   
   result.confluenceOK = CheckConfluence(result.currentStrength);
   if(!result.confluenceOK)
   {
      result.passed = false;
      // Agora a lógica bloqueia quando a confluência está ALTA demais (EMAs comprimidas = lateral).
      // Ajustamos a mensagem para refletir corretamente esse comportamento.
      result.failReason = StringFormat("Confluência ALTA demais (lateral): %.1f%%", result.currentConfluence);
      return result;
   }
   
   result.slopeOK = CheckSlope(isBuy);
   if(!result.slopeOK)
   {
      result.passed = false;
      result.failReason = StringFormat("Slope insuficiente: %.4f", result.currentSlope);
      return result;
   }
   
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
   
   //--- Todos os filtros passaram
   result.passed = true;
   result.failReason = "";
   
   return result;
}

//+------------------------------------------------------------------+
//| Verificar se passa todos os filtros (simplificado)               |
//+------------------------------------------------------------------+
bool CFilters::PassesAllFilters(bool isBuy, int minStrength)
{
   FilterResult result = CheckAll(isBuy, minStrength);
   return result.passed;
}

//+------------------------------------------------------------------+
//| Verificações individuais públicas                                |
//+------------------------------------------------------------------+
bool CFilters::IsSpreadOK()     { return CheckSpread(); }
bool CFilters::IsATROK()        { return CheckATR(); }
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
//| Iniciar cooldown após TP3                                        |
//+------------------------------------------------------------------+
void CFilters::StartCooldownAfterTP3()
{
   m_cooldownCounter = m_config.cooldownBarsAfterTP3;
   m_lastTP3Time = TimeCurrent();
   if(m_cooldownCounter > 0)
      Print("CFilters: Cooldown iniciado após TP3 - ", m_cooldownCounter, " barras");
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
//| Obter ATR atual                                                  |
//+------------------------------------------------------------------+
double CFilters::GetCurrentATR()
{
   if(m_regime == NULL)
      return 0;
   
   return m_regime.GetATR(1);
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
   Print("ATR:           ", result.atrOK ? "OK ✓" : "FALHOU ✗",
         " (", DoubleToString(result.currentATR, _Digits), ")");
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
   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+

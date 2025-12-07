//+------------------------------------------------------------------+
//|                                             CRegimeDetector.mqh  |
//|                                 Copyright 2025, Pauloeduspbr     |
//|                      FGM Trend Rider - Versão Platina Final      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Pauloeduspbr"
#property version   "1.00"
#property strict

#include "CAssetSpecs.mqh"

//+------------------------------------------------------------------+
//| Enumeração de Regime de Mercado                                  |
//+------------------------------------------------------------------+
enum ENUM_MARKET_REGIME
{
   REGIME_TRENDING,     // Mercado em tendência (normal)
   REGIME_RANGING,      // Mercado lateral/consolidação
   REGIME_VOLATILE      // Mercado volátil/explosivo
};

//+------------------------------------------------------------------+
//| Estrutura de resultado da detecção de regime                     |
//+------------------------------------------------------------------+
struct RegimeResult
{
   ENUM_MARKET_REGIME regime;          // Regime atual
   double             atrCurrent;      // ATR atual
   double             atrAverage;      // ATR médio
   double             atrRatio;        // Razão ATR (atual/média × 100)
   
   //--- Ajustes por regime
   int                minStrength;     // Força mínima ajustada
   double             lotMultiplier;   // Multiplicador de lote
   double             slMultiplier;    // Multiplicador de SL
   
   //--- Informações
   string             description;     // Descrição do regime
   bool               isValid;         // Dados válidos
};

//+------------------------------------------------------------------+
//| Estrutura de configuração do detector                            |
//+------------------------------------------------------------------+
struct RegimeConfig
{
   int                atrPeriod;       // Período do ATR
   int                atrMAPeriod;     // Período da média do ATR
   
   //--- Limiares
   double             rangingThreshold;   // ATR < X% da média = ranging
   double             volatileThreshold;  // ATR > X% da média = volatile
   
   //--- Ajustes para regime RANGING
   int                rangingMinStrength;
   double             rangingLotMult;
   double             rangingSLMult;
   
   //--- Ajustes para regime VOLATILE
   int                volatileMinStrength;
   double             volatileLotMult;
   double             volatileSLMult;
   
   //--- Ajustes para regime TRENDING (normal)
   int                trendingMinStrength;
   double             trendingLotMult;
   double             trendingSLMult;
};

//+------------------------------------------------------------------+
//| Classe de Detecção de Regime de Mercado                          |
//+------------------------------------------------------------------+
class CRegimeDetector
{
private:
   CAssetSpecs*       m_asset;          // Ponteiro para especificações
   RegimeConfig       m_config;         // Configuração
   bool               m_initialized;    // Flag de inicialização
   string             m_lastError;      // Último erro
   
   //--- Handles
   int                m_handleATR;      // Handle do ATR
   int                m_handleATRMA;    // Handle da MA do ATR (calculado)
   
   //--- Buffers
   double             m_bufferATR[];
   double             m_bufferATRMA[];
   
   //--- Cache
   RegimeResult       m_lastResult;
   datetime           m_lastCalcTime;
   
   //--- Métodos privados
   bool               CreateHandles();
   void               ReleaseHandles();
   double             CalculateATRMA(int period, int shift);
   
public:
                      CRegimeDetector();
                     ~CRegimeDetector();
   
   //--- Inicialização
   bool               Init(CAssetSpecs* asset);
   void               Deinit();
   bool               IsInitialized() { return m_initialized; }
   string             GetLastError() { return m_lastError; }
   
   //--- Configuração
   void               SetConfig(const RegimeConfig& config);
   RegimeConfig       GetConfig() { return m_config; }
   void               SetDefaultConfig();
   
   //--- Detecção principal
   RegimeResult       Detect(int shift = 1);
   ENUM_MARKET_REGIME GetCurrentRegime();
   bool               IsTrending();
   bool               IsRanging();
   bool               IsVolatile();
   
   //--- Obter ajustes
   int                GetMinStrength();
   double             GetLotMultiplier();
   double             GetSLMultiplier();
   
   //--- Dados de volatilidade
   double             GetATR(int shift = 1);
   double             GetATRAverage(int shift = 1);
   double             GetATRRatio(int shift = 1);
   
   //--- Utilitários
   string             GetRegimeString(ENUM_MARKET_REGIME regime);
   
   //--- Debug
   void               PrintRegimeInfo();
};

//+------------------------------------------------------------------+
//| Construtor                                                        |
//+------------------------------------------------------------------+
CRegimeDetector::CRegimeDetector()
{
   m_asset = NULL;
   m_initialized = false;
   m_lastError = "";
   m_handleATR = INVALID_HANDLE;
   m_handleATRMA = INVALID_HANDLE;
   m_lastCalcTime = 0;
   
   //--- Configurar buffers como series
   ArraySetAsSeries(m_bufferATR, true);
   ArraySetAsSeries(m_bufferATRMA, true);
   
   //--- Configuração padrão
   SetDefaultConfig();
   
   //--- Resultado inicial
   ZeroMemory(m_lastResult);
}

//+------------------------------------------------------------------+
//| Destrutor                                                         |
//+------------------------------------------------------------------+
CRegimeDetector::~CRegimeDetector()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Inicialização                                                     |
//+------------------------------------------------------------------+
bool CRegimeDetector::Init(CAssetSpecs* asset)
{
   if(asset == NULL || !asset.IsInitialized())
   {
      m_lastError = "CAssetSpecs inválido ou não inicializado";
      return false;
   }
   
   m_asset = asset;
   
   //--- Criar handles
   if(!CreateHandles())
      return false;
   
   m_initialized = true;
   Print("CRegimeDetector: Inicializado. ATR(", m_config.atrPeriod, ") MA(", m_config.atrMAPeriod, ")");
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinicialização                                                   |
//+------------------------------------------------------------------+
void CRegimeDetector::Deinit()
{
   ReleaseHandles();
   m_initialized = false;
}

//+------------------------------------------------------------------+
//| Criar handles de indicadores                                     |
//+------------------------------------------------------------------+
bool CRegimeDetector::CreateHandles()
{
   //--- Criar ATR
   m_handleATR = iATR(m_asset.GetSymbol(), PERIOD_CURRENT, m_config.atrPeriod);
   
   if(m_handleATR == INVALID_HANDLE)
   {
      m_lastError = StringFormat("Falha ao criar handle ATR. Erro: %d", GetLastError());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Liberar handles                                                  |
//+------------------------------------------------------------------+
void CRegimeDetector::ReleaseHandles()
{
   if(m_handleATR != INVALID_HANDLE)
   {
      IndicatorRelease(m_handleATR);
      m_handleATR = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Definir configuração padrão                                      |
//+------------------------------------------------------------------+
void CRegimeDetector::SetDefaultConfig()
{
   m_config.atrPeriod = 14;
   m_config.atrMAPeriod = 50;
   
   //--- Limiares
   m_config.rangingThreshold = 80.0;    // ATR < 80% da média
   m_config.volatileThreshold = 150.0;  // ATR > 150% da média
   
   //--- Ajustes RANGING
   m_config.rangingMinStrength = 4;
   m_config.rangingLotMult = 0.5;
   m_config.rangingSLMult = 1.0;
   
   //--- Ajustes VOLATILE
   m_config.volatileMinStrength = 5;
   m_config.volatileLotMult = 0.5;
   m_config.volatileSLMult = 2.0;
   
   //--- Ajustes TRENDING
   m_config.trendingMinStrength = 3;
   m_config.trendingLotMult = 1.0;
   m_config.trendingSLMult = 1.5;
}

//+------------------------------------------------------------------+
//| Definir configuração                                             |
//+------------------------------------------------------------------+
void CRegimeDetector::SetConfig(const RegimeConfig& config)
{
   m_config = config;
   
   //--- Recriar handles se período mudou
   if(m_initialized)
   {
      ReleaseHandles();
      CreateHandles();
   }
}

//+------------------------------------------------------------------+
//| Calcular média do ATR                                            |
//+------------------------------------------------------------------+
double CRegimeDetector::CalculateATRMA(int period, int shift)
{
   if(m_handleATR == INVALID_HANDLE)
      return 0;
   
   //--- Copiar ATR para cálculo
   double atrValues[];
   ArraySetAsSeries(atrValues, true);
   
   int copied = CopyBuffer(m_handleATR, 0, shift, period, atrValues);
   if(copied < period)
      return 0;
   
   //--- Calcular média simples
   double sum = 0;
   for(int i = 0; i < period; i++)
   {
      sum += atrValues[i];
   }
   
   return sum / period;
}

//+------------------------------------------------------------------+
//| Detecção principal                                               |
//+------------------------------------------------------------------+
RegimeResult CRegimeDetector::Detect(int shift = 1)
{
   RegimeResult result;
   ZeroMemory(result);
   result.isValid = false;
   result.regime = REGIME_TRENDING;
   result.lotMultiplier = 1.0;
   result.slMultiplier = 1.5;
   result.minStrength = 3;
   
   if(!m_initialized || m_handleATR == INVALID_HANDLE)
   {
      result.description = "Detector não inicializado";
      return result;
   }
   
   //--- Obter ATR atual
   if(CopyBuffer(m_handleATR, 0, shift, 1, m_bufferATR) <= 0)
   {
      result.description = "Falha ao copiar ATR";
      return result;
   }
   
   result.atrCurrent = m_bufferATR[0];
   
   //--- Calcular média do ATR
   result.atrAverage = CalculateATRMA(m_config.atrMAPeriod, shift);
   
   if(result.atrAverage <= 0)
   {
      result.description = "Média do ATR inválida";
      return result;
   }
   
   //--- Calcular razão
   result.atrRatio = (result.atrCurrent / result.atrAverage) * 100.0;
   
   //--- Classificar regime
   if(result.atrRatio < m_config.rangingThreshold)
   {
      result.regime = REGIME_RANGING;
      result.minStrength = m_config.rangingMinStrength;
      result.lotMultiplier = m_config.rangingLotMult;
      result.slMultiplier = m_config.rangingSLMult;
      result.description = StringFormat("Mercado Lateral (ATR %.1f%% da média)", result.atrRatio);
   }
   else if(result.atrRatio > m_config.volatileThreshold)
   {
      result.regime = REGIME_VOLATILE;
      result.minStrength = m_config.volatileMinStrength;
      result.lotMultiplier = m_config.volatileLotMult;
      result.slMultiplier = m_config.volatileSLMult;
      result.description = StringFormat("Mercado Volátil (ATR %.1f%% da média)", result.atrRatio);
   }
   else
   {
      result.regime = REGIME_TRENDING;
      result.minStrength = m_config.trendingMinStrength;
      result.lotMultiplier = m_config.trendingLotMult;
      result.slMultiplier = m_config.trendingSLMult;
      result.description = StringFormat("Mercado em Tendência (ATR %.1f%% da média)", result.atrRatio);
   }
   
   result.isValid = true;
   
   //--- Guardar no cache
   m_lastResult = result;
   m_lastCalcTime = TimeCurrent();
   
   return result;
}

//+------------------------------------------------------------------+
//| Obter regime atual                                               |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME CRegimeDetector::GetCurrentRegime()
{
   RegimeResult result = Detect(1);
   return result.regime;
}

//+------------------------------------------------------------------+
//| Verificar se está em tendência                                   |
//+------------------------------------------------------------------+
bool CRegimeDetector::IsTrending()
{
   return (GetCurrentRegime() == REGIME_TRENDING);
}

//+------------------------------------------------------------------+
//| Verificar se está lateral                                        |
//+------------------------------------------------------------------+
bool CRegimeDetector::IsRanging()
{
   return (GetCurrentRegime() == REGIME_RANGING);
}

//+------------------------------------------------------------------+
//| Verificar se está volátil                                        |
//+------------------------------------------------------------------+
bool CRegimeDetector::IsVolatile()
{
   return (GetCurrentRegime() == REGIME_VOLATILE);
}

//+------------------------------------------------------------------+
//| Obter força mínima ajustada                                      |
//+------------------------------------------------------------------+
int CRegimeDetector::GetMinStrength()
{
   RegimeResult result = Detect(1);
   return result.minStrength;
}

//+------------------------------------------------------------------+
//| Obter multiplicador de lote                                      |
//+------------------------------------------------------------------+
double CRegimeDetector::GetLotMultiplier()
{
   RegimeResult result = Detect(1);
   return result.lotMultiplier;
}

//+------------------------------------------------------------------+
//| Obter multiplicador de SL                                        |
//+------------------------------------------------------------------+
double CRegimeDetector::GetSLMultiplier()
{
   RegimeResult result = Detect(1);
   return result.slMultiplier;
}

//+------------------------------------------------------------------+
//| Obter ATR                                                        |
//+------------------------------------------------------------------+
double CRegimeDetector::GetATR(int shift = 1)
{
   if(m_handleATR == INVALID_HANDLE)
      return 0;
   
   if(CopyBuffer(m_handleATR, 0, shift, 1, m_bufferATR) <= 0)
      return 0;
   
   return m_bufferATR[0];
}

//+------------------------------------------------------------------+
//| Obter média do ATR                                               |
//+------------------------------------------------------------------+
double CRegimeDetector::GetATRAverage(int shift = 1)
{
   return CalculateATRMA(m_config.atrMAPeriod, shift);
}

//+------------------------------------------------------------------+
//| Obter razão do ATR                                               |
//+------------------------------------------------------------------+
double CRegimeDetector::GetATRRatio(int shift = 1)
{
   double atr = GetATR(shift);
   double atrMA = GetATRAverage(shift);
   
   if(atrMA <= 0)
      return 100.0;
   
   return (atr / atrMA) * 100.0;
}

//+------------------------------------------------------------------+
//| Obter string do regime                                           |
//+------------------------------------------------------------------+
string CRegimeDetector::GetRegimeString(ENUM_MARKET_REGIME regime)
{
   switch(regime)
   {
      case REGIME_TRENDING: return "TRENDING";
      case REGIME_RANGING:  return "RANGING";
      case REGIME_VOLATILE: return "VOLATILE";
      default:              return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Imprimir informações do regime (debug)                           |
//+------------------------------------------------------------------+
void CRegimeDetector::PrintRegimeInfo()
{
   RegimeResult result = Detect(1);
   
   Print("═══════════════════════════════════════════════════════════");
   Print("CRegimeDetector - Informações do Regime");
   Print("═══════════════════════════════════════════════════════════");
   Print("Válido:        ", result.isValid ? "SIM" : "NÃO");
   Print("───────────────────────────────────────────────────────────");
   Print("Regime:        ", GetRegimeString(result.regime));
   Print("Descrição:     ", result.description);
   Print("───────────────────────────────────────────────────────────");
   Print("ATR Atual:     ", DoubleToString(result.atrCurrent, _Digits));
   Print("ATR Média:     ", DoubleToString(result.atrAverage, _Digits));
   Print("ATR Ratio:     ", DoubleToString(result.atrRatio, 1), "%");
   Print("───────────────────────────────────────────────────────────");
   Print("Força Mín:     ", result.minStrength);
   Print("Mult. Lote:    ", DoubleToString(result.lotMultiplier, 2));
   Print("Mult. SL:      ", DoubleToString(result.slMultiplier, 2));
   Print("───────────────────────────────────────────────────────────");
   Print("Limiares:");
   Print("  Ranging:     < ", DoubleToString(m_config.rangingThreshold, 0), "%");
   Print("  Volatile:    > ", DoubleToString(m_config.volatileThreshold, 0), "%");
   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+

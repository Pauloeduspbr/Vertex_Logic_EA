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
   double             rangeCurrent;    // Range atual (High-Low)
   double             rangeAverage;    // Range médio
   double             rangeRatio;      // Razão Range (atual/média × 100)
   
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
   int                rangePeriod;     // Período para média do Range
   
   //--- Limiares
   double             rangingThreshold;   // Range < X% da média = ranging
   double             volatileThreshold;  // Range > X% da média = volatile
   
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
   
   //--- Cache
   RegimeResult       m_lastResult;
   datetime           m_lastCalcTime;
   
   //--- Métodos privados
   double             CalculateRangeMA(int period, int shift);
   
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
   double             GetRange(int shift = 1);
   double             GetRangeAverage(int shift = 1);
   double             GetRangeRatio(int shift = 1);
   
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
   m_lastCalcTime = 0;
   
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
   m_initialized = true;
   Print("CRegimeDetector: Inicializado. Range Period(", m_config.rangePeriod, ")");
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinicialização                                                   |
//+------------------------------------------------------------------+
void CRegimeDetector::Deinit()
{
   m_initialized = false;
}

//+------------------------------------------------------------------+
//| Definir configuração padrão                                      |
//+------------------------------------------------------------------+
void CRegimeDetector::SetDefaultConfig()
{
   m_config.rangePeriod = 14;
   
   //--- Limiares
   m_config.rangingThreshold = 80.0;    // Range < 80% da média
   m_config.volatileThreshold = 150.0;  // Range > 150% da média
   
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
}

//+------------------------------------------------------------------+
//| Calcular média do Range (High-Low)                               |
//+------------------------------------------------------------------+
double CRegimeDetector::CalculateRangeMA(int period, int shift)
{
   double sum = 0;
   int count = 0;
   
   for(int i = 0; i < period; i++)
   {
      double high = iHigh(m_asset.GetSymbol(), PERIOD_CURRENT, shift + i);
      double low = iLow(m_asset.GetSymbol(), PERIOD_CURRENT, shift + i);
      
      if(high > 0 && low > 0)
      {
         sum += (high - low);
         count++;
      }
   }
   
   if(count == 0) return 0;
   return sum / count;
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
   
   if(!m_initialized)
   {
      result.description = "Detector não inicializado";
      return result;
   }
   
   //--- Obter Range atual
   double high = iHigh(m_asset.GetSymbol(), PERIOD_CURRENT, shift);
   double low = iLow(m_asset.GetSymbol(), PERIOD_CURRENT, shift);
   
   if(high == 0 || low == 0)
   {
      result.description = "Falha ao obter preços";
      return result;
   }
   
   result.rangeCurrent = high - low;
   
   //--- Calcular média do Range
   result.rangeAverage = CalculateRangeMA(m_config.rangePeriod, shift);
   
   if(result.rangeAverage <= 0)
   {
      result.description = "Média do Range inválida";
      return result;
   }
   
   //--- Calcular razão
   result.rangeRatio = (result.rangeCurrent / result.rangeAverage) * 100.0;
   
   //--- Classificar regime
   if(result.rangeRatio < m_config.rangingThreshold)
   {
      result.regime = REGIME_RANGING;
      result.minStrength = m_config.rangingMinStrength;
      result.lotMultiplier = m_config.rangingLotMult;
      result.slMultiplier = m_config.rangingSLMult;
      result.description = StringFormat("Mercado Lateral (Range %.1f%% da média)", result.rangeRatio);
   }
   else if(result.rangeRatio > m_config.volatileThreshold)
   {
      result.regime = REGIME_VOLATILE;
      result.minStrength = m_config.volatileMinStrength;
      result.lotMultiplier = m_config.volatileLotMult;
      result.slMultiplier = m_config.volatileSLMult;
      result.description = StringFormat("Mercado Volátil (Range %.1f%% da média)", result.rangeRatio);
   }
   else
   {
      result.regime = REGIME_TRENDING;
      result.minStrength = m_config.trendingMinStrength;
      result.lotMultiplier = m_config.trendingLotMult;
      result.slMultiplier = m_config.trendingSLMult;
      result.description = StringFormat("Mercado em Tendência (Range %.1f%% da média)", result.rangeRatio);
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
//| Obter Range                                                      |
//+------------------------------------------------------------------+
double CRegimeDetector::GetRange(int shift = 1)
{
   double high = iHigh(m_asset.GetSymbol(), PERIOD_CURRENT, shift);
   double low = iLow(m_asset.GetSymbol(), PERIOD_CURRENT, shift);
   return high - low;
}

//+------------------------------------------------------------------+
//| Obter média do Range                                             |
//+------------------------------------------------------------------+
double CRegimeDetector::GetRangeAverage(int shift = 1)
{
   return CalculateRangeMA(m_config.rangePeriod, shift);
}

//+------------------------------------------------------------------+
//| Obter razão do Range                                             |
//+------------------------------------------------------------------+
double CRegimeDetector::GetRangeRatio(int shift = 1)
{
   double range = GetRange(shift);
   double rangeMA = GetRangeAverage(shift);
   
   if(rangeMA <= 0)
      return 100.0;
   
   return (range / rangeMA) * 100.0;
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
   Print("Range Atual:   ", DoubleToString(result.rangeCurrent, _Digits));
   Print("Range Média:   ", DoubleToString(result.rangeAverage, _Digits));
   Print("Range Ratio:   ", DoubleToString(result.rangeRatio, 1), "%");
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

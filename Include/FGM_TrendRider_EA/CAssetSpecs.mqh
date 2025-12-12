//+------------------------------------------------------------------+
//|                                                  CAssetSpecs.mqh |
//|                                 Copyright 2025, Pauloeduspbr     |
//|                      FGM Trend Rider - Versão Platina Final      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Pauloeduspbr"
#property version   "1.00"
#property strict

#ifndef CASSETSPECS_MQH
#define CASSETSPECS_MQH

//+------------------------------------------------------------------+
//| Enumerações de Tipo de Ativo                                     |
//+------------------------------------------------------------------+
enum ENUM_ASSET_TYPE
{
   ASSET_WIN,      // Mini Índice Bovespa (WIN/IND)
   ASSET_WDO,      // Mini Dólar (WDO/DOL)
   ASSET_FOREX,    // Forex (Majors e Crosses)
   ASSET_STOCK,    // Ações
   ASSET_COMMODITY,// Commodities
   ASSET_CRYPTO,   // Criptomoedas
   ASSET_UNKNOWN   // Tipo desconhecido
};

//+------------------------------------------------------------------+
//| Enumeração de Mercado                                            |
//+------------------------------------------------------------------+
enum ENUM_MARKET_TYPE
{
   MARKET_B3,      // B3 - Brasil
   MARKET_FOREX,   // Forex Internacional
   MARKET_OTHER    // Outros mercados
};

//+------------------------------------------------------------------+
//| Estrutura de Especificações do Ativo                             |
//+------------------------------------------------------------------+
struct AssetSpecsData
{
   string            symbol;              // Símbolo do ativo
   ENUM_ASSET_TYPE   assetType;           // Tipo do ativo
   ENUM_MARKET_TYPE  marketType;          // Tipo de mercado
   
   //--- Especificações de trade
   double            tickSize;            // Tamanho do tick
   double            tickValue;           // Valor do tick
   double            pointValue;          // Valor do ponto
   int               digits;              // Casas decimais
   
   //--- Limites de volume
   double            volumeMin;           // Volume mínimo
   double            volumeMax;           // Volume máximo
   double            volumeStep;          // Passo do volume
   
   //--- Limites de stops
   int               stopsLevel;          // Nível mínimo de stops em pontos
   int               freezeLevel;         // Nível de congelamento
   
   //--- Spread e custos
   double            spreadTypical;       // Spread típico
   
   //--- Horários
   bool              is24Hours;           // Opera 24 horas
   
   //--- Magic number
   int               assetCode;           // Código do ativo para magic number
};

//+------------------------------------------------------------------+
//| Classe de Especificações do Ativo                                |
//+------------------------------------------------------------------+
class CAssetSpecs
{
private:
   AssetSpecsData    m_specs;             // Dados das especificações
   bool              m_initialized;       // Flag de inicialização
   string            m_lastError;         // Último erro
   
   //--- Métodos privados de detecção
   ENUM_ASSET_TYPE   DetectAssetType(string symbol);
   ENUM_MARKET_TYPE  DetectMarketType(string symbol);
   int               GetAssetCode(ENUM_ASSET_TYPE type);
   void              LoadSymbolSpecs();
   
public:
                     CAssetSpecs();
                    ~CAssetSpecs();
   
   //--- Inicialização
   bool              Init(string symbol = NULL);
   bool              IsInitialized() { return m_initialized; }
   string            GetLastError() { return m_lastError; }
   
   //--- Getters - Identificação
   string            GetSymbol()        { return m_specs.symbol; }
   ENUM_ASSET_TYPE   GetAssetType()     { return m_specs.assetType; }
   ENUM_MARKET_TYPE  GetMarketType()    { return m_specs.marketType; }
   bool              IsB3()             { return m_specs.marketType == MARKET_B3; }
   bool              IsForex()          { return m_specs.marketType == MARKET_FOREX; }
   bool              IsWIN()            { return m_specs.assetType == ASSET_WIN; }
   bool              IsWDO()            { return m_specs.assetType == ASSET_WDO; }
   
   //--- Getters - Especificações de Trade
   double            GetTickSize()      { return m_specs.tickSize; }
   double            GetTickValue()     { return m_specs.tickValue; }
   double            GetPointValue()    { return m_specs.pointValue; }
   int               GetDigits()        { return m_specs.digits; }
   
   //--- Getters - Volume
   double            GetVolumeMin()     { return m_specs.volumeMin; }
   double            GetVolumeMax()     { return m_specs.volumeMax; }
   double            GetVolumeStep()    { return m_specs.volumeStep; }
   
   //--- Getters - Stops
   int               GetStopsLevel()    { return m_specs.stopsLevel; }
   int               GetFreezeLevel()   { return m_specs.freezeLevel; }
   
   //--- Getters - Parâmetros específicos
   int               GetAssetCode()     { return m_specs.assetCode; }
   
   //--- Funções de Normalização
   double            NormalizeLot(double lot);
   double            NormalizePrice(double price);
   double            NormalizeSL(double price, bool isBuy);
   double            NormalizeTP(double price, bool isBuy);
   
   //--- Conversões
   double            PointsToPrice(int points);
   int               PriceToPoints(double priceDiff);
   double            PipsToPoints(double pips);
   int               GetPipFactor();
   
   //--- Cálculos de Valor
   double            CalculateTickValue();
   double            CalculateLotValue(double lot, double priceChange);
   
   //--- Magic Number
   int               CalculateMagicNumber(int baseNumber, ENUM_TIMEFRAMES tf);
   int               GetTimeframeCode(ENUM_TIMEFRAMES tf);
   
   //--- Debug e Log
   string            GetAssetTypeString();
   string            GetMarketTypeString();
   void              PrintSpecs();
};

//+------------------------------------------------------------------+
//| Construtor                                                        |
//+------------------------------------------------------------------+
CAssetSpecs::CAssetSpecs()
{
   m_initialized = false;
   m_lastError = "";
   ZeroMemory(m_specs);
}

//+------------------------------------------------------------------+
//| Destrutor                                                         |
//+------------------------------------------------------------------+
CAssetSpecs::~CAssetSpecs()
{
}

//+------------------------------------------------------------------+
//| Inicialização                                                     |
//+------------------------------------------------------------------+
bool CAssetSpecs::Init(string symbol = NULL)
{
   //--- Usar símbolo atual se não especificado
   if(symbol == NULL || symbol == "")
      symbol = _Symbol;
   
   m_specs.symbol = symbol;
   
   //--- Detectar tipo do ativo
   m_specs.assetType = DetectAssetType(symbol);
   m_specs.marketType = DetectMarketType(symbol);
   m_specs.assetCode = GetAssetCode(m_specs.assetType);
   
   //--- Carregar especificações do símbolo
   LoadSymbolSpecs();
   
   //--- Validar especificações carregadas
   if(m_specs.tickSize <= 0 || m_specs.tickValue <= 0)
   {
      m_lastError = "Falha ao carregar especificações do símbolo: " + symbol;
      Print("CAssetSpecs Error: ", m_lastError);
      m_initialized = false;
      return false;
   }
   
   m_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Detectar tipo do ativo                                           |
//+------------------------------------------------------------------+
ENUM_ASSET_TYPE CAssetSpecs::DetectAssetType(string symbol)
{
   //--- Detecção automática baseada nas propriedades do símbolo (SEM HARDCODE)
   ENUM_SYMBOL_CALC_MODE calcMode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(symbol, SYMBOL_TRADE_CALC_MODE);
   
   //--- Forex
   if(calcMode == SYMBOL_CALC_MODE_FOREX || calcMode == SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE)
      return ASSET_FOREX;
      
   //--- Futuros (B3: WIN/WDO geralmente usam FUTURES ou EXCH_FUTURES)
   if(calcMode == SYMBOL_CALC_MODE_FUTURES || calcMode == SYMBOL_CALC_MODE_EXCH_FUTURES || 
      calcMode == SYMBOL_CALC_MODE_EXCH_FUTURES_FORTS)
   {
      // Tentar distinguir WIN/WDO pelo nome apenas se necessário para ajustes finos,
      // mas a lógica principal deve ser agnóstica.
      // Para manter compatibilidade com o resto do código que espera ASSET_WIN/WDO:
      string upper = symbol;
      StringToUpper(upper);
      if(StringFind(upper, "WIN") >= 0 || StringFind(upper, "IND") >= 0) return ASSET_WIN;
      if(StringFind(upper, "WDO") >= 0 || StringFind(upper, "DOL") >= 0) return ASSET_WDO;
      
      // Se for outro futuro, tratar como Commodity ou Stock dependendo do contexto,
      // ou criar um tipo genérico ASSET_FUTURE. Por enquanto, retornamos COMMODITY como fallback seguro.
      return ASSET_COMMODITY;
   }
   
   //--- CFDs (Indices, Stocks, Crypto)
   if(calcMode == SYMBOL_CALC_MODE_CFD)
   {
      // Tentar refinar
      string path = SymbolInfoString(symbol, SYMBOL_PATH);
      StringToUpper(path);
      
      if(StringFind(path, "CRYPTO") >= 0) return ASSET_CRYPTO;
      if(StringFind(path, "INDEX") >= 0) return ASSET_WIN; // Tratar índices como WIN (comportamento similar)
      if(StringFind(path, "STOCK") >= 0) return ASSET_STOCK;
      
      return ASSET_FOREX; // Fallback para CFD genérico
   }
   
   //--- Ações (Exchange Stocks)
   if(calcMode == SYMBOL_CALC_MODE_EXCH_STOCKS || calcMode == SYMBOL_CALC_MODE_EXCH_STOCKS_MOEX)
      return ASSET_STOCK;
      
   //--- Fallback para detecção por nome (apenas se calcMode falhar ou for genérico)
   string upper = symbol;
   StringToUpper(upper);
   
   if(StringFind(upper, "XAU") >= 0 || StringFind(upper, "XAG") >= 0) return ASSET_COMMODITY;
   if(StringFind(upper, "BTC") >= 0 || StringFind(upper, "ETH") >= 0) return ASSET_CRYPTO;
   
   return ASSET_UNKNOWN;
}

//+------------------------------------------------------------------+
//| Detectar tipo de mercado                                         |
//+------------------------------------------------------------------+
ENUM_MARKET_TYPE CAssetSpecs::DetectMarketType(string symbol)
{
   if(m_specs.assetType == ASSET_WIN || m_specs.assetType == ASSET_WDO || m_specs.assetType == ASSET_STOCK)
      return MARKET_B3; // Assumindo B3 para futuros e ações locais
   
   if(m_specs.assetType == ASSET_FOREX || m_specs.assetType == ASSET_COMMODITY || m_specs.assetType == ASSET_CRYPTO)
      return MARKET_FOREX; // Mercado internacional
   
   return MARKET_OTHER;
}

//+------------------------------------------------------------------+
//| Obter código do ativo para magic number                          |
//+------------------------------------------------------------------+
int CAssetSpecs::GetAssetCode(ENUM_ASSET_TYPE type)
{
   switch(type)
   {
      case ASSET_WIN:       return 1000;
      case ASSET_WDO:       return 2000;
      case ASSET_FOREX:     return 3000;
      case ASSET_STOCK:     return 4000;
      case ASSET_COMMODITY: return 5000;
      case ASSET_CRYPTO:    return 6000;
      default:              return 9000;
   }
}

//+------------------------------------------------------------------+
//| Carregar especificações do símbolo                               |
//+------------------------------------------------------------------+
void CAssetSpecs::LoadSymbolSpecs()
{
   string symbol = m_specs.symbol;
   
   //--- Especificações básicas do símbolo
   m_specs.tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   m_specs.tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   m_specs.pointValue = SymbolInfoDouble(symbol, SYMBOL_POINT);
   m_specs.digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   //--- Limites de volume
   m_specs.volumeMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   m_specs.volumeMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   m_specs.volumeStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   //--- Limites de stops
   m_specs.stopsLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   m_specs.freezeLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   
   //--- Spread atual
   m_specs.spreadTypical = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
}

//+------------------------------------------------------------------+
//| Normalizar lote                                                   |
//+------------------------------------------------------------------+
double CAssetSpecs::NormalizeLot(double lot)
{
   if(!m_initialized)
      return 0.0;
   
   //--- Aplicar limites
   lot = MathMax(m_specs.volumeMin, lot);
   lot = MathMin(m_specs.volumeMax, lot);
   // maxLot removido, usando volumeMax que é a propriedade correta do símbolo
   
   //--- Normalizar para o step
   if(m_specs.volumeStep > 0)
      lot = MathFloor(lot / m_specs.volumeStep) * m_specs.volumeStep;
   
   //--- Garantir que está dentro dos limites
   if(lot < m_specs.volumeMin)
      lot = m_specs.volumeMin;
   
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Normalizar preço                                                  |
//+------------------------------------------------------------------+
double CAssetSpecs::NormalizePrice(double price)
{
   if(!m_initialized)
      return price;
   
   //--- Normalizar para o tick size
   if(m_specs.tickSize > 0)
      price = MathRound(price / m_specs.tickSize) * m_specs.tickSize;
   
   return NormalizeDouble(price, m_specs.digits);
}

//+------------------------------------------------------------------+
//| Normalizar SL considerando stops level                           |
//+------------------------------------------------------------------+
double CAssetSpecs::NormalizeSL(double slPrice, bool isBuy)
{
   if(!m_initialized)
      return slPrice;
   
   double currentPrice = isBuy ? SymbolInfoDouble(m_specs.symbol, SYMBOL_BID) 
                               : SymbolInfoDouble(m_specs.symbol, SYMBOL_ASK);
   
   double minDistance = m_specs.stopsLevel * m_specs.pointValue;
   
   if(isBuy)
   {
      //--- SL deve estar abaixo do preço atual
      double maxSL = currentPrice - minDistance;
      if(slPrice > maxSL)
         slPrice = maxSL;
   }
   else
   {
      //--- SL deve estar acima do preço atual
      double minSL = currentPrice + minDistance;
      if(slPrice < minSL)
         slPrice = minSL;
   }
   
   return NormalizePrice(slPrice);
}

//+------------------------------------------------------------------+
//| Normalizar TP considerando stops level                           |
//+------------------------------------------------------------------+
double CAssetSpecs::NormalizeTP(double tpPrice, bool isBuy)
{
   if(!m_initialized)
      return tpPrice;
   
   double currentPrice = isBuy ? SymbolInfoDouble(m_specs.symbol, SYMBOL_ASK) 
                               : SymbolInfoDouble(m_specs.symbol, SYMBOL_BID);
   
   double minDistance = m_specs.stopsLevel * m_specs.pointValue;
   
   if(isBuy)
   {
      //--- TP deve estar acima do preço atual
      double minTP = currentPrice + minDistance;
      if(tpPrice < minTP)
         tpPrice = minTP;
   }
   else
   {
      //--- TP deve estar abaixo do preço atual
      double maxTP = currentPrice - minDistance;
      if(tpPrice > maxTP)
         tpPrice = maxTP;
   }
   
   return NormalizePrice(tpPrice);
}

//+------------------------------------------------------------------+
//| Converter pontos para preço                                      |
//+------------------------------------------------------------------+
double CAssetSpecs::PointsToPrice(int points)
{
   return points * m_specs.pointValue;
}

//+------------------------------------------------------------------+
//| Converter diferença de preço para pontos                         |
//+------------------------------------------------------------------+
int CAssetSpecs::PriceToPoints(double priceDiff)
{
   if(m_specs.pointValue <= 0)
      return 0;
   return (int)MathRound(MathAbs(priceDiff) / m_specs.pointValue);
}

//+------------------------------------------------------------------+
//| Converter pips para pontos                                       |
//+------------------------------------------------------------------+
double CAssetSpecs::PipsToPoints(double pips)
{
   int pipFactor = GetPipFactor();
   return pips * pipFactor;
}

//+------------------------------------------------------------------+
//| Obter fator de pip (para Forex com 5 dígitos = 10)               |
//+------------------------------------------------------------------+
int CAssetSpecs::GetPipFactor()
{
   if(m_specs.assetType == ASSET_FOREX)
   {
      //--- JPY pairs têm 3 dígitos, outros têm 5
      if(m_specs.digits == 3 || m_specs.digits == 2)
         return 1;
      else if(m_specs.digits == 5 || m_specs.digits == 4)
         return 10;
   }
   return 1;
}

//+------------------------------------------------------------------+
//| Calcular valor do tick atualizado                                |
//+------------------------------------------------------------------+
double CAssetSpecs::CalculateTickValue()
{
   if(!m_initialized)
      return 0;
   
   //--- Atualizar o tick value (pode mudar em Forex)
   double tickValue = SymbolInfoDouble(m_specs.symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickValue > 0)
      m_specs.tickValue = tickValue;
   
   return m_specs.tickValue;
}

//+------------------------------------------------------------------+
//| Calcular valor de uma mudança de preço para um lote              |
//+------------------------------------------------------------------+
double CAssetSpecs::CalculateLotValue(double lot, double priceChange)
{
   if(!m_initialized || m_specs.tickSize <= 0)
      return 0;
   
   double tickValue = CalculateTickValue();
   double ticks = priceChange / m_specs.tickSize;
   
   return lot * ticks * tickValue;
}

//+------------------------------------------------------------------+
//| Calcular Magic Number                                            |
//+------------------------------------------------------------------+
int CAssetSpecs::CalculateMagicNumber(int baseNumber, ENUM_TIMEFRAMES tf)
{
   int tfCode = GetTimeframeCode(tf);
   return baseNumber + m_specs.assetCode + tfCode;
}

//+------------------------------------------------------------------+
//| Obter código do timeframe para magic number                      |
//+------------------------------------------------------------------+
int CAssetSpecs::GetTimeframeCode(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return 1;
      case PERIOD_M5:  return 5;
      case PERIOD_M15: return 15;
      case PERIOD_M30: return 30;
      case PERIOD_H1:  return 60;
      case PERIOD_H4:  return 240;
      case PERIOD_D1:  return 1440;
      case PERIOD_W1:  return 10080;
      case PERIOD_MN1: return 43200;
      default:         return 0;
   }
}

//+------------------------------------------------------------------+
//| Obter string do tipo de ativo                                    |
//+------------------------------------------------------------------+
string CAssetSpecs::GetAssetTypeString()
{
   switch(m_specs.assetType)
   {
      case ASSET_WIN:       return "Mini Índice (WIN)";
      case ASSET_WDO:       return "Mini Dólar (WDO)";
      case ASSET_FOREX:     return "Forex";
      case ASSET_STOCK:     return "Ação";
      case ASSET_COMMODITY: return "Commodity";
      case ASSET_CRYPTO:    return "Cripto";
      default:              return "Desconhecido";
   }
}

//+------------------------------------------------------------------+
//| Obter string do tipo de mercado                                  |
//+------------------------------------------------------------------+
string CAssetSpecs::GetMarketTypeString()
{
   switch(m_specs.marketType)
   {
      case MARKET_B3:    return "B3";
      case MARKET_FOREX: return "Forex";
      default:           return "Outro";
   }
}

//+------------------------------------------------------------------+
//| Imprimir especificações (debug)                                  |
//+------------------------------------------------------------------+
void CAssetSpecs::PrintSpecs()
{
   Print("═══════════════════════════════════════════════════════════");
   Print("CAssetSpecs - ", m_specs.symbol);
   Print("═══════════════════════════════════════════════════════════");
   Print("Tipo: ", GetAssetTypeString(), " | Mercado: ", GetMarketTypeString());
   Print("───────────────────────────────────────────────────────────");
   Print("Tick Size:  ", DoubleToString(m_specs.tickSize, 8));
   Print("Tick Value: ", DoubleToString(m_specs.tickValue, 4));
   Print("Point:      ", DoubleToString(m_specs.pointValue, 8));
   Print("Digits:     ", m_specs.digits);
   Print("───────────────────────────────────────────────────────────");
   Print("Volume Min:  ", m_specs.volumeMin);
   Print("Volume Max:  ", m_specs.volumeMax);
   Print("Volume Step: ", m_specs.volumeStep);
   Print("───────────────────────────────────────────────────────────");
   Print("Stops Level:  ", m_specs.stopsLevel);
   Print("Freeze Level: ", m_specs.freezeLevel);
   Print("───────────────────────────────────────────────────────────");
   Print("Asset Code:  ", m_specs.assetCode);
   Print("═══════════════════════════════════════════════════════════");
}

#endif // CASSETSPECS_MQH

//+------------------------------------------------------------------+

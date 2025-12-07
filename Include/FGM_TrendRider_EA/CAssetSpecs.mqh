//+------------------------------------------------------------------+
//|                                                  CAssetSpecs.mqh |
//|                                 Copyright 2025, Pauloeduspbr     |
//|                      FGM Trend Rider - Versão Platina Final      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Pauloeduspbr"
#property version   "1.00"
#property strict

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
   int               spreadMaxAllowed;    // Spread máximo permitido
   
   //--- Horários
   bool              is24Hours;           // Opera 24 horas
   string            sessionStart;        // Início da sessão
   string            sessionEnd;          // Fim da sessão
   
   //--- Parâmetros específicos
   double            atrMinValid;         // ATR mínimo válido
   double            atrMaxValid;         // ATR máximo válido
   double            slopeMinRequired;    // Slope mínimo requerido
   int               slMin;               // Stop loss mínimo
   int               slMax;               // Stop loss máximo
   int               beOffset;            // Offset do break-even
   double            maxLot;              // Lote máximo
   
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
   void              SetDefaultsForAssetType();
   
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
   double            GetMaxLot()        { return m_specs.maxLot; }
   
   //--- Getters - Stops
   int               GetStopsLevel()    { return m_specs.stopsLevel; }
   int               GetFreezeLevel()   { return m_specs.freezeLevel; }
   
   //--- Getters - Parâmetros específicos
   double            GetATRMin()        { return m_specs.atrMinValid; }
   double            GetATRMax()        { return m_specs.atrMaxValid; }
   double            GetSlopeMin()      { return m_specs.slopeMinRequired; }
   int               GetSLMin()         { return m_specs.slMin; }
   int               GetSLMax()         { return m_specs.slMax; }
   int               GetBEOffset()      { return m_specs.beOffset; }
   int               GetSpreadMax()     { return m_specs.spreadMaxAllowed; }
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
   
   //--- Definir valores padrão específicos do tipo
   SetDefaultsForAssetType();
   
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
   string upper = symbol;
   StringToUpper(upper);
   
   //--- Mini Índice B3
   if(StringFind(upper, "WIN") >= 0 || StringFind(upper, "IND") >= 0)
      return ASSET_WIN;
   
   //--- Mini Dólar B3
   if(StringFind(upper, "WDO") >= 0 || StringFind(upper, "DOL") >= 0)
      return ASSET_WDO;
   
   //--- Forex - Detectar por pares de moedas
   string currencies[] = {"USD", "EUR", "GBP", "JPY", "AUD", "NZD", "CAD", "CHF"};
   int currencyCount = 0;
   
   for(int i = 0; i < ArraySize(currencies); i++)
   {
      if(StringFind(upper, currencies[i]) >= 0)
         currencyCount++;
   }
   
   //--- Se contém 2 moedas, provavelmente é Forex
   if(currencyCount >= 2)
      return ASSET_FOREX;
   
   //--- Verificar se é moeda exótica com USD
   string exotics[] = {"MXN", "ZAR", "TRY", "BRL", "PLN", "HUF", "CZK", "SEK", "NOK", "DKK"};
   for(int i = 0; i < ArraySize(exotics); i++)
   {
      if(StringFind(upper, exotics[i]) >= 0 && currencyCount >= 1)
         return ASSET_FOREX;
   }
   
   //--- Criptomoedas
   string cryptos[] = {"BTC", "ETH", "XRP", "LTC", "BCH", "ADA", "DOT", "LINK"};
   for(int i = 0; i < ArraySize(cryptos); i++)
   {
      if(StringFind(upper, cryptos[i]) >= 0)
         return ASSET_CRYPTO;
   }
   
   //--- Commodities
   string commodities[] = {"XAUUSD", "XAGUSD", "GOLD", "SILVER", "OIL", "WTI", "BRENT", "NATGAS"};
   for(int i = 0; i < ArraySize(commodities); i++)
   {
      if(StringFind(upper, commodities[i]) >= 0)
         return ASSET_COMMODITY;
   }
   
   return ASSET_UNKNOWN;
}

//+------------------------------------------------------------------+
//| Detectar tipo de mercado                                         |
//+------------------------------------------------------------------+
ENUM_MARKET_TYPE CAssetSpecs::DetectMarketType(string symbol)
{
   if(m_specs.assetType == ASSET_WIN || m_specs.assetType == ASSET_WDO)
      return MARKET_B3;
   
   if(m_specs.assetType == ASSET_FOREX)
      return MARKET_FOREX;
   
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
//| Definir valores padrão por tipo de ativo                         |
//+------------------------------------------------------------------+
void CAssetSpecs::SetDefaultsForAssetType()
{
   switch(m_specs.assetType)
   {
      case ASSET_WIN:
         m_specs.spreadMaxAllowed = 25;    // Pontos
         m_specs.atrMinValid = 50;         // Pontos
         m_specs.atrMaxValid = 400;        // Pontos
         m_specs.slopeMinRequired = 2.0;   // Pontos por barra
         m_specs.slMin = 80;               // Pontos
         m_specs.slMax = 250;              // Pontos
         m_specs.beOffset = 10;            // Pontos
         m_specs.maxLot = 50;              // Contratos
         m_specs.is24Hours = false;
         m_specs.sessionStart = "09:00";
         m_specs.sessionEnd = "18:00";
         break;
         
      case ASSET_WDO:
         m_specs.spreadMaxAllowed = 4;     // Pontos
         m_specs.atrMinValid = 3;          // Pontos
         m_specs.atrMaxValid = 20;         // Pontos
         m_specs.slopeMinRequired = 0.3;   // Pontos por barra
         m_specs.slMin = 4;                // Pontos
         m_specs.slMax = 12;               // Pontos
         m_specs.beOffset = 1;             // Pontos
         m_specs.maxLot = 20;              // Contratos
         m_specs.is24Hours = false;
         m_specs.sessionStart = "09:00";
         m_specs.sessionEnd = "18:00";
         break;
         
      case ASSET_FOREX:
         m_specs.spreadMaxAllowed = 25;    // Points (2.5 pips para 5 dígitos)
         m_specs.atrMinValid = 80;         // Points (8 pips)
         m_specs.atrMaxValid = 800;        // Points (80 pips)
         m_specs.slopeMinRequired = 5.0;   // Points (0.5 pips) por barra
         m_specs.slMin = 150;              // Points (15 pips)
         m_specs.slMax = 500;              // Points (50 pips)
         m_specs.beOffset = 20;            // Points (2 pips)
         m_specs.maxLot = 1.0;             // Lotes
         m_specs.is24Hours = true;
         m_specs.sessionStart = "00:00";
         m_specs.sessionEnd = "23:59";
         break;
         
      default:
         //--- Valores conservadores para ativos desconhecidos
         m_specs.spreadMaxAllowed = 50;
         m_specs.atrMinValid = 10;
         m_specs.atrMaxValid = 1000;
         m_specs.slopeMinRequired = 1.0;
         m_specs.slMin = 50;
         m_specs.slMax = 500;
         m_specs.beOffset = 5;
         m_specs.maxLot = 1.0;
         m_specs.is24Hours = true;
         m_specs.sessionStart = "00:00";
         m_specs.sessionEnd = "23:59";
         break;
   }
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
   lot = MathMin(m_specs.maxLot, lot);
   
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
   Print("Max Lot:     ", m_specs.maxLot);
   Print("───────────────────────────────────────────────────────────");
   Print("Stops Level:  ", m_specs.stopsLevel);
   Print("Freeze Level: ", m_specs.freezeLevel);
   Print("Spread Max:   ", m_specs.spreadMaxAllowed);
   Print("───────────────────────────────────────────────────────────");
   Print("ATR Min:     ", m_specs.atrMinValid);
   Print("ATR Max:     ", m_specs.atrMaxValid);
   Print("Slope Min:   ", m_specs.slopeMinRequired);
   Print("SL Min:      ", m_specs.slMin);
   Print("SL Max:      ", m_specs.slMax);
   Print("BE Offset:   ", m_specs.beOffset);
   Print("───────────────────────────────────────────────────────────");
   Print("Asset Code:  ", m_specs.assetCode);
   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+

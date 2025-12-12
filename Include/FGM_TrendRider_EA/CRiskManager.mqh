//+------------------------------------------------------------------+
//|                                                 CRiskManager.mqh |
//|                                 Copyright 2025, Pauloeduspbr     |
//|                      FGM Trend Rider - Versão Platina Final      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Pauloeduspbr"
#property version   "1.00"
#property strict

#include "CAssetSpecs.mqh"

//+------------------------------------------------------------------+
//| Estrutura de parâmetros de risco                                 |
//+------------------------------------------------------------------+
struct RiskParams
{
   //--- Modo de lote
   int      lotMode;              // 0=Fixed, 1=RiskPercent
   double   fixedLot;             // Lote fixo (contratos B3 ou lotes Forex)
   
   //--- Risco base
   double   riskPercent;          // % do capital por trade
   
   //--- Multiplicadores por força
   double   riskMultF5;           // Multiplicador força 5
   double   riskMultF4;           // Multiplicador força 4
   double   riskMultF3;           // Multiplicador força 3
   
   //--- Limites de lote
   double   maxLotWIN;            // Máximo para WIN
   double   maxLotWDO;            // Máximo para WDO
   double   maxLotForex;          // Máximo para Forex
   
   //--- Stop Loss
   int      slMode;               // 0=Fixed, 1=ATR, 2=Swing, 3=Hybrid
   int      slFixedPoints;        // SL fixo em pontos (NOVO!)
   int      slMinPoints;          // SL mínimo em pontos (NOVO!)
   int      slMaxPoints;          // SL máximo em pontos (NOVO!)
   double   slATRMult;            // Multiplicador ATR normal
   double   slATRMultVolatile;    // Multiplicador ATR em regime volátil
   double   slBufferATR;          // Buffer adicional (fração do ATR)
   
   //--- Take Profit
   int      tpMode;               // 0=Fixed, 1=RR, 2=ATR
   int      tpFixedPoints;        // TP fixo em pontos
   double   tpATRMult;            // Multiplicador ATR para TP
   double   tp1RR;                // Risk:Reward TP1
   double   tp2RR;                // Risk:Reward TP2
   
   //--- Break-even
   bool     beActive;             // Ativar break-even
   int      beOffsetWIN;          // Offset WIN
   int      beOffsetWDO;          // Offset WDO
   int      beOffsetForex;        // Offset Forex (em points)
   
   //--- Proteção diária
   bool     dailyProtection;      // Proteção ativa
   double   maxDailyDD;           // DD diário máximo %
   int      maxConsecStops;       // Stops consecutivos máximo
};

//+------------------------------------------------------------------+
//| Estrutura de resultado do cálculo de posição                     |
//+------------------------------------------------------------------+
struct PositionCalcResult
{
   bool     isValid;              // Cálculo válido
   string   errorMessage;         // Mensagem de erro
   
   //--- Lote
   double   lotSize;              // Tamanho do lote calculado
   double   lotRaw;               // Lote antes de normalização
   
   //--- Stop Loss
   double   slPrice;              // Preço do stop loss
   double   slPoints;             // SL em pontos
   double   slValue;              // Valor monetário do SL
   
   //--- Take Profits
   double   tp1Price;             // Preço TP principal
   double   tp2Price;             // Preço TP2 (reserva)
   
   //--- Break-even
   double   bePrice;              // Preço do break-even
   double   beOffset;             // Offset do BE em pontos
   
   //--- Risco
   double   riskAmount;           // Valor em risco
   double   riskPercent;          // % do capital em risco
   double   rewardAmount;         // Potencial de ganho no TP
};

//+------------------------------------------------------------------+
//| Estrutura de proteção diária                                     |
//+------------------------------------------------------------------+
struct DailyProtectionData
{
   datetime currentDay;           // Dia atual
   double   startBalance;         // Saldo no início do dia
   double   currentDD;            // Drawdown atual em %
   int      consecutiveStops;     // Stops consecutivos
   int      totalTrades;          // Total de trades no dia
   int      winTrades;            // Trades vencedores
   int      lossTrades;           // Trades perdedores
   double   grossProfit;          // Lucro bruto
   double   grossLoss;            // Prejuízo bruto
   bool     isPaused;             // EA pausado por proteção
   string   pauseReason;          // Motivo da pausa
};

//+------------------------------------------------------------------+
//| Classe de Gestão de Risco                                        |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   CAssetSpecs*      m_asset;           // Ponteiro para especificações
   RiskParams        m_params;          // Parâmetros de risco
   DailyProtectionData m_daily;         // Dados de proteção diária
   bool              m_initialized;     // Flag de inicialização
   string            m_lastError;       // Último erro
   
   //--- Parâmetros
   int               m_atrPeriod; // Mantendo o nome para compatibilidade de config, mas é Range Period
   
   //--- Métodos privados
   double            GetAverageRange(int period, int shift = 1);
   double            FindSwingLow(int lookback = 3, int shift = 1);
   double            FindSwingHigh(int lookback = 3, int shift = 1);
   void              ResetDailyIfNewDay();
   
public:
                     CRiskManager();
                    ~CRiskManager();
   
   //--- Inicialização
   bool              Init(CAssetSpecs* asset, int atrPeriod = 14);
   void              Deinit();
   bool              IsInitialized() { return m_initialized; }
   string            GetLastError() { return m_lastError; }
   
   //--- Configuração de parâmetros
   void              SetRiskParams(const RiskParams& params);
   RiskParams        GetRiskParams() { return m_params; }
   
   //--- Cálculo de Lote
   double            CalculateLot(double slPoints, int strength, bool isVolatile = false);
   double            CalculateLotByRisk(double riskAmount, double slPoints);
   double            GetRiskMultiplier(int strength);
   
   //--- Cálculo de Stop Loss
   double            CalculateSL(bool isBuy, bool isVolatile = false);
   double            CalculateSLPoints(bool isBuy, bool isVolatile = false);
   double            CalculateSLByATR(bool isBuy, double atrMult);
   double            CalculateSLBySwing(bool isBuy, int lookback = 3);
   double            CalculateSLHybrid(bool isBuy, bool isVolatile = false);
   
   //--- Cálculo de Take Profit
   double            CalculateTP(double entryPrice, double slPoints, double rrRatio, bool isBuy);
   double            CalculateTP1(double entryPrice, double slPoints, bool isBuy);
   double            CalculateTP2(double entryPrice, double slPoints, bool isBuy);
   
   //--- Cálculo de Break-even
   double            CalculateBEPrice(double entryPrice, bool isBuy);
   int               GetBEOffset();
   

   
   //--- Cálculo completo da posição
   PositionCalcResult CalculatePosition(double entryPrice, bool isBuy, int strength, bool isVolatile = false);
   
   //--- Proteção Diária
   bool              CheckDailyProtection();
   void              UpdateDailyStats(double pnl, bool isWin);
   void              ResetDailyProtection();
   void              IncrementConsecutiveStops();
   void              ResetConsecutiveStops();
   bool              IsDailyPaused() { return m_daily.isPaused; }
   string            GetPauseReason() { return m_daily.pauseReason; }
   DailyProtectionData GetDailyData() { return m_daily; }
   
   //--- Validação
   bool              ValidateLot(double lot);
   bool              ValidateSL(double slPrice, double entryPrice, bool isBuy);
   bool              ValidateTP(double tpPrice, double entryPrice, bool isBuy);
   
   //--- Utilitários
   double            GetAccountBalance();
   double            GetAccountEquity();
   double            PointsToValue(double points, double lot);
   double            ValueToPoints(double value, double lot);
   
   //--- Debug
   void              PrintRiskInfo(const PositionCalcResult& result);
   void              PrintDailyStats();
};

//+------------------------------------------------------------------+
//| Construtor                                                        |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager()
{
   m_asset = NULL;
   m_initialized = false;
   m_lastError = "";
   m_atrPeriod = 14;
   
   //--- Parâmetros padrão
   m_params.lotMode = 0;  // Lote fixo por padrão
   m_params.fixedLot = 1.0;
   m_params.riskPercent = 1.0;
   m_params.riskMultF5 = 1.5;
   m_params.riskMultF4 = 1.0;
   m_params.riskMultF3 = 0.5;
   m_params.maxLotWIN = 50;
   m_params.maxLotWDO = 20;
   m_params.maxLotForex = 1.0;
   m_params.slMode = 0; // Fixed por padrão (respeitando input do usuário)
   m_params.slFixedPoints = 150;
   m_params.slMinPoints = 50;
   m_params.slMaxPoints = 500;
   m_params.slATRMult = 1.5;
   m_params.slATRMultVolatile = 2.0;
   m_params.slBufferATR = 0.3;
   m_params.tpMode = 1;  // RR por padrão
   m_params.tpFixedPoints = 300;
   m_params.tpATRMult = 3.0;
   m_params.tp1RR = 1.0;
   m_params.tp2RR = 2.0;
   m_params.beActive = true;
   m_params.beOffsetWIN = 10;
   m_params.beOffsetWDO = 1;
   m_params.beOffsetForex = 20;
   m_params.dailyProtection = true;
   m_params.maxDailyDD = 3.0;
   m_params.maxConsecStops = 3;
   
   //--- Inicializar proteção diária
   ZeroMemory(m_daily);
}

//+------------------------------------------------------------------+
//| Destrutor                                                         |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Inicialização                                                     |
//+------------------------------------------------------------------+
bool CRiskManager::Init(CAssetSpecs* asset, int atrPeriod = 14)
{
   if(asset == NULL || !asset.IsInitialized())
   {
      m_lastError = "CAssetSpecs inválido ou não inicializado";
      return false;
   }
   
   m_asset = asset;
   m_atrPeriod = atrPeriod;
   
   //--- Inicializar proteção diária
   ResetDailyProtection();
   
   m_initialized = true;
   Print("CRiskManager: Inicializado com sucesso. Range Period(", atrPeriod, ")");
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinicialização                                                   |
//+------------------------------------------------------------------+
void CRiskManager::Deinit()
{
   m_initialized = false;
}

//+------------------------------------------------------------------+
//| Definir parâmetros de risco                                      |
//+------------------------------------------------------------------+
void CRiskManager::SetRiskParams(const RiskParams& params)
{
   m_params = params;
}

//+------------------------------------------------------------------+
//| Obter valor do Range Médio (substituto do ATR)                   |
//+------------------------------------------------------------------+
double CRiskManager::GetAverageRange(int period, int shift = 1)
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
//| Encontrar swing low                                              |
//+------------------------------------------------------------------+
double CRiskManager::FindSwingLow(int lookback = 3, int shift = 1)
{
   double lows[];
   ArraySetAsSeries(lows, true);
   
   if(CopyLow(m_asset.GetSymbol(), PERIOD_CURRENT, shift, lookback, lows) <= 0)
      return 0;
   
   double lowest = lows[0];
   for(int i = 1; i < ArraySize(lows); i++)
   {
      if(lows[i] < lowest)
         lowest = lows[i];
   }
   
   return lowest;
}

//+------------------------------------------------------------------+
//| Encontrar swing high                                             |
//+------------------------------------------------------------------+
double CRiskManager::FindSwingHigh(int lookback = 3, int shift = 1)
{
   double highs[];
   ArraySetAsSeries(highs, true);
   
   if(CopyHigh(m_asset.GetSymbol(), PERIOD_CURRENT, shift, lookback, highs) <= 0)
      return 0;
   
   double highest = highs[0];
   for(int i = 1; i < ArraySize(highs); i++)
   {
      if(highs[i] > highest)
         highest = highs[i];
   }
   
   return highest;
}

//+------------------------------------------------------------------+
//| Obter multiplicador de risco por força                           |
//+------------------------------------------------------------------+
double CRiskManager::GetRiskMultiplier(int strength)
{
   switch(MathAbs(strength))
   {
      case 5: return m_params.riskMultF5;
      case 4: return m_params.riskMultF4;
      case 3: return m_params.riskMultF3;
      default: return 0.5;
   }
}

//+------------------------------------------------------------------+
//| Calcular lote                                                     |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLot(double slPoints, int strength, bool isVolatile = false)
{
   if(!m_initialized || m_asset == NULL)
      return 0;
   
   //--- MODO LOTE FIXO: retorna o lote configurado diretamente
   if(m_params.lotMode == 0)
   {
      double lot = m_params.fixedLot;
      
      //--- Aplicar limite máximo por tipo de ativo
      double maxLot = m_params.maxLotForex;
      if(m_asset.IsWIN())
         maxLot = m_params.maxLotWIN;
      else if(m_asset.IsWDO())
         maxLot = m_params.maxLotWDO;
      
      lot = MathMin(lot, maxLot);
      
      //--- Normalizar e retornar
      return m_asset.NormalizeLot(lot);
   }
   
   //--- MODO RISCO %: calcular lote baseado no risco
   if(slPoints <= 0)
      return 0;
   
   //--- Calcular risco base
   double balance = GetAccountBalance();
   double riskAmount = balance * (m_params.riskPercent / 100.0);
   
   //--- Aplicar multiplicador por força
   double riskMult = GetRiskMultiplier(strength);
   riskAmount *= riskMult;
   
   //--- Ajustar para regime volátil
   if(isVolatile)
      riskAmount *= 0.5;
   
   //--- Calcular lote
   double lot = CalculateLotByRisk(riskAmount, slPoints);
   
   return lot;
}

//+------------------------------------------------------------------+
//| Calcular lote pelo valor do risco                                |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotByRisk(double riskAmount, double slPoints)
{
   if(!m_initialized || m_asset == NULL || slPoints <= 0)
      return 0;
   
   //--- Calcular valor do SL em termos monetários
   double tickValue = m_asset.CalculateTickValue();
   double tickSize = m_asset.GetTickSize();
   
   if(tickValue <= 0 || tickSize <= 0)
      return 0;
   
   //--- Converter pontos para preço
   double slPrice = slPoints * m_asset.GetPointValue();
   
   //--- Calcular quantidade de ticks no SL
   double ticks = slPrice / tickSize;
   
   //--- Valor do SL por lote
   double slValuePerLot = ticks * tickValue;
   
   if(slValuePerLot <= 0)
      return 0;
   
   //--- Calcular lote
   double lot = riskAmount / slValuePerLot;
   
   //--- Aplicar limite máximo por tipo de ativo
   double maxLot = m_params.maxLotForex;
   if(m_asset.IsWIN())
      maxLot = m_params.maxLotWIN;
   else if(m_asset.IsWDO())
      maxLot = m_params.maxLotWDO;
   
   lot = MathMin(lot, maxLot);
   
   //--- Normalizar lote
   return m_asset.NormalizeLot(lot);
}

//+------------------------------------------------------------------+
//| Calcular SL em pontos                                            |
//+------------------------------------------------------------------+
double CRiskManager::CalculateSLPoints(bool isBuy, bool isVolatile = false)
{
   if(!m_initialized || m_asset == NULL)
      return 0;
   
   double slPoints = 0;
   
   switch(m_params.slMode)
   {
      case 0: // Fixed - USA O VALOR DO INPUT DIRETAMENTE
         slPoints = (double)m_params.slFixedPoints;
         break;
         
      case 1: // ATR
         {
            double atr = GetAverageRange(m_atrPeriod, 1);
            double mult = isVolatile ? m_params.slATRMultVolatile : m_params.slATRMult;
            slPoints = m_asset.PriceToPoints(atr * mult);
         }
         break;
         
      case 2: // Swing
         {
            double bid = SymbolInfoDouble(m_asset.GetSymbol(), SYMBOL_BID);
            double ask = SymbolInfoDouble(m_asset.GetSymbol(), SYMBOL_ASK);
            
            if(isBuy)
            {
               double swingLow = FindSwingLow(3, 1);
               slPoints = m_asset.PriceToPoints(bid - swingLow);
            }
            else
            {
               double swingHigh = FindSwingHigh(3, 1);
               slPoints = m_asset.PriceToPoints(swingHigh - ask);
            }
         }
         break;
         
      case 3: // Hybrid (ATR + Swing - usa o maior)
      default:
         {
            //--- Calcular por ATR
            double atr = GetAverageRange(m_atrPeriod, 1);
            double mult = isVolatile ? m_params.slATRMultVolatile : m_params.slATRMult;
            double slATRPoints = m_asset.PriceToPoints(atr * mult);
            
            //--- Calcular por Swing
            double bid = SymbolInfoDouble(m_asset.GetSymbol(), SYMBOL_BID);
            double ask = SymbolInfoDouble(m_asset.GetSymbol(), SYMBOL_ASK);
            double slSwingPoints = 0;
            
            if(isBuy)
            {
               double swingLow = FindSwingLow(3, 1);
               slSwingPoints = m_asset.PriceToPoints(bid - swingLow);
            }
            else
            {
               double swingHigh = FindSwingHigh(3, 1);
               slSwingPoints = m_asset.PriceToPoints(swingHigh - ask);
            }
            
            //--- Usar o MAIOR dos dois (mais conservador)
            slPoints = MathMax(slATRPoints, slSwingPoints);
         }
         break;
   }
   
   //--- Aplicar limites mínimo e máximo do INPUT
   slPoints = MathMax(slPoints, (double)m_params.slMinPoints);
   slPoints = MathMin(slPoints, (double)m_params.slMaxPoints);
   
   return slPoints;
}

//+------------------------------------------------------------------+
//| Calcular SL preço                                                |
//+------------------------------------------------------------------+
double CRiskManager::CalculateSL(bool isBuy, bool isVolatile = false)
{
   if(!m_initialized || m_asset == NULL)
      return 0;
   
   double slPoints = CalculateSLPoints(isBuy, isVolatile);
   double bid = SymbolInfoDouble(m_asset.GetSymbol(), SYMBOL_BID);
   double ask = SymbolInfoDouble(m_asset.GetSymbol(), SYMBOL_ASK);
   
   double slPrice;
   if(isBuy)
      slPrice = bid - (slPoints * m_asset.GetPointValue());
   else
      slPrice = ask + (slPoints * m_asset.GetPointValue());
   
   return m_asset.NormalizeSL(slPrice, isBuy);
}

//+------------------------------------------------------------------+
//| Calcular SL por ATR                                              |
//+------------------------------------------------------------------+
double CRiskManager::CalculateSLByATR(bool isBuy, double atrMult)
{
   if(!m_initialized || m_asset == NULL)
      return 0;
   
   double atr = GetAverageRange(m_atrPeriod, 1);
   if(atr <= 0)
      return 0;
   
   double slDistance = atr * atrMult;
   
   //--- Adicionar buffer
   slDistance += atr * m_params.slBufferATR;
   
   double bid = SymbolInfoDouble(m_asset.GetSymbol(), SYMBOL_BID);
   double ask = SymbolInfoDouble(m_asset.GetSymbol(), SYMBOL_ASK);
   
   double slPrice;
   if(isBuy)
      slPrice = bid - slDistance;
   else
      slPrice = ask + slDistance;
   
   return m_asset.NormalizeSL(slPrice, isBuy);
}

//+------------------------------------------------------------------+
//| Calcular SL por Swing                                            |
//+------------------------------------------------------------------+
double CRiskManager::CalculateSLBySwing(bool isBuy, int lookback = 3)
{
   if(!m_initialized || m_asset == NULL)
      return 0;
   
   double atr = GetAverageRange(m_atrPeriod, 1);
   double buffer = atr * m_params.slBufferATR;
   
   double slPrice;
   if(isBuy)
   {
      double swingLow = FindSwingLow(lookback, 1);
      slPrice = swingLow - buffer;
   }
   else
   {
      double swingHigh = FindSwingHigh(lookback, 1);
      slPrice = swingHigh + buffer;
   }
   
   return m_asset.NormalizeSL(slPrice, isBuy);
}

//+------------------------------------------------------------------+
//| Calcular SL Híbrido (ATR + Swing)                                |
//+------------------------------------------------------------------+
double CRiskManager::CalculateSLHybrid(bool isBuy, bool isVolatile = false)
{
   if(!m_initialized || m_asset == NULL)
      return 0;
   
   //--- Calcular SL por ATR
   double atrMult = isVolatile ? m_params.slATRMultVolatile : m_params.slATRMult;
   double slATR = CalculateSLByATR(isBuy, atrMult);
   
   //--- Calcular SL por Swing
   double slSwing = CalculateSLBySwing(isBuy, 3);
   
   //--- Usar o maior dos dois (mais conservador)
   double slPrice;
   if(isBuy)
      slPrice = MathMin(slATR, slSwing); // Mais baixo para compra
   else
      slPrice = MathMax(slATR, slSwing); // Mais alto para venda
   
   //--- Converter para distância em pontos e aplicar limites
   double bid = SymbolInfoDouble(m_asset.GetSymbol(), SYMBOL_BID);
   double ask = SymbolInfoDouble(m_asset.GetSymbol(), SYMBOL_ASK);
   
   double distance;
   if(isBuy)
      distance = bid - slPrice;
   else
      distance = slPrice - ask;
   
   double minDistance = m_asset.GetSLMin() * m_asset.GetPointValue();
   double maxDistance = m_asset.GetSLMax() * m_asset.GetPointValue();
   
   distance = MathMax(distance, minDistance);
   distance = MathMin(distance, maxDistance);
   
   //--- Recalcular preço com distância limitada
   if(isBuy)
      slPrice = bid - distance;
   else
      slPrice = ask + distance;
   
   return m_asset.NormalizeSL(slPrice, isBuy);
}

//+------------------------------------------------------------------+
//| Calcular Take Profit                                             |
//+------------------------------------------------------------------+
double CRiskManager::CalculateTP(double entryPrice, double slPoints, double rrRatio, bool isBuy)
{
   if(!m_initialized || m_asset == NULL)
      return 0;
   
   double tpDistance = slPoints * m_asset.GetPointValue() * rrRatio;
   
   double tpPrice;
   if(isBuy)
      tpPrice = entryPrice + tpDistance;
   else
      tpPrice = entryPrice - tpDistance;
   
   return m_asset.NormalizeTP(tpPrice, isBuy);
}

//+------------------------------------------------------------------+
//| Calcular TP1                                                     |
//+------------------------------------------------------------------+
double CRiskManager::CalculateTP1(double entryPrice, double slPoints, bool isBuy)
{
   return CalculateTP(entryPrice, slPoints, m_params.tp1RR, isBuy);
}

//+------------------------------------------------------------------+
//| Calcular TP2                                                     |
//+------------------------------------------------------------------+
double CRiskManager::CalculateTP2(double entryPrice, double slPoints, bool isBuy)
{
   return CalculateTP(entryPrice, slPoints, m_params.tp2RR, isBuy);
}

//+------------------------------------------------------------------+
//| Calcular preço do Break-even                                     |
//+------------------------------------------------------------------+
double CRiskManager::CalculateBEPrice(double entryPrice, bool isBuy)
{
   if(!m_initialized || m_asset == NULL)
      return entryPrice;
   
   int offset = GetBEOffset();
   double offsetPrice = offset * m_asset.GetPointValue();
   
   double bePrice;
   if(isBuy)
      bePrice = entryPrice + offsetPrice;
   else
      bePrice = entryPrice - offsetPrice;
   
   return m_asset.NormalizePrice(bePrice);
}

//+------------------------------------------------------------------+
//| Obter offset do break-even                                       |
//+------------------------------------------------------------------+
int CRiskManager::GetBEOffset()
{
   if(!m_initialized || m_asset == NULL)
      return 0;
   
   if(m_asset.IsWIN())
      return m_params.beOffsetWIN;
   else if(m_asset.IsWDO())
      return m_params.beOffsetWDO;
   else
      return m_params.beOffsetForex;
}

//+------------------------------------------------------------------+
//| Cálculo completo da posição                                      |
//+------------------------------------------------------------------+
PositionCalcResult CRiskManager::CalculatePosition(double entryPrice, bool isBuy, int strength, bool isVolatile = false)
{
   PositionCalcResult result;
   ZeroMemory(result);
   result.isValid = false;
   
   if(!m_initialized || m_asset == NULL)
   {
      result.errorMessage = "RiskManager não inicializado";
      return result;
   }
   
   //--- Calcular Stop Loss
   double slPoints = CalculateSLPoints(isBuy, isVolatile);
   if(slPoints <= 0)
   {
      result.errorMessage = "SL inválido";
      return result;
   }
   
   result.slPoints = slPoints;
   result.slPrice = CalculateSL(isBuy, isVolatile);
   
   //--- Calcular Lote
   double lot = CalculateLot(slPoints, strength, isVolatile);
   if(lot <= 0)
   {
      result.errorMessage = "Lote inválido";
      return result;
   }
   
   result.lotRaw = lot;
   result.lotSize = m_asset.NormalizeLot(lot);
   
   //--- Calcular Take Profits baseado no modo configurado
   double tpPoints = 0;
   
   switch(m_params.tpMode)
   {
      case 0: // Fixed - TP fixo em pontos
         tpPoints = (double)m_params.tpFixedPoints;
         break;
         
      case 1: // RR - Razão Risco/Retorno
         tpPoints = slPoints * m_params.tp1RR;  // TP baseado em R:R
         break;
         
      case 2: // ATR - Baseado em ATR
         {
            double atr = GetAverageRange(m_atrPeriod, 1);
            tpPoints = m_asset.PriceToPoints(atr * m_params.tpATRMult);
         }
         break;
         
      default:
         tpPoints = slPoints * m_params.tp1RR;
         break;
   }
   
   //--- Calcular preço do TP principal
   double tpDistance = tpPoints * m_asset.GetPointValue();
   if(isBuy)
      result.tp1Price = m_asset.NormalizeTP(entryPrice + tpDistance, isBuy);
   else
      result.tp1Price = m_asset.NormalizeTP(entryPrice - tpDistance, isBuy);
   
   //--- TP2 (reserva, mesmo valor que TP1 já que não usamos Triple Exit)
   result.tp2Price = result.tp1Price;
   
   //--- Calcular Break-even
   if(m_params.beActive)
   {
      result.bePrice = CalculateBEPrice(entryPrice, isBuy);
      result.beOffset = (double)GetBEOffset();
   }
   
   //--- Calcular valor do SL
   result.slValue = PointsToValue(slPoints, result.lotSize);
   
   //--- Calcular risco
   result.riskAmount = result.slValue;
   result.riskPercent = (result.riskAmount / GetAccountBalance()) * 100.0;
   
   //--- Calcular potencial de ganho (usando TP principal)
   double tpPointsCalc = (m_params.tpMode == 0) ? (double)m_params.tpFixedPoints : (slPoints * m_params.tp1RR);
   result.rewardAmount = PointsToValue(tpPointsCalc, result.lotSize);
   
   result.isValid = true;
   return result;
}

//+------------------------------------------------------------------+
//| Verificar proteção diária                                        |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDailyProtection()
{
   if(!m_params.dailyProtection)
      return true;
   
   ResetDailyIfNewDay();
   
   //--- Verificar drawdown
   double currentBalance = GetAccountBalance();
   double dd = ((m_daily.startBalance - currentBalance) / m_daily.startBalance) * 100.0;
   m_daily.currentDD = dd;
   
   if(dd >= m_params.maxDailyDD)
   {
      m_daily.isPaused = true;
      m_daily.pauseReason = StringFormat("Drawdown diário de %.2f%% excedeu limite de %.2f%%", 
                                          dd, m_params.maxDailyDD);
      Print("CRiskManager: ", m_daily.pauseReason);
      return false;
   }
   
   //--- Verificar stops consecutivos
   if(m_daily.consecutiveStops >= m_params.maxConsecStops)
   {
      m_daily.isPaused = true;
      m_daily.pauseReason = StringFormat("%d stops consecutivos atingidos (limite: %d)", 
                                          m_daily.consecutiveStops, m_params.maxConsecStops);
      Print("CRiskManager: ", m_daily.pauseReason);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Verificar se é um novo dia                                       |
//+------------------------------------------------------------------+
void CRiskManager::ResetDailyIfNewDay()
{
   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   
   if(today != m_daily.currentDay)
   {
      ResetDailyProtection();
   }
}

//+------------------------------------------------------------------+
//| Atualizar estatísticas diárias                                   |
//+------------------------------------------------------------------+
void CRiskManager::UpdateDailyStats(double pnl, bool isWin)
{
   m_daily.totalTrades++;
   
   if(isWin)
   {
      m_daily.winTrades++;
      m_daily.grossProfit += pnl;
      ResetConsecutiveStops();
   }
   else
   {
      m_daily.lossTrades++;
      m_daily.grossLoss += MathAbs(pnl);
      IncrementConsecutiveStops();
   }
}

//+------------------------------------------------------------------+
//| Reset proteção diária                                            |
//+------------------------------------------------------------------+
void CRiskManager::ResetDailyProtection()
{
   m_daily.currentDay = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   m_daily.startBalance = GetAccountBalance();
   m_daily.currentDD = 0;
   m_daily.consecutiveStops = 0;
   m_daily.totalTrades = 0;
   m_daily.winTrades = 0;
   m_daily.lossTrades = 0;
   m_daily.grossProfit = 0;
   m_daily.grossLoss = 0;
   m_daily.isPaused = false;
   m_daily.pauseReason = "";
   
   Print("CRiskManager: Proteção diária resetada. Saldo inicial: ", DoubleToString(m_daily.startBalance, 2));
}

//+------------------------------------------------------------------+
//| Incrementar stops consecutivos                                   |
//+------------------------------------------------------------------+
void CRiskManager::IncrementConsecutiveStops()
{
   m_daily.consecutiveStops++;
}

//+------------------------------------------------------------------+
//| Resetar stops consecutivos                                       |
//+------------------------------------------------------------------+
void CRiskManager::ResetConsecutiveStops()
{
   m_daily.consecutiveStops = 0;
}

//+------------------------------------------------------------------+
//| Validar lote                                                     |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateLot(double lot)
{
   if(!m_initialized || m_asset == NULL)
      return false;
   
   if(lot < m_asset.GetVolumeMin())
      return false;
   
   if(lot > m_asset.GetVolumeMax())
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Validar SL                                                       |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateSL(double slPrice, double entryPrice, bool isBuy)
{
   if(!m_initialized || m_asset == NULL)
      return false;
   
   if(isBuy && slPrice >= entryPrice)
      return false;
   
   if(!isBuy && slPrice <= entryPrice)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Validar TP                                                       |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateTP(double tpPrice, double entryPrice, bool isBuy)
{
   if(!m_initialized || m_asset == NULL)
      return false;
   
   if(isBuy && tpPrice <= entryPrice)
      return false;
   
   if(!isBuy && tpPrice >= entryPrice)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Obter saldo da conta                                             |
//+------------------------------------------------------------------+
double CRiskManager::GetAccountBalance()
{
   return AccountInfoDouble(ACCOUNT_BALANCE);
}

//+------------------------------------------------------------------+
//| Obter equity da conta                                            |
//+------------------------------------------------------------------+
double CRiskManager::GetAccountEquity()
{
   return AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Converter pontos para valor monetário                            |
//+------------------------------------------------------------------+
double CRiskManager::PointsToValue(double points, double lot)
{
   if(!m_initialized || m_asset == NULL || lot <= 0)
      return 0;
   
   double priceChange = points * m_asset.GetPointValue();
   return m_asset.CalculateLotValue(lot, priceChange);
}

//+------------------------------------------------------------------+
//| Converter valor monetário para pontos                            |
//+------------------------------------------------------------------+
double CRiskManager::ValueToPoints(double value, double lot)
{
   if(!m_initialized || m_asset == NULL || lot <= 0)
      return 0;
   
   double tickValue = m_asset.CalculateTickValue();
   double tickSize = m_asset.GetTickSize();
   
   if(tickValue <= 0 || tickSize <= 0)
      return 0;
   
   double priceChange = (value / lot) / (tickValue / tickSize);
   return priceChange / m_asset.GetPointValue();
}

//+------------------------------------------------------------------+
//| Imprimir informações de risco (debug)                            |
//+------------------------------------------------------------------+
void CRiskManager::PrintRiskInfo(const PositionCalcResult& result)
{
   Print("═══════════════════════════════════════════════════════════");
   Print("CRiskManager - Informações da Posição");
   Print("═══════════════════════════════════════════════════════════");
   Print("Válido: ", result.isValid ? "Sim" : ("Não - " + result.errorMessage));
   Print("───────────────────────────────────────────────────────────");
   Print("Lote Total:    ", DoubleToString(result.lotSize, 2));
   Print("  └─ Lote Raw: ", DoubleToString(result.lotRaw, 4));
   Print("───────────────────────────────────────────────────────────");
   Print("Stop Loss:     ", DoubleToString(result.slPrice, _Digits));
   Print("  └─ Pontos:   ", DoubleToString(result.slPoints, 0));
   Print("  └─ Valor:    ", DoubleToString(result.slValue, 2));
   Print("───────────────────────────────────────────────────────────");
   Print("Take Profit:   ", DoubleToString(result.tp1Price, _Digits));
   Print("───────────────────────────────────────────────────────────");
   Print("Break-even:    ", DoubleToString(result.bePrice, _Digits));
   Print("───────────────────────────────────────────────────────────");
   Print("Risco:         ", DoubleToString(result.riskAmount, 2), " (", DoubleToString(result.riskPercent, 2), "%)");
   Print("Potencial TP:  ", DoubleToString(result.rewardAmount, 2));
   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Imprimir estatísticas diárias                                    |
//+------------------------------------------------------------------+
void CRiskManager::PrintDailyStats()
{
   Print("═══════════════════════════════════════════════════════════");
   Print("CRiskManager - Estatísticas Diárias");
   Print("═══════════════════════════════════════════════════════════");
   Print("Data:              ", TimeToString(m_daily.currentDay, TIME_DATE));
   Print("Saldo Inicial:     ", DoubleToString(m_daily.startBalance, 2));
   Print("Drawdown Atual:    ", DoubleToString(m_daily.currentDD, 2), "%");
   Print("───────────────────────────────────────────────────────────");
   Print("Trades:            ", m_daily.totalTrades);
   Print("  └─ Vencedores:   ", m_daily.winTrades);
   Print("  └─ Perdedores:   ", m_daily.lossTrades);
   Print("───────────────────────────────────────────────────────────");
   Print("Lucro Bruto:       ", DoubleToString(m_daily.grossProfit, 2));
   Print("Prejuízo Bruto:    ", DoubleToString(m_daily.grossLoss, 2));
   Print("Resultado:         ", DoubleToString(m_daily.grossProfit - m_daily.grossLoss, 2));
   Print("───────────────────────────────────────────────────────────");
   Print("Stops Consecutivos:", m_daily.consecutiveStops);
   Print("Pausado:           ", m_daily.isPaused ? ("Sim - " + m_daily.pauseReason) : "Não");
   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+

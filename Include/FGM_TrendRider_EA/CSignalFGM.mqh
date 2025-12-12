//+------------------------------------------------------------------+
//|                                                   CSignalFGM.mqh |
//|                                 Copyright 2025, Pauloeduspbr     |
//|                      FGM Trend Rider - Versão Platina Final      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Pauloeduspbr"
#property version   "1.00"
#property strict

#ifndef CSIGNALFGM_MQH
#define CSIGNALFGM_MQH

//+------------------------------------------------------------------+
//| Estrutura de dados do sinal FGM                                  |
//+------------------------------------------------------------------+
struct FGM_DATA
{
   //--- EMAs
   double   ema1;           // EMA 1 (mais rápida)
   double   ema2;           // EMA 2
   double   ema3;           // EMA 3 (média)
   double   ema4;           // EMA 4
   double   ema5;           // EMA 5 (mais lenta - tendência macro)
   
   //--- Sinais
   double   signal;         // Sinal consolidado (-5 a +5)
   double   strength;       // Força do sinal (0 a 5)
   double   phase;          // Fase de mercado (-2 a +2)
   double   entry;          // Gatilho de entrada (-1, 0, +1)
   double   exitSignal;     // Gatilho de saída (-1, 0, +1)
   double   confluence;     // Confluência (0% a 100%)
   
   //--- Metadados
   datetime time;           // Tempo da barra
   bool     isValid;        // Dados válidos
};

//+------------------------------------------------------------------+
//| Enumeração de Crossover                                          |
//+------------------------------------------------------------------+
enum ENUM_CROSSOVER_TYPE
{
   CROSSOVER_EMA1_EMA2,    // EMA1 x EMA2 (mais rápido)
   CROSSOVER_EMA2_EMA3,    // EMA2 x EMA3 (médio)
   CROSSOVER_EMA3_EMA4,    // EMA3 x EMA4 (lento)
   CROSSOVER_CUSTOM        // Customizado
};

//+------------------------------------------------------------------+
//| Classe Wrapper para o Indicador FGM                              |
//+------------------------------------------------------------------+
class CSignalFGM
{
private:
   //--- Handle do indicador
   int               m_handle;
   bool              m_initialized;
   string            m_lastError;
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   
   //--- Parâmetros do indicador
   int               m_emaPeriod1;
   int               m_emaPeriod2;
   int               m_emaPeriod3;
   int               m_emaPeriod4;
   int               m_emaPeriod5;
   ENUM_APPLIED_PRICE m_appliedPrice;
   
   //--- Buffers de dados
   double            m_bufferEMA1[];
   double            m_bufferEMA2[];
   double            m_bufferEMA3[];
   double            m_bufferEMA4[];
   double            m_bufferEMA5[];
   double            m_bufferSignal[];
   double            m_bufferStrength[];
   double            m_bufferPhase[];
   double            m_bufferEntry[];
   double            m_bufferExit[];
   double            m_bufferConfluence[];
   
   //--- Cache de dados
   FGM_DATA          m_lastData;
   int               m_lastCopyBars;
   
   //--- Índices dos buffers no indicador
   enum ENUM_BUFFER_INDEX
   {
      BUFFER_EMA1 = 0,
      BUFFER_EMA2 = 1,
      BUFFER_EMA3 = 2,
      BUFFER_EMA4 = 3,
      BUFFER_EMA5 = 4,
      BUFFER_SIGNAL = 5,
      BUFFER_STRENGTH = 6,
      BUFFER_PHASE = 7,
      BUFFER_ENTRY = 8,
      BUFFER_EXIT = 9,
      BUFFER_CONFLUENCE = 10
   };
   
public:
                     CSignalFGM();
                    ~CSignalFGM();
   
   //--- Inicialização
   bool              Init(string symbol = NULL, 
                          ENUM_TIMEFRAMES tf = PERIOD_CURRENT,
                          int period1 = 5,
                          int period2 = 8,
                          int period3 = 21,
                          int period4 = 50,
                          int period5 = 200,
                          ENUM_APPLIED_PRICE appliedPrice = PRICE_CLOSE,
                          int primaryCross = 0,
                          int secondaryCross = 1,
                          int customCross1 = 1,
                          int customCross2 = 2,
                          int signalMode = 1,
                          int minStrength = 3,
                          double confluenceThreshold = 50.0,
                          bool requireConfluence = false,
                          bool enablePullbacks = true,
                          double confRangeMax = 0.05,
                          double confRangeHigh = 0.10,
                          double confRangeMed = 0.20,
                          double confRangeLow = 0.30);
   void              Deinit();
   bool              IsInitialized() { return m_initialized; }
   string            GetLastError() { return m_lastError; }
   int               GetHandle() { return m_handle; }
   
   //--- Leitura de dados (shift = 1 para barra fechada)
   bool              Update(int bars = 3);
   FGM_DATA          GetData(int shift = 1);
   bool              IsDataValid(int shift = 1);
   
   //--- Getters individuais (shift = 1 para barra fechada)
   double            GetEMA1(int shift = 1);
   double            GetEMA2(int shift = 1);
   double            GetEMA3(int shift = 1);
   double            GetEMA4(int shift = 1);
   double            GetEMA5(int shift = 1);
   double            GetSignal(int shift = 1);
   double            GetStrength(int shift = 1);
   double            GetPhase(int shift = 1);
   double            GetEntry(int shift = 1);
   double            GetExit(int shift = 1);
   double            GetConfluence(int shift = 1);
   
   //--- Interpretação do sinal
   bool              HasBuySignal(int shift = 1);
   bool              HasSellSignal(int shift = 1);
   bool              HasExitLong(int shift = 1);
   bool              HasExitShort(int shift = 1);
   
   //--- Interpretação da fase
   bool              IsBullPhase(int shift = 1);
   bool              IsBearPhase(int shift = 1);
   bool              IsNeutralPhase(int shift = 1);
   bool              IsStrongBull(int shift = 1);
   bool              IsStrongBear(int shift = 1);
   
   //--- Cálculos adicionais
   double            CalculateSlope(int period = 5, int shift = 1);
   double            GetEMASpread(int shift = 1);
   bool              IsLequeAberto(bool isBuy, int shift = 1);
   
   //--- Texto descritivo
   string            GetPhaseString(int shift = 1);
   string            GetStrengthString(int shift = 1);
   string            GetSignalDescription(int shift = 1);
   
   //--- Debug
   void              PrintSignalInfo(int shift = 1);
};

//+------------------------------------------------------------------+
//| Construtor                                                        |
//+------------------------------------------------------------------+
CSignalFGM::CSignalFGM()
{
   m_handle = INVALID_HANDLE;
   m_initialized = false;
   m_lastError = "";
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_lastCopyBars = 0;
   
   m_emaPeriod1 = 5;
   m_emaPeriod2 = 8;
   m_emaPeriod3 = 21;
   m_emaPeriod4 = 50;
   m_emaPeriod5 = 200;
   m_appliedPrice = PRICE_CLOSE;
   
   ZeroMemory(m_lastData);
   
   //--- Configurar buffers como series (mais recente = índice 0)
   ArraySetAsSeries(m_bufferEMA1, true);
   ArraySetAsSeries(m_bufferEMA2, true);
   ArraySetAsSeries(m_bufferEMA3, true);
   ArraySetAsSeries(m_bufferEMA4, true);
   ArraySetAsSeries(m_bufferEMA5, true);
   ArraySetAsSeries(m_bufferSignal, true);
   ArraySetAsSeries(m_bufferStrength, true);
   ArraySetAsSeries(m_bufferPhase, true);
   ArraySetAsSeries(m_bufferEntry, true);
   ArraySetAsSeries(m_bufferExit, true);
   ArraySetAsSeries(m_bufferConfluence, true);
}

//+------------------------------------------------------------------+
//| Destrutor                                                         |
//+------------------------------------------------------------------+
CSignalFGM::~CSignalFGM()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Inicialização                                                     |
//+------------------------------------------------------------------+
bool CSignalFGM::Init(string symbol = NULL, 
                       ENUM_TIMEFRAMES tf = PERIOD_CURRENT,
                       int period1 = 5,
                       int period2 = 8,
                       int period3 = 21,
                       int period4 = 50,
                       int period5 = 200,
                       ENUM_APPLIED_PRICE appliedPrice = PRICE_CLOSE,
                       int primaryCross = 0,
                       int secondaryCross = 1,
                       int customCross1 = 1,
                       int customCross2 = 2,
                       int signalMode = 1,
                       int minStrength = 3,
                       double confluenceThreshold = 50.0,
                       bool requireConfluence = false,
                       bool enablePullbacks = true,
                       double confRangeMax = 0.05,
                       double confRangeHigh = 0.10,
                       double confRangeMed = 0.20,
                       double confRangeLow = 0.30)
{
   //--- Definir parâmetros
   m_symbol = (symbol == NULL || symbol == "") ? _Symbol : symbol;
   m_timeframe = (tf == PERIOD_CURRENT) ? Period() : tf;
   
   m_emaPeriod1 = period1;
   m_emaPeriod2 = period2;
   m_emaPeriod3 = period3;
   m_emaPeriod4 = period4;
   m_emaPeriod5 = period5;
   m_appliedPrice = appliedPrice;
   
   //--- Validar períodos (devem estar em ordem crescente)
   if(period1 >= period2 || period2 >= period3 || 
      period3 >= period4 || period4 >= period5)
   {
      m_lastError = "Períodos das EMAs devem estar em ordem crescente";
      Print("CSignalFGM Error: ", m_lastError);
      return false;
   }
   
   //--- Criar handle do indicador FGM
   m_handle = iCustom(m_symbol, m_timeframe, 
                       "FGM_TrendRider_EA\\FGM_Indicator",
                       period1,           // EMA 1 Period
                       period2,           // EMA 2 Period
                       period3,           // EMA 3 Period
                       period4,           // EMA 4 Period
                       period5,           // EMA 5 Period
                       appliedPrice,      // Applied Price
                       primaryCross,      // Primary Crossover
                       secondaryCross,    // Secondary Confirmation
                       customCross1,      // Custom Cross 1
                       customCross2,      // Custom Cross 2
                       signalMode,        // Signal Mode
                       minStrength,       // Min Strength
                       confluenceThreshold, // Confluence Threshold
                       requireConfluence, // Require Confluence
                       enablePullbacks,   // Enable Pullbacks
                       confRangeMax,      // Conf Range Max
                       confRangeHigh,     // Conf Range High
                       confRangeMed,      // Conf Range Med
                       confRangeLow       // Conf Range Low
                       );
   
   //--- Verificar se o handle foi criado com sucesso
   if(m_handle == INVALID_HANDLE)
   {
      m_lastError = StringFormat("Falha ao criar handle do indicador FGM. Erro: %d", GetLastError());
      Print("CSignalFGM Error: ", m_lastError);
      return false;
   }
   
   //--- Aguardar dados disponíveis
   int attempts = 0;
   while(BarsCalculated(m_handle) <= 0 && attempts < 50)
   {
      Sleep(100);
      attempts++;
   }
   
   if(BarsCalculated(m_handle) <= 0)
   {
      m_lastError = "Indicador FGM não retornou dados";
      Print("CSignalFGM Error: ", m_lastError);
      IndicatorRelease(m_handle);
      m_handle = INVALID_HANDLE;
      return false;
   }
   
   m_initialized = true;
   Print("CSignalFGM: Inicializado com sucesso para ", m_symbol, " ", EnumToString(m_timeframe));
   Print("CSignalFGM: EMAs = ", period1, "/", period2, "/", period3, "/", period4, "/", period5);
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinicialização                                                   |
//+------------------------------------------------------------------+
void CSignalFGM::Deinit()
{
   if(m_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_handle);
      m_handle = INVALID_HANDLE;
   }
   m_initialized = false;
}

//+------------------------------------------------------------------+
//| Atualizar buffers                                                 |
//+------------------------------------------------------------------+
bool CSignalFGM::Update(int bars = 3)
{
   if(!m_initialized || m_handle == INVALID_HANDLE)
   {
      m_lastError = "Indicador não inicializado";
      return false;
   }
   
   //--- Copiar todos os buffers
   int copied = 0;
   
   copied = CopyBuffer(m_handle, BUFFER_EMA1, 0, bars, m_bufferEMA1);
   if(copied <= 0) { m_lastError = "Falha ao copiar buffer EMA1"; return false; }
   
   copied = CopyBuffer(m_handle, BUFFER_EMA2, 0, bars, m_bufferEMA2);
   if(copied <= 0) { m_lastError = "Falha ao copiar buffer EMA2"; return false; }
   
   copied = CopyBuffer(m_handle, BUFFER_EMA3, 0, bars, m_bufferEMA3);
   if(copied <= 0) { m_lastError = "Falha ao copiar buffer EMA3"; return false; }
   
   copied = CopyBuffer(m_handle, BUFFER_EMA4, 0, bars, m_bufferEMA4);
   if(copied <= 0) { m_lastError = "Falha ao copiar buffer EMA4"; return false; }
   
   copied = CopyBuffer(m_handle, BUFFER_EMA5, 0, bars, m_bufferEMA5);
   if(copied <= 0) { m_lastError = "Falha ao copiar buffer EMA5"; return false; }
   
   copied = CopyBuffer(m_handle, BUFFER_SIGNAL, 0, bars, m_bufferSignal);
   if(copied <= 0) { m_lastError = "Falha ao copiar buffer Signal"; return false; }
   
   copied = CopyBuffer(m_handle, BUFFER_STRENGTH, 0, bars, m_bufferStrength);
   if(copied <= 0) { m_lastError = "Falha ao copiar buffer Strength"; return false; }
   
   copied = CopyBuffer(m_handle, BUFFER_PHASE, 0, bars, m_bufferPhase);
   if(copied <= 0) { m_lastError = "Falha ao copiar buffer Phase"; return false; }
   
   copied = CopyBuffer(m_handle, BUFFER_ENTRY, 0, bars, m_bufferEntry);
   if(copied <= 0) { m_lastError = "Falha ao copiar buffer Entry"; return false; }
   
   copied = CopyBuffer(m_handle, BUFFER_EXIT, 0, bars, m_bufferExit);
   if(copied <= 0) { m_lastError = "Falha ao copiar buffer Exit"; return false; }
   
   copied = CopyBuffer(m_handle, BUFFER_CONFLUENCE, 0, bars, m_bufferConfluence);
   if(copied <= 0) { m_lastError = "Falha ao copiar buffer Confluence"; return false; }
   
   m_lastCopyBars = bars;
   return true;
}

//+------------------------------------------------------------------+
//| Obter estrutura completa de dados                                |
//+------------------------------------------------------------------+
FGM_DATA CSignalFGM::GetData(int shift = 1)
{
   FGM_DATA data;
   ZeroMemory(data);
   data.isValid = false;
   
   if(!m_initialized || shift >= ArraySize(m_bufferEMA1))
      return data;
   
   //--- Preencher EMAs
   data.ema1 = m_bufferEMA1[shift];
   data.ema2 = m_bufferEMA2[shift];
   data.ema3 = m_bufferEMA3[shift];
   data.ema4 = m_bufferEMA4[shift];
   data.ema5 = m_bufferEMA5[shift];
   
   //--- Preencher sinais
   data.signal = m_bufferSignal[shift];
   data.strength = m_bufferStrength[shift];
   data.phase = m_bufferPhase[shift];
   data.entry = m_bufferEntry[shift];
   data.exitSignal = m_bufferExit[shift];
   data.confluence = m_bufferConfluence[shift];
   
   //--- Validar dados
   if(data.ema1 > 0 && data.ema5 > 0)
      data.isValid = true;
   
   //--- Obter tempo da barra
   datetime times[];
   if(CopyTime(m_symbol, m_timeframe, shift, 1, times) > 0)
      data.time = times[0];
   
   //--- CORREÇÃO CRÍTICA: Forçar atualização da confluência
   //--- O buffer de confluência às vezes vem zerado do indicador se não houver tick novo
   //--- Recalcular confluência manualmente se estiver zerada mas houver sinal
   if(data.confluence == 0 && data.strength > 0)
   {
      // Recalcular confluência baseada na proximidade das EMAs
      // Fórmula simplificada: quanto mais próximas as EMAs, maior a confluência (compressão)
      // Quanto mais afastadas (leque aberto), menor a confluência (tendência)
      
      double maxEMA = MathMax(data.ema1, MathMax(data.ema2, MathMax(data.ema3, MathMax(data.ema4, data.ema5))));
      double minEMA = MathMin(data.ema1, MathMin(data.ema2, MathMin(data.ema3, MathMin(data.ema4, data.ema5))));
      
      if(minEMA > 0)
      {
         double spreadPercent = (maxEMA - minEMA) / minEMA * 100.0;
         // Se spread < 0.05% -> Confluência 100%
         // Se spread > 0.5% -> Confluência 0%
         
         if(spreadPercent < 0.05) data.confluence = 100.0;
         else if(spreadPercent > 0.5) data.confluence = 10.0; // Mínimo 10% para indicar tendência forte
         else
         {
            // Interpolação linear inversa
            data.confluence = 100.0 - ((spreadPercent - 0.05) / (0.5 - 0.05) * 90.0);
         }
      }
   }

   return data;
}

//+------------------------------------------------------------------+
//| Verificar se dados são válidos                                   |
//+------------------------------------------------------------------+
bool CSignalFGM::IsDataValid(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferEMA1))
      return false;
   
   if(m_bufferEMA1[shift] <= 0 || m_bufferEMA5[shift] <= 0)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Getters individuais                                              |
//+------------------------------------------------------------------+
double CSignalFGM::GetEMA1(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferEMA1)) return 0;
   return m_bufferEMA1[shift];
}

double CSignalFGM::GetEMA2(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferEMA2)) return 0;
   return m_bufferEMA2[shift];
}

double CSignalFGM::GetEMA3(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferEMA3)) return 0;
   return m_bufferEMA3[shift];
}

double CSignalFGM::GetEMA4(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferEMA4)) return 0;
   return m_bufferEMA4[shift];
}

double CSignalFGM::GetEMA5(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferEMA5)) return 0;
   return m_bufferEMA5[shift];
}

double CSignalFGM::GetSignal(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferSignal)) return 0;
   return m_bufferSignal[shift];
}

double CSignalFGM::GetStrength(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferStrength)) return 0;
   return MathAbs(m_bufferStrength[shift]);
}

double CSignalFGM::GetPhase(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferPhase)) return 0;
   return m_bufferPhase[shift];
}

double CSignalFGM::GetEntry(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferEntry)) return 0;
   return m_bufferEntry[shift];
}

double CSignalFGM::GetExit(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferExit)) return 0;
   return m_bufferExit[shift];
}

double CSignalFGM::GetConfluence(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferConfluence)) return 0;
   return m_bufferConfluence[shift];
}

//+------------------------------------------------------------------+
//| Verificar sinal de compra                                        |
//+------------------------------------------------------------------+
bool CSignalFGM::HasBuySignal(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferEntry)) return false;
   return (m_bufferEntry[shift] > 0);
}

//+------------------------------------------------------------------+
//| Verificar sinal de venda                                         |
//+------------------------------------------------------------------+
bool CSignalFGM::HasSellSignal(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferEntry)) return false;
   return (m_bufferEntry[shift] < 0);
}

//+------------------------------------------------------------------+
//| Verificar sinal de saída de compra                               |
//+------------------------------------------------------------------+
bool CSignalFGM::HasExitLong(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferExit)) return false;
   return (m_bufferExit[shift] > 0);
}

//+------------------------------------------------------------------+
//| Verificar sinal de saída de venda                                |
//+------------------------------------------------------------------+
bool CSignalFGM::HasExitShort(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferExit)) return false;
   return (m_bufferExit[shift] < 0);
}

//+------------------------------------------------------------------+
//| Verificar fase bull                                              |
//+------------------------------------------------------------------+
bool CSignalFGM::IsBullPhase(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferPhase)) return false;
   return (m_bufferPhase[shift] > 0);
}

//+------------------------------------------------------------------+
//| Verificar fase bear                                              |
//+------------------------------------------------------------------+
bool CSignalFGM::IsBearPhase(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferPhase)) return false;
   return (m_bufferPhase[shift] < 0);
}

//+------------------------------------------------------------------+
//| Verificar fase neutra                                            |
//+------------------------------------------------------------------+
bool CSignalFGM::IsNeutralPhase(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferPhase)) return false;
   return (m_bufferPhase[shift] == 0);
}

//+------------------------------------------------------------------+
//| Verificar tendência forte de alta                                |
//+------------------------------------------------------------------+
bool CSignalFGM::IsStrongBull(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferPhase)) return false;
   return (m_bufferPhase[shift] >= 2);
}

//+------------------------------------------------------------------+
//| Verificar tendência forte de baixa                               |
//+------------------------------------------------------------------+
bool CSignalFGM::IsStrongBear(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferPhase)) return false;
   return (m_bufferPhase[shift] <= -2);
}

//+------------------------------------------------------------------+
//| Calcular slope (inclinação) da EMA3                              |
//+------------------------------------------------------------------+
double CSignalFGM::CalculateSlope(int period = 5, int shift = 1)
{
   if(!m_initialized) return 0;
   
   //--- Precisamos de dados suficientes
   int requiredBars = shift + period + 1;
   if(ArraySize(m_bufferEMA3) < requiredBars)
   {
      //--- Tentar atualizar com mais barras
      if(!Update(requiredBars + 1))
         return 0;
   }
   
   if(ArraySize(m_bufferEMA3) < requiredBars)
      return 0;
   
   //--- Calcular slope: (EMA3[shift] - EMA3[shift + period]) / period
   double currentEMA = m_bufferEMA3[shift];
   double pastEMA = m_bufferEMA3[shift + period];
   
   if(currentEMA <= 0 || pastEMA <= 0)
      return 0;
   
   double slope = (currentEMA - pastEMA) / period;
   
   return slope;
}

//+------------------------------------------------------------------+
//| Obter spread entre EMA1 e EMA5                                   |
//+------------------------------------------------------------------+
double CSignalFGM::GetEMASpread(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferEMA1)) return 0;
   
   return MathAbs(m_bufferEMA1[shift] - m_bufferEMA5[shift]);
}

//+------------------------------------------------------------------+
//| Verificar se o "leque" está aberto (EMAs expandindo)             |
//+------------------------------------------------------------------+
bool CSignalFGM::IsLequeAberto(bool isBuy, int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferEMA1)) return false;
   
   double ema1 = m_bufferEMA1[shift];
   double ema2 = m_bufferEMA2[shift];
   double ema3 = m_bufferEMA3[shift];
   double ema4 = m_bufferEMA4[shift];
   double ema5 = m_bufferEMA5[shift];
   
   if(isBuy)
   {
      //--- Para compra: EMA1 > EMA2 > EMA3 > EMA4 > EMA5
      return (ema1 > ema2 && ema2 > ema3 && ema3 > ema4 && ema4 > ema5);
   }
   else
   {
      //--- Para venda: EMA1 < EMA2 < EMA3 < EMA4 < EMA5
      return (ema1 < ema2 && ema2 < ema3 && ema3 < ema4 && ema4 < ema5);
   }
}

//+------------------------------------------------------------------+
//| Obter descrição da fase                                          |
//+------------------------------------------------------------------+
string CSignalFGM::GetPhaseString(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferPhase)) return "N/A";
   
   int phase = (int)m_bufferPhase[shift];
   
   switch(phase)
   {
      case 2:  return "Strong Bull";
      case 1:  return "Weak Bull";
      case 0:  return "Neutral";
      case -1: return "Weak Bear";
      case -2: return "Strong Bear";
      default: return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Obter descrição da força                                         |
//+------------------------------------------------------------------+
string CSignalFGM::GetStrengthString(int shift = 1)
{
   if(!m_initialized || shift >= ArraySize(m_bufferStrength)) return "N/A";
   
   int strength = (int)MathAbs(m_bufferStrength[shift]);
   
   switch(strength)
   {
      case 5: return "★★★★★ Perfeito";
      case 4: return "★★★★☆ Forte";
      case 3: return "★★★☆☆ Moderado";
      case 2: return "★★☆☆☆ Fraco";
      case 1: return "★☆☆☆☆ Mínimo";
      case 0: return "☆☆☆☆☆ Nenhum";
      default: return "Desconhecido";
   }
}

//+------------------------------------------------------------------+
//| Obter descrição completa do sinal                                |
//+------------------------------------------------------------------+
string CSignalFGM::GetSignalDescription(int shift = 1)
{
   if(!m_initialized) return "Não inicializado";
   
   FGM_DATA data = GetData(shift);
   if(!data.isValid) return "Dados inválidos";
   
   string desc = "";
   
   //--- Sinal de entrada
   if(data.entry > 0)
      desc += "COMPRA | ";
   else if(data.entry < 0)
      desc += "VENDA | ";
   else
      desc += "NEUTRO | ";
   
   //--- Força
   desc += StringFormat("Força: %d/5 | ", (int)MathAbs(data.strength));
   
   //--- Fase
   desc += "Fase: " + GetPhaseString(shift) + " | ";
   
   //--- Confluência
   desc += StringFormat("Conf: %.0f%%", data.confluence);
   
   return desc;
}

//+------------------------------------------------------------------+
//| Imprimir informações do sinal (debug)                            |
//+------------------------------------------------------------------+
void CSignalFGM::PrintSignalInfo(int shift = 1)
{
   if(!m_initialized)
   {
      Print("CSignalFGM: Não inicializado");
      return;
   }
   
   FGM_DATA data = GetData(shift);
   
   Print("═══════════════════════════════════════════════════════════");
   Print("CSignalFGM - Informações do Sinal (Shift: ", shift, ")");
   Print("═══════════════════════════════════════════════════════════");
   Print("Válido: ", data.isValid ? "Sim" : "Não");
   Print("───────────────────────────────────────────────────────────");
   Print("EMA1 (", m_emaPeriod1, "): ", DoubleToString(data.ema1, _Digits));
   Print("EMA2 (", m_emaPeriod2, "): ", DoubleToString(data.ema2, _Digits));
   Print("EMA3 (", m_emaPeriod3, "): ", DoubleToString(data.ema3, _Digits));
   Print("EMA4 (", m_emaPeriod4, "): ", DoubleToString(data.ema4, _Digits));
   Print("EMA5 (", m_emaPeriod5, "): ", DoubleToString(data.ema5, _Digits));
   Print("───────────────────────────────────────────────────────────");
   Print("Signal:     ", data.signal);
   Print("Strength:   ", GetStrengthString(shift));
   Print("Phase:      ", GetPhaseString(shift), " (", data.phase, ")");
   Print("Entry:      ", data.entry > 0 ? "BUY" : (data.entry < 0 ? "SELL" : "NONE"));
   Print("Exit:       ", data.exitSignal);
   Print("Confluence: ", DoubleToString(data.confluence, 1), "%");
   Print("───────────────────────────────────────────────────────────");
   Print("Slope (5):  ", DoubleToString(CalculateSlope(5, shift), _Digits));
   Print("Leque Buy:  ", IsLequeAberto(true, shift) ? "SIM" : "NÃO");
   Print("Leque Sell: ", IsLequeAberto(false, shift) ? "SIM" : "NÃO");
   Print("═══════════════════════════════════════════════════════════");
}

#endif // CSIGNALFGM_MQH

//+------------------------------------------------------------------+

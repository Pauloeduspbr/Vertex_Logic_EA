//+------------------------------------------------------------------+
//|                                                    COBVMACD.mqh   |
//|                         Nexus Confluence Logic - OBV MACD         |
//|                    Integrated Signal Analysis for EA              |
//+------------------------------------------------------------------+
#property copyright "Nexus Confluence EA - Paulo"
#property version   "1.00"
#property strict

#ifndef COBVMACD_MQH
#define COBVMACD_MQH

//--- Índices de buffers (usando #define para compatibilidade MQL5)
#define IDX_HIST_DATA   0   // Histograma
#define IDX_COLOR_INDEX 1   // Índice de cor
#define IDX_MACD_LINE   2   // Linha MACD
#define IDX_SIGNAL_LINE 3   // Linha de Sinal
#define IDX_THRESHOLD   4   // Threshold (Buffer de leitura para EA)

//+------------------------------------------------------------------+
//| Enumeração de Sinais (Nexus Logic)                               |
//+------------------------------------------------------------------+
enum ENUM_CUSTOM_SIGNAL
{
   SIGNAL_NONE   = 0,   // Neutro / Lateralização (abaixo do Threshold)
   SIGNAL_BUY    = 1,   // Sinal de Compra Forte (Green Strong)
   SIGNAL_SELL   = -1,  // Sinal de Venda Forte (Red Strong)
   SIGNAL_HOLD_B = 2,   // Compra Enfraquecendo (Green Weak)
   SIGNAL_HOLD_S = -2   // Venda Enfraquecendo (Red Weak)
};

//+------------------------------------------------------------------+
//| Enumeração de Cores do Indicador                                 |
//+------------------------------------------------------------------+
enum ENUM_OBV_COLOR
{
   COLOR_POS_STRONG = 0,  // Verde Forte (Compra Máxima)
   COLOR_NEG_STRONG = 1,  // Vermelho Forte (Venda Máxima)
   COLOR_POS_WEAK   = 2,  // Verde Fraco (Compra Enfraquecendo)
   COLOR_NEG_WEAK   = 3   // Vermelho Fraco (Venda Enfraquecendo)
};

//+------------------------------------------------------------------+
//| Classe COBVMACD - Leitura Profissional do OBV MACD               |
//+------------------------------------------------------------------+
class COBVMACD
{
private:
   //--- Dados do indicador
   int               m_handle;
   bool              m_initialized;
   string            m_lastError;
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   
   //--- Parâmetros
   int               m_fastEMA;
   int               m_slowEMA;
   int               m_signalSMA;
   int               m_obvSmooth;
   bool              m_useTickVolume;
   int               m_threshPeriod;
   double            m_threshMult;
   
   //--- Cache de dados
   double            m_currentHist;
   double            m_currentColor;
   double            m_currentThreshold;
   double            m_currentMACD;
   double            m_currentSignal;
   datetime          m_lastUpdateTime;

public:
                     COBVMACD();
                    ~COBVMACD();
   
   //--- Inicialização
   bool              Init(string symbol = NULL,
                          ENUM_TIMEFRAMES tf = PERIOD_CURRENT,
                          int fastEMA = 12,
                          int slowEMA = 26,
                          int signalSMA = 9,
                          int obvSmooth = 5,
                          bool useTickVolume = true,
                          int threshPeriod = 34,
                          double threshMult = 0.6);
   
   void              Deinit();
   bool              IsInitialized() const { return m_initialized; }
   string            GetLastError() const { return m_lastError; }
   
   //--- Atualização de dados
   bool              Update(int shift = 1);
   
   //--- Leitura de dados
   ENUM_CUSTOM_SIGNAL GetSignal(int shift = 1);
   double            GetHistogram(int shift = 1) const { return m_currentHist; }
   double            GetColorIndex(int shift = 1) const { return m_currentColor; }
   double            GetThreshold(int shift = 1) const { return m_currentThreshold; }
   double            GetMACDLine(int shift = 1) const { return m_currentMACD; }
   double            GetSignalLine(int shift = 1) const { return m_currentSignal; }
   
   //--- Análise detalhada
   bool              IsNoiseFiltered(int shift = 1) const;
   bool              IsVolumeRelevant(int shift = 1) const;
   bool              IsSideways(int shift = 1) const;
   bool              IsSignalStrong(int shift = 1) const;
   int               GetSignalStrength(int shift = 1) const; // 0-5 (0=none, 5=max)
};

//+------------------------------------------------------------------+
//| Construtor                                                        |
//+------------------------------------------------------------------+
COBVMACD::COBVMACD()
{
   m_handle = INVALID_HANDLE;
   m_initialized = false;
   m_lastError = "";
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   
   m_fastEMA = 12;
   m_slowEMA = 26;
   m_signalSMA = 9;
   m_obvSmooth = 5;
   m_useTickVolume = true;
   m_threshPeriod = 34;
   m_threshMult = 0.6;
   
   m_currentHist = 0.0;
   m_currentColor = 0.0;
   m_currentThreshold = 0.0;
   m_currentMACD = 0.0;
   m_currentSignal = 0.0;
   m_lastUpdateTime = 0;
}

//+------------------------------------------------------------------+
//| Destrutor                                                         |
//+------------------------------------------------------------------+
COBVMACD::~COBVMACD()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Inicialização                                                     |
//+------------------------------------------------------------------+
bool COBVMACD::Init(string symbol,
                    ENUM_TIMEFRAMES tf,
                    int fastEMA,
                    int slowEMA,
                    int signalSMA,
                    int obvSmooth,
                    bool useTickVolume,
                    int threshPeriod,
                    double threshMult)
{
   m_symbol = (symbol == NULL || symbol == "") ? _Symbol : symbol;
   m_timeframe = (tf == PERIOD_CURRENT) ? _Period : tf;
   
   m_fastEMA = fastEMA;
   m_slowEMA = slowEMA;
   m_signalSMA = signalSMA;
   m_obvSmooth = obvSmooth;
   m_useTickVolume = useTickVolume;
   m_threshPeriod = threshPeriod;
   m_threshMult = threshMult;
   
   //--- Criar handle do indicador
   m_handle = iCustom(m_symbol, m_timeframe,
                      "Indicators\\FGM_TrendRider_EA\\OBV_MACD_v3",
                      m_fastEMA,
                      m_slowEMA,
                      m_signalSMA,
                      m_obvSmooth,
                      m_useTickVolume,
                      true,     // InpShowMACDLine
                      true,     // InpShowSignalLine
                      m_threshPeriod,
                      m_threshMult);
   
   if(m_handle == INVALID_HANDLE)
   {
      int err = GetLastError();
      m_lastError = StringFormat("Falha ao criar handle OBV_MACD_v3. Erro: %d", err);
      return false;
   }
   
   m_initialized = true;
   m_lastError = "";
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinicialização                                                   |
//+------------------------------------------------------------------+
void COBVMACD::Deinit()
{
   if(m_handle != INVALID_HANDLE)
   {
      IndicatorRelease(m_handle);
      m_handle = INVALID_HANDLE;
   }
   m_initialized = false;
}

//+------------------------------------------------------------------+
//| Atualização de dados                                              |
//+------------------------------------------------------------------+
bool COBVMACD::Update(int shift)
{
   if(!m_initialized)
   {
      m_lastError = "COBVMACD não inicializado";
      return false;
   }
   
   //--- Buffers para leitura
   double hist_buffer[1], color_buffer[1], threshold_buffer[1];
   double macd_buffer[1], signal_buffer[1];
   
   //--- Copiar dados do histograma
   if(CopyBuffer(m_handle, IDX_HIST_DATA, shift, 1, hist_buffer) <= 0)
   {
      m_lastError = "Falha ao copiar buffer histograma";
      return false;
   }
   
   //--- Copiar dados da cor
   if(CopyBuffer(m_handle, IDX_COLOR_INDEX, shift, 1, color_buffer) <= 0)
   {
      m_lastError = "Falha ao copiar buffer cor";
      return false;
   }
   
   //--- Copiar dados do threshold
   if(CopyBuffer(m_handle, IDX_THRESHOLD, shift, 1, threshold_buffer) <= 0)
   {
      m_lastError = "Falha ao copiar buffer threshold";
      return false;
   }
   
   //--- Copiar dados da linha MACD
   if(CopyBuffer(m_handle, IDX_MACD_LINE, shift, 1, macd_buffer) <= 0)
   {
      m_lastError = "Falha ao copiar buffer MACD";
      return false;
   }
   
   //--- Copiar dados da linha de Sinal
   if(CopyBuffer(m_handle, IDX_SIGNAL_LINE, shift, 1, signal_buffer) <= 0)
   {
      m_lastError = "Falha ao copiar buffer sinal";
      return false;
   }
   
   //--- Armazenar em cache
   m_currentHist = hist_buffer[0];
   m_currentColor = color_buffer[0];
   m_currentThreshold = threshold_buffer[0];
   m_currentMACD = macd_buffer[0];
   m_currentSignal = signal_buffer[0];
   m_lastUpdateTime = TimeCurrent();
   
   return true;
}

//+------------------------------------------------------------------+
//| Obter sinal principal (Nexus Logic)                              |
//+------------------------------------------------------------------+
ENUM_CUSTOM_SIGNAL COBVMACD::GetSignal(int shift)
{
   if(!Update(shift))
      return SIGNAL_NONE;
   
   //--- Converter cor para int (ela vem como double no buffer)
   int colorValue = (int)MathRound(m_currentColor);
   
   //--- DEBUG: Log dos dados lidos
   Print(StringFormat("[OBV MACD DEBUG] Shift=%d: Hist=%.6f | Color_Raw=%.0f (int=%d) | Threshold=%.6f | Hist_abs=%.6f",
                      shift, m_currentHist, m_currentColor, colorValue, m_currentThreshold, MathAbs(m_currentHist)));
   
   //--- FILTRO DE RUÍDO: Se histograma < threshold, mercado é lateral
   if(MathAbs(m_currentHist) < m_currentThreshold)
   {
      Print(StringFormat("[OBV MACD] Filtro de ruído ativado: |%.6f| < %.6f (LATERALIZAÇÃO)", 
                         MathAbs(m_currentHist), m_currentThreshold));
      return SIGNAL_NONE;  // Mercado em lateralização
   }
   
   Print(StringFormat("[OBV MACD] Passando filtro de ruído. Histograma válido: |%.6f| >= %.6f", 
                      MathAbs(m_currentHist), m_currentThreshold));
   
   //--- LÓGICA DE SINAIS BASEADA NA COR
   if(m_currentHist >= 0.0)
   {
      //--- Sinal POSITIVO (Bullish)
      Print(StringFormat("[OBV MACD] Histograma POSITIVO (%.6f). ColorValue=%d (0=Forte, 2=Fraco)", m_currentHist, colorValue));
      
      if(colorValue == COLOR_POS_STRONG)  // 0 = Verde Forte
      {
         Print("[OBV MACD] Cor 0 (Verde Forte) detectada -> SIGNAL_BUY");
         return SIGNAL_BUY;
      }
      else if(colorValue == COLOR_POS_WEAK)  // 2 = Verde Fraco
      {
         Print("[OBV MACD] Cor 2 (Verde Fraco) detectada -> SIGNAL_HOLD_B");
         return SIGNAL_HOLD_B;
      }
      else
      {
         Print(StringFormat("[OBV MACD] Cor desconhecida para histograma positivo: %d -> SIGNAL_NONE", colorValue));
         return SIGNAL_NONE;
      }
   }
   else
   {
      //--- Sinal NEGATIVO (Bearish)
      Print(StringFormat("[OBV MACD] Histograma NEGATIVO (%.6f). ColorValue=%d (1=Forte, 3=Fraco)", m_currentHist, colorValue));
      
      if(colorValue == COLOR_NEG_STRONG)  // 1 = Vermelho Forte
      {
         Print("[OBV MACD] Cor 1 (Vermelho Forte) detectada -> SIGNAL_SELL");
         return SIGNAL_SELL;
      }
      else if(colorValue == COLOR_NEG_WEAK)  // 3 = Vermelho Fraco
      {
         Print("[OBV MACD] Cor 3 (Vermelho Fraco) detectada -> SIGNAL_HOLD_S");
         return SIGNAL_HOLD_S;
      }
      else
      {
         Print(StringFormat("[OBV MACD] Cor desconhecida para histograma negativo: %d -> SIGNAL_NONE", colorValue));
         return SIGNAL_NONE;
      }
   }
}

//+------------------------------------------------------------------+
//| Verificar se há ruído (Volume abaixo do limiar)                  |
//+------------------------------------------------------------------+
bool COBVMACD::IsNoiseFiltered(int shift) const
{
   return MathAbs(m_currentHist) > m_currentThreshold;
}

//+------------------------------------------------------------------+
//| Verificar se o volume é relevante                                |
//+------------------------------------------------------------------+
bool COBVMACD::IsVolumeRelevant(int shift) const
{
   return IsNoiseFiltered(shift) && MathAbs(m_currentHist) > m_currentThreshold * 1.5;
}

//+------------------------------------------------------------------+
//| Detectar lateralização (Death Zone)                              |
//+------------------------------------------------------------------+
bool COBVMACD::IsSideways(int shift) const
{
   //--- Mercado lateral quando:
   //--- 1. Histograma muito pequeno (abaixo do threshold)
   //--- 2. MACD colado na linha de sinal (muito próximas)
   double macd_signal_dist = MathAbs(m_currentMACD - m_currentSignal);
   
   return (MathAbs(m_currentHist) < m_currentThreshold) &&
          (macd_signal_dist < 0.0005);
}

//+------------------------------------------------------------------+
//| Verificar se sinal é forte (não fraco)                           |
//+------------------------------------------------------------------+
bool COBVMACD::IsSignalStrong(int shift) const
{
   return (m_currentColor == COLOR_POS_STRONG || m_currentColor == COLOR_NEG_STRONG);
}

//+------------------------------------------------------------------+
//| Obter força do sinal (0-5)                                       |
//+------------------------------------------------------------------+
int COBVMACD::GetSignalStrength(int shift) const
{
   //--- Se está em ruído, força = 0
   if(!IsNoiseFiltered(shift))
      return 0;
   
   //--- Calcular força baseado na distância do threshold
   double ratio = MathAbs(m_currentHist) / m_currentThreshold;
   
   if(ratio > 3.0) return 5;       // Muito forte
   if(ratio > 2.0) return 4;       // Forte
   if(ratio > 1.5) return 3;       // Moderado
   if(ratio > 1.0) return 2;       // Fraco
   return 1;                        // Muito fraco
}

#endif // COBVMACD_MQH

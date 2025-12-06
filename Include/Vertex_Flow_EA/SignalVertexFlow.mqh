//+------------------------------------------------------------------+
//|                                             SignalVertexFlow.mqh |
//|                                  Copyright 2025, ExpertTrader MQL5 |
//|                                         https://www.experttrader.net |
//+------------------------------------------------------------------+
#include "Inputs.mqh"

class CSignalVertexFlow
{
private:
    int            m_handle_fgm;
    int            m_handle_mfi;
    int            m_handle_rsi;
    int            m_handle_adx;
    
    //--- Buffers for reading - FGM EMAs (5 lines) + data
    double         m_buf_fgm_ema1[];   // Buffer 0: EMA 14
    double         m_buf_fgm_ema2[];   // Buffer 1: EMA 26
    double         m_buf_fgm_ema3[];   // Buffer 2: EMA 50
    double         m_buf_fgm_ema4[];   // Buffer 3: EMA 100
    double         m_buf_fgm_ema5[];   // Buffer 4: EMA 200
    double         m_buf_fgm_phase[];  // Buffer 7: Phase
    
    //--- Buffers MFI, RSI, ADX
    double         m_buf_mfi_color[];
    double         m_buf_mfi_val[];
    double         m_buf_rsi_val[];
    double         m_buf_rsi_ma[];
    double         m_buf_adx[];
    
    //--- NEW BUFFERS FOR ADX DIRECTION
    double         m_buf_adx_di_plus[];  // Buffer 0: DI+
    double         m_buf_adx_di_minus[]; // Buffer 1: DI-
    
    //--- Re-entry control
    datetime       m_last_entry_time;
    int            m_last_entry_direction; // 1=buy, -1=sell, 0=none
    datetime       m_last_bar_processed;   // Last processed bar
    
public:
    CSignalVertexFlow();
    ~CSignalVertexFlow();
    
    bool           Init();
    int            GetSignal(); // 1=Buy, -1=Sell, 0=None
    
    //--- Getters for Chart Attachment
    int            GetHandleFGM() { return m_handle_fgm; }
    int            GetHandleMFI() { return m_handle_mfi; }
    int            GetHandleRSI() { return m_handle_rsi; }
    int            GetHandleADX() { return m_handle_adx; }
    
private:
    bool           UpdateBuffers();
    bool           IsPriceAboveAllEMAs(int shift, double price);
    bool           IsPriceBelowAllEMAs(int shift, double price);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalVertexFlow::CSignalVertexFlow() : 
    m_handle_fgm(INVALID_HANDLE),
    m_handle_mfi(INVALID_HANDLE),
    m_handle_rsi(INVALID_HANDLE),
    m_handle_adx(INVALID_HANDLE),
    m_last_entry_time(0),
    m_last_entry_direction(0),
    m_last_bar_processed(0)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSignalVertexFlow::~CSignalVertexFlow()
{
    if(m_handle_fgm != INVALID_HANDLE) IndicatorRelease(m_handle_fgm);
    if(m_handle_mfi != INVALID_HANDLE) IndicatorRelease(m_handle_mfi);
    if(m_handle_rsi != INVALID_HANDLE) IndicatorRelease(m_handle_rsi);
    if(m_handle_adx != INVALID_HANDLE) IndicatorRelease(m_handle_adx);
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CSignalVertexFlow::Init()
{
    Print("Vertex Flow Signal Init - Version with ADX DI Check (Clean Write)");
    
    //--- Initialize FGM Indicator
    m_handle_fgm = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\FGM_Indicator",
                           Inp_FGM_Period1,
                           Inp_FGM_Period2,
                           Inp_FGM_Period3,
                           Inp_FGM_Period4,
                           Inp_FGM_Period5,
                           Inp_FGM_Price,
                           Inp_FGM_Cross,
                           1,
                           1,
                           2,
                           Inp_FGM_Mode,
                           Inp_FGM_MinStr
                           );
                           
    if(m_handle_fgm == INVALID_HANDLE) { Print("Failed to create FGM handle"); return false; }

    //--- Initialize Enhanced MFI
    m_handle_mfi = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\EnhancedMFI",
                           Inp_MFI_Period,
                           13,
                           5,
                           Inp_MFI_LatStart,
                           Inp_MFI_LatEnd,
                           Inp_MFI_VolType,
                           1.2
                           );
                           
    if(m_handle_mfi == INVALID_HANDLE) { Print("Failed to create MFI handle"); return false; }

    //--- Initialize RSIOMA v2
    m_handle_rsi = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\RSIOMA_v2HHLSX_MT5",
                           Inp_RSI_Period,
                           Inp_RSI_MAPeriod,
                           Inp_RSI_MAMethod,
                           70.0, 30.0, true
                           );
                           
    if(m_handle_rsi == INVALID_HANDLE) { Print("Failed to create RSIOMA handle"); return false; }

    //--- Initialize ADXW Cloud
    m_handle_adx = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\ADXW_Cloud",
                           Inp_ADX_Period,
                           Inp_ADX_MinTrend,
                           clrLightGreen,
                           clrHotPink,
                           80
                           );
                           
    if(m_handle_adx == INVALID_HANDLE) { Print("Failed to create ADX handle"); return false; }

    return true;
}

//+------------------------------------------------------------------+
//| Update Buffers                                                   |
//+------------------------------------------------------------------+
bool CSignalVertexFlow::UpdateBuffers()
{
    int count = 3;

    // Set arrays as series
    ArraySetAsSeries(m_buf_fgm_ema1, true);
    ArraySetAsSeries(m_buf_fgm_ema2, true);
    ArraySetAsSeries(m_buf_fgm_ema3, true);
    ArraySetAsSeries(m_buf_fgm_ema4, true);
    ArraySetAsSeries(m_buf_fgm_ema5, true);
    ArraySetAsSeries(m_buf_fgm_phase, true);
    ArraySetAsSeries(m_buf_mfi_color, true);
    ArraySetAsSeries(m_buf_mfi_val, true);
    ArraySetAsSeries(m_buf_rsi_val, true);
    ArraySetAsSeries(m_buf_rsi_ma, true);
    ArraySetAsSeries(m_buf_adx, true);
    ArraySetAsSeries(m_buf_adx_di_plus, true);
    ArraySetAsSeries(m_buf_adx_di_minus, true);

    // FGM
    if(CopyBuffer(m_handle_fgm, 0, 0, count, m_buf_fgm_ema1) < count) return false;
    if(CopyBuffer(m_handle_fgm, 1, 0, count, m_buf_fgm_ema2) < count) return false;
    if(CopyBuffer(m_handle_fgm, 2, 0, count, m_buf_fgm_ema3) < count) return false;
    if(CopyBuffer(m_handle_fgm, 3, 0, count, m_buf_fgm_ema4) < count) return false;
    if(CopyBuffer(m_handle_fgm, 4, 0, count, m_buf_fgm_ema5) < count) return false;
    if(CopyBuffer(m_handle_fgm, 7, 0, count, m_buf_fgm_phase) < count) return false;
    
    // MFI
    if(CopyBuffer(m_handle_mfi, 1, 0, count, m_buf_mfi_color) < count) return false;
    if(CopyBuffer(m_handle_mfi, 0, 0, count, m_buf_mfi_val) < count) return false;
    
    // RSI
    if(CopyBuffer(m_handle_rsi, 0, 0, count, m_buf_rsi_val) < count) return false;
    if(CopyBuffer(m_handle_rsi, 1, 0, count, m_buf_rsi_ma) < count) return false;

    // ADX (Buffer 0=+DI, 1=-DI, 2=ADX)
    if(CopyBuffer(m_handle_adx, 0, 0, count, m_buf_adx_di_plus) < count) return false;
    if(CopyBuffer(m_handle_adx, 1, 0, count, m_buf_adx_di_minus) < count) return false;
    if(CopyBuffer(m_handle_adx, 2, 0, count, m_buf_adx) < count) return false;

    return true;
}

//+------------------------------------------------------------------+
//| Check if price is above all EMAs                                 |
//+------------------------------------------------------------------+
bool CSignalVertexFlow::IsPriceAboveAllEMAs(int shift, double price)
{
    return (price > m_buf_fgm_ema1[shift] &&
            price > m_buf_fgm_ema2[shift] &&
            price > m_buf_fgm_ema3[shift] &&
            price > m_buf_fgm_ema4[shift] &&
            price > m_buf_fgm_ema5[shift]);
}

//+------------------------------------------------------------------+
//| Check if price is below all EMAs                                 |
//+------------------------------------------------------------------+
bool CSignalVertexFlow::IsPriceBelowAllEMAs(int shift, double price)
{
    return (price < m_buf_fgm_ema1[shift] &&
            price < m_buf_fgm_ema2[shift] &&
            price < m_buf_fgm_ema3[shift] &&
            price < m_buf_fgm_ema4[shift] &&
            price < m_buf_fgm_ema5[shift]);
}

//+------------------------------------------------------------------+
//| Get Signal                                                       |
//+------------------------------------------------------------------+
int CSignalVertexFlow::GetSignal()
{
    if(!UpdateBuffers())
        return 0;

    datetime closed_bar_time = iTime(_Symbol, _Period, 1);
    
    if(m_last_bar_processed == closed_bar_time)
        return 0;
    
    m_last_bar_processed = closed_bar_time;

    int shift = 1;
    
    double close_price = iClose(_Symbol, _Period, shift);
    
    // Read Indicators
    int mfi_color = (int)m_buf_mfi_color[shift];
    double mfi_val = m_buf_mfi_val[shift];
    double adx_curr = m_buf_adx[shift];
    double adx_di_plus = m_buf_adx_di_plus[shift];
    double adx_di_minus = m_buf_adx_di_minus[shift];
    
    // FGM Logic
    bool price_above_all_emas = IsPriceAboveAllEMAs(shift, close_price);
    bool price_below_all_emas = IsPriceBelowAllEMAs(shift, close_price);
    
    // Fan Logic
    bool emas_fanned_bull = (m_buf_fgm_ema1[shift] > m_buf_fgm_ema2[shift] && 
                             m_buf_fgm_ema2[shift] > m_buf_fgm_ema3[shift] &&
                             m_buf_fgm_ema3[shift] > m_buf_fgm_ema5[shift]);

    bool emas_fanned_bear = (m_buf_fgm_ema1[shift] < m_buf_fgm_ema2[shift] && 
                             m_buf_fgm_ema2[shift] < m_buf_fgm_ema3[shift] &&
                             m_buf_fgm_ema3[shift] < m_buf_fgm_ema5[shift]);
    
    // ADX Logic
    bool adx_trending = (adx_curr >= Inp_ADX_MinTrend);
    bool adx_bullish  = (adx_di_plus > adx_di_minus);
    bool adx_bearish  = (adx_di_minus > adx_di_plus);
    
    // MFI Logic
    bool mfi_green = (mfi_color == 0);
    bool mfi_red   = (mfi_color == 1);
    
    // RSI Logic
    double rsi_val = m_buf_rsi_val[shift];
    double rsi_ma = m_buf_rsi_ma[shift];
    
    bool rsi_bullish = (rsi_val > rsi_ma);
    bool rsi_bearish = (rsi_val < rsi_ma);
    
    bool rsi_not_overbought = (rsi_val < 75.0);
    bool rsi_not_oversold   = (rsi_val > 25.0);
    
    PrintFormat("[DEBUG] %s | Close=%.2f | PriceAboveEMAs=%s PriceBelowEMAs=%s | FanBull=%s FanBear=%s | MFI=%d(%.1f) RSI=%.1f/%.1f(%s) | ADX=%.1f(%s) DI+=%.1f DI-=%.1f",
                TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                close_price,
                price_above_all_emas ? "YES" : "NO",
                price_below_all_emas ? "YES" : "NO",
                emas_fanned_bull ? "YES" : "NO",
                emas_fanned_bear ? "YES" : "NO",
                mfi_color, mfi_val,
                rsi_val, rsi_ma, rsi_bullish ? "BULL" : "BEAR",
                adx_curr, adx_trending ? "TREND" : "LATERAL",
                adx_di_plus, adx_di_minus);
    
    // BUY Logic
    bool buy_fgm_ok     = (price_above_all_emas && emas_fanned_bull);
    bool buy_adx_ok     = (adx_trending && adx_bullish);
    bool buy_mfi_ok     = mfi_green;
    bool buy_rsi_ok     = (rsi_bullish && rsi_not_overbought);
    
    datetime current_bar_time = iTime(_Symbol, _Period, 0);
    int bars_since_entry = (m_last_entry_time > 0) ? 
                           (int)((current_bar_time - m_last_entry_time) / PeriodSeconds(_Period)) : 999;
    bool can_buy = (m_last_entry_direction != 1 || bars_since_entry > 10);
    
    if(buy_fgm_ok && buy_adx_ok && buy_mfi_ok && buy_rsi_ok && can_buy)
    {
        PrintFormat("[SIGNAL BUY] %s | Close=%.2f | EMAs=ABOVE_ALL+FANNED ADX=%.1f(BULL) MFI=%d RSI=%.1f/%.1f",
                    TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                    close_price, adx_curr, mfi_color, rsi_val, rsi_ma);
        
        PrintFormat("   EMAs: %.2f / %.2f / %.2f / %.2f / %.2f",
                    m_buf_fgm_ema1[shift], m_buf_fgm_ema2[shift], m_buf_fgm_ema3[shift],
                    m_buf_fgm_ema4[shift], m_buf_fgm_ema5[shift]);
        
        m_last_entry_time = current_bar_time;
        m_last_entry_direction = 1;
        return 1;
    }
    
    // SELL Logic
    bool sell_fgm_ok     = (price_below_all_emas && emas_fanned_bear);
    bool sell_adx_ok     = (adx_trending && adx_bearish);
    bool sell_mfi_ok     = mfi_red;
    bool sell_rsi_ok     = (rsi_bearish && rsi_not_oversold);
    
    bool can_sell = (m_last_entry_direction != -1 || bars_since_entry > 10);
    
    if(sell_fgm_ok && sell_adx_ok && sell_mfi_ok && sell_rsi_ok && can_sell)
    {
        PrintFormat("[SIGNAL SELL] %s | Close=%.2f | EMAs=BELOW_ALL+FANNED ADX=%.1f(BEAR) MFI=%d RSI=%.1f/%.1f",
                    TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                    close_price, adx_curr, mfi_color, rsi_val, rsi_ma);
        
        PrintFormat("   EMAs: %.2f / %.2f / %.2f / %.2f / %.2f",
                    m_buf_fgm_ema1[shift], m_buf_fgm_ema2[shift], m_buf_fgm_ema3[shift],
                    m_buf_fgm_ema4[shift], m_buf_fgm_ema5[shift]);
        
        m_last_entry_time = current_bar_time;
        m_last_entry_direction = -1;
        return -1;
    }
    
    return 0;
}

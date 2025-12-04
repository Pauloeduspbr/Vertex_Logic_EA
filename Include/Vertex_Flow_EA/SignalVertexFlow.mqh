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
    int            m_handle_obv;
    int            m_handle_rsi;
    
    //--- Buffers for reading
    double         m_buf_fgm_phase[];
    double         m_buf_mfi_color[];
    double         m_buf_mfi_val[];
    double         m_buf_obv_hist[];
    double         m_buf_obv_color[];
    double         m_buf_rsi_val[];
    double         m_buf_rsi_ma[];
    
public:
    CSignalVertexFlow();
    ~CSignalVertexFlow();
    
    bool           Init();
    int            GetSignal(); // 1=Buy, -1=Sell, 0=None
    
    //--- Getters for Chart Attachment
    int            GetHandleFGM() { return m_handle_fgm; }
    int            GetHandleMFI() { return m_handle_mfi; }
    int            GetHandleOBV() { return m_handle_obv; }
    int            GetHandleRSI() { return m_handle_rsi; }
    
private:
    bool           UpdateBuffers();
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalVertexFlow::CSignalVertexFlow() : 
    m_handle_fgm(INVALID_HANDLE),
    m_handle_mfi(INVALID_HANDLE),
    m_handle_obv(INVALID_HANDLE),
    m_handle_rsi(INVALID_HANDLE)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSignalVertexFlow::~CSignalVertexFlow()
{
    if(m_handle_fgm != INVALID_HANDLE) IndicatorRelease(m_handle_fgm);
    if(m_handle_mfi != INVALID_HANDLE) IndicatorRelease(m_handle_mfi);
    if(m_handle_obv != INVALID_HANDLE) IndicatorRelease(m_handle_obv);
    if(m_handle_rsi != INVALID_HANDLE) IndicatorRelease(m_handle_rsi);
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CSignalVertexFlow::Init()
{
    //--- Initialize FGM Indicator (simplified - passing Period1 twice to account for hidden input shift)
    m_handle_fgm = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\FGM_Indicator",
                           Inp_FGM_Period1, Inp_FGM_Period1, Inp_FGM_Period2, Inp_FGM_Period3, Inp_FGM_Period4, Inp_FGM_Period5
                           );
                           
    if(m_handle_fgm == INVALID_HANDLE) { Print("Failed to create FGM handle"); return false; }

    //--- Initialize Enhanced MFI
    m_handle_mfi = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\EnhancedMFI",
                           Inp_MFI_Period,
                           13, // BullsBearsPeriod
                           5, // VolumePeriod
                           Inp_MFI_LatStart,
                           Inp_MFI_LatEnd,
                           Inp_MFI_VolType,
                           1.2 // VolumeFactor
                           );
                           
    if(m_handle_mfi == INVALID_HANDLE) { Print("Failed to create MFI handle"); return false; }

    //--- Initialize OBV MACD
    m_handle_obv = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\OBV_MACD",
                           Inp_OBV_FastEMA,
                           Inp_OBV_SlowEMA,
                           Inp_OBV_SignalSMA,
                           Inp_OBV_Smooth,
                           Inp_OBV_UseTick,
                           false, false, 34, 0.6 // Visuals & Threshold
                           );
                           
    if(m_handle_obv == INVALID_HANDLE) { Print("Failed to create OBV MACD handle"); return false; }

    //--- Initialize RSIOMA v2
    m_handle_rsi = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\RSIOMA_v2HHLSX_MT5",
                           Inp_RSI_Period,
                           Inp_RSI_MAPeriod,
                           Inp_RSI_MAMethod,
                           70.0, 30.0, false // Levels
                           );
                           
    if(m_handle_rsi == INVALID_HANDLE) { Print("Failed to create RSIOMA handle"); return false; }

    return true;
}

//+------------------------------------------------------------------+
//| Update Buffers                                                   |
//+------------------------------------------------------------------+
bool CSignalVertexFlow::UpdateBuffers()
{
    // Need 3 bars for crossover check (0, 1, 2)
    int count = 3;
    
    if(CopyBuffer(m_handle_fgm, 7, 0, count, m_buf_fgm_phase) < count) return false;
    if(CopyBuffer(m_handle_mfi, 1, 0, count, m_buf_mfi_color) < count) return false;
    if(CopyBuffer(m_handle_mfi, 0, 0, count, m_buf_mfi_val) < count) return false; // Value for oversold/overbought check
    if(CopyBuffer(m_handle_obv, 0, 0, count, m_buf_obv_hist) < count) return false;
    if(CopyBuffer(m_handle_obv, 1, 0, count, m_buf_obv_color) < count) return false;
    if(CopyBuffer(m_handle_rsi, 0, 0, count, m_buf_rsi_val) < count) return false;
    if(CopyBuffer(m_handle_rsi, 1, 0, count, m_buf_rsi_ma) < count) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Get Signal                                                       |
//+------------------------------------------------------------------+
int CSignalVertexFlow::GetSignal()
{
    if(!UpdateBuffers()) return 0;
    
    // Index 0 is oldest in CopyBuffer result if not AsSeries.
    // Let's set AsSeries to make it easier (0=current, 1=prev).
    ArraySetAsSeries(m_buf_fgm_phase, true);
    ArraySetAsSeries(m_buf_mfi_color, true);
    ArraySetAsSeries(m_buf_mfi_val, true);
    ArraySetAsSeries(m_buf_obv_hist, true);
    ArraySetAsSeries(m_buf_obv_color, true);
    ArraySetAsSeries(m_buf_rsi_val, true);
    ArraySetAsSeries(m_buf_rsi_ma, true);
    
    //--- Analyze at Shift 1 (Completed Bar)
    int shift = 1;
    
    //--- 1. RSIOMA Trigger (Crossover)
    bool rsi_cross_up = (m_buf_rsi_val[shift] > m_buf_rsi_ma[shift]) && (m_buf_rsi_val[shift+1] <= m_buf_rsi_ma[shift+1]);
    bool rsi_cross_down = (m_buf_rsi_val[shift] < m_buf_rsi_ma[shift]) && (m_buf_rsi_val[shift+1] >= m_buf_rsi_ma[shift+1]);
    
    if(!rsi_cross_up && !rsi_cross_down) return 0; // No trigger
    
    //--- 2. FGM Filter
    // Phase: 2=StrongBull, 1=WeakBull, 0=Neutral, -1=WeakBear, -2=StrongBear
    int fgm_phase = (int)m_buf_fgm_phase[shift];
    
    //--- 3. MFI Filter
    // Color: 0=Green, 1=Red, 2=Yellow
    int mfi_color = (int)m_buf_mfi_color[shift];
    double mfi_val = m_buf_mfi_val[shift];
    
    if(mfi_color == 2) return 0; // Lateral - VETO
    
    //--- 4. OBV MACD Filter
    // Color: 0=GreenStrong, 1=RedStrong, 2=GreenWeak, 3=RedWeak
    double obv_hist = m_buf_obv_hist[shift];
    int obv_color = (int)m_buf_obv_color[shift];
    
    //--- BUY LOGIC
    if(rsi_cross_up)
    {
        // FGM: Must be Bullish (1 or 2)
        if(fgm_phase < 1) return 0;
        
        // MFI: Must be Green (0) OR Oversold (<20)
        // Note: mfi_color != 2 is already checked.
        // If it's Red (1) but < 20, is it allowed? User said: "Verde OR saindo da zona de sobrevenda"
        // If it's Red, it's selling pressure. But if it's < 20, it might be a reversal.
        // Let's stick to strict: If Color is Red, check if < 20. If > 20 and Red, then Veto.
        if(mfi_color == 1 && mfi_val > 20.0) return 0; 
        
        // OBV: Hist > 0 OR GreenStrong (0)
        if(obv_hist <= 0 && obv_color != 0) return 0;
        
        return 1; // Valid Buy
    }
    
    //--- SELL LOGIC
    if(rsi_cross_down)
    {
        // FGM: Must be Bearish (-1 or -2)
        if(fgm_phase > -1) return 0;
        
        // MFI: Must be Red (1) OR Overbought (>80)
        // If it's Green (0) but > 80, is it allowed?
        if(mfi_color == 0 && mfi_val < 80.0) return 0;
        
        // OBV: Hist < 0 OR RedStrong (1)
        if(obv_hist >= 0 && obv_color != 1) return 0;
        
        return -1; // Valid Sell
    }
    
    return 0;
}

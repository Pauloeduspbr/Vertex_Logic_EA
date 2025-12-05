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
    
    //--- Buffers for reading
    double         m_buf_fgm_phase[];
    double         m_buf_mfi_color[];
    double         m_buf_mfi_val[];
    double         m_buf_rsi_val[];
    double         m_buf_rsi_ma[];
    double         m_buf_adx[];
    
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
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalVertexFlow::CSignalVertexFlow() : 
    m_handle_fgm(INVALID_HANDLE),
    m_handle_mfi(INVALID_HANDLE),
    m_handle_rsi(INVALID_HANDLE),
    m_handle_adx(INVALID_HANDLE)
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

    //--- Initialize RSIOMA v2
    // Último parâmetro (ShowLevels) EM TRUE para exibir os níveis 70/30 no gráfico
    // Isso permite visualizar claramente o filtro de nível (acima/abaixo de 50) usado pelo EA.
    m_handle_rsi = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\RSIOMA_v2HHLSX_MT5",
                           Inp_RSI_Period,
                           Inp_RSI_MAPeriod,
                           Inp_RSI_MAMethod,
                           70.0, 30.0, true // Levels
                           );
                           
    if(m_handle_rsi == INVALID_HANDLE) { Print("Failed to create RSIOMA handle"); return false; }

    //--- Initialize ADXW Cloud
    // Assuming filename is ADXW_Cloud.mq5 based on "ADXW Cloud 1.0" title
    // Parameters from image: Period, ADXR Level, BullColor, BearColor, Transparency
    m_handle_adx = iCustom(_Symbol, _Period, "Vertex_Flow_EA\\ADXW_Cloud",
                           Inp_ADX_Period,
                           Inp_ADX_MinTrend, // Using MinTrend as the ADXR Level input for the indicator
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
    // Precisamos de 3 barras COMPLETAS para verificar cruzamento e filtros.
    // Vamos sempre trabalhar com séries (0 = barra atual em formação, 1 = última barra fechada, 2 = barra anterior fechada).
    int count = 3;

    // IMPORTANTE: Definir ArraySetAsSeries ANTES de CopyBuffer é uma boa prática
    // para evitar problemas de indexação em diferentes timeframes
    ArraySetAsSeries(m_buf_fgm_phase, true);
    ArraySetAsSeries(m_buf_mfi_color, true);
    ArraySetAsSeries(m_buf_mfi_val, true);
    ArraySetAsSeries(m_buf_rsi_val, true);
    ArraySetAsSeries(m_buf_rsi_ma, true);
    ArraySetAsSeries(m_buf_adx, true);

    // Copia a partir da barra 0, com arrays já marcados como séries
    // para garantir que todos os indicadores estejam alinhados no mesmo índice.
    if(CopyBuffer(m_handle_fgm, 7, 0, count, m_buf_fgm_phase) < count) return false;
    if(CopyBuffer(m_handle_mfi, 1, 0, count, m_buf_mfi_color) < count) return false;
    if(CopyBuffer(m_handle_mfi, 0, 0, count, m_buf_mfi_val) < count) return false; // Valor para sobrecompra/sobrevenda
    // No indicador RSIOMA_v2HHLSX_MT5:
    //  - Buffer 0 = RSI principal (linha vermelha)
    //  - Buffer 1 = MA do RSI (linha azul)
    // Portanto, aqui mantemos a mesma convenção visual:
    if(CopyBuffer(m_handle_rsi, 0, 0, count, m_buf_rsi_val) < count) return false; // Buffer 0 = RSI (vermelha)
    if(CopyBuffer(m_handle_rsi, 1, 0, count, m_buf_rsi_ma) < count) return false; // Buffer 1 = MA  (azul)

    // ADXW Cloud: Buffer 2 é assumido como o valor principal do ADX
    // NOTA: Se o indicador ADXW_Cloud usar outro buffer, ajustar aqui
    if(CopyBuffer(m_handle_adx, 2, 0, count, m_buf_adx) < count) return false;

    return true;
}

//+------------------------------------------------------------------+
//| Get Signal                                                       |
//+------------------------------------------------------------------+
int CSignalVertexFlow::GetSignal()
{
    if(!UpdateBuffers())
        return 0;

    // IMPORTANTE: Verificar se estamos no início de uma nova barra para evitar sinais duplicados
    static datetime last_bar_time = 0;
    datetime current_bar_time = iTime(_Symbol, _Period, 0);
    
    // Só processar sinal UMA VEZ por barra (quando a barra fecha)
    if(last_bar_time == current_bar_time)
        return 0; // Já processamos esta barra
    
    last_bar_time = current_bar_time;

    // Analisamos a ÚLTIMA BARRA FECHADA (índice 1 após ArraySetAsSeries)
    int shift = 1;              // barra fechada mais recente (candle de sinal)
    int prev_shift = shift + 1; // barra anterior à de sinal (para detectar cruzamento)
    
    //--- 1. RSIOMA Trigger (Crossover)
    // Buffer 0 = RSI principal (linha vermelha)
    // Buffer 1 = MA do RSI (linha azul)
    double rsi_now = m_buf_rsi_val[shift];
    double rsi_ma_now = m_buf_rsi_ma[shift];
    double rsi_prev = m_buf_rsi_val[prev_shift];
    double rsi_ma_prev = m_buf_rsi_ma[prev_shift];

    bool rsi_bull_now  = (rsi_now > rsi_ma_now);
    bool rsi_bull_prev = (rsi_prev > rsi_ma_prev);
    bool rsi_bear_now  = (rsi_now < rsi_ma_now);
    bool rsi_bear_prev = (rsi_prev < rsi_ma_prev);

    bool rsi_cross_up   = (!rsi_bull_prev && rsi_bull_now);
    bool rsi_cross_down = (!rsi_bear_prev && rsi_bear_now);

    if(!rsi_cross_up && !rsi_cross_down)
        return 0;
    
    //--- 2. FGM Filter
    int fgm_phase = (int)m_buf_fgm_phase[shift];
    
    //--- 3. MFI Filter
    int mfi_color = (int)m_buf_mfi_color[shift];
    double mfi_val = m_buf_mfi_val[shift];
    
    //--- 4. ADX Filter
    double adx_curr = m_buf_adx[shift];
    double adx_prev = m_buf_adx[prev_shift];
    bool adx_rising = (adx_curr > adx_prev);
    
    // DEBUG: Log detalhado quando há cruzamento RSIOMA
    PrintFormat("[DEBUG] %s | RSIOMA Cross: %s | RSI=%.2f MA=%.2f | FGM=%d | MFI_Color=%d MFI_Val=%.2f | ADX=%.2f Rising=%s",
                TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                rsi_cross_up ? "UP" : "DOWN",
                rsi_now, rsi_ma_now,
                fgm_phase,
                mfi_color, mfi_val,
                adx_curr, adx_rising ? "YES" : "NO");
    
    //--- BUY LOGIC
    if(rsi_cross_up)
    {
        // FILTRO 1: FGM DEVE ser BULLISH (>0). Neutro (0) = sem tendência = não opera
        if(fgm_phase <= 0) 
        {
            Print("[VETO BUY] FGM Not Bullish: ", fgm_phase);
            return 0;
        }
        
        // FILTRO 2: MFI não pode estar em lateral (amarelo=2)
        if(mfi_color == 2)
        {
            Print("[VETO BUY] MFI Lateral (Yellow)");
            return 0;
        }
        
        // FILTRO 3: MFI DEVE ser verde (buying pressure) para compra
        if(mfi_color != 0)
        {
            Print("[VETO BUY] MFI Not Green: ", mfi_color);
            return 0;
        }
        
        // FILTRO 4: ADX deve indicar força de tendência (mínimo 22 para compra)
        if(adx_curr < 22.0)
        {
            Print("[VETO BUY] ADX Too Low: ", adx_curr);
            return 0;
        }
        
        // FILTRO 5: RSI deve estar entre 45-68 (zona de momentum de alta)
        if(rsi_now > 68.0 || rsi_now < 45.0)
        {
            Print("[VETO BUY] RSI Out of Range (45-68): ", rsi_now);
            return 0;
        }
        
        Print("[SIGNAL BUY] All filters passed!");
        return 1;
    }
    
    //--- SELL LOGIC
    if(rsi_cross_down)
    {
        // FILTRO 1: FGM DEVE ser BEARISH (<0). Neutro (0) = sem tendência = não opera
        if(fgm_phase >= 0)
        {
            Print("[VETO SELL] FGM Not Bearish: ", fgm_phase);
            return 0;
        }
        
        // FILTRO 2: MFI não pode estar em lateral (amarelo=2)
        if(mfi_color == 2)
        {
            Print("[VETO SELL] MFI Lateral (Yellow)");
            return 0;
        }
        
        // FILTRO 3: MFI deve indicar pressão vendedora (vermelho=1) ou neutro após queda
        // Relaxado: permite MFI verde se RSI já está em queda forte
        if(mfi_color == 0 && rsi_now > 50.0)
        {
            Print("[VETO SELL] MFI Green with RSI > 50");
            return 0;
        }
        
        // FILTRO 4: ADX deve indicar força de tendência (mínimo 18 para venda)
        if(adx_curr < 18.0)
        {
            Print("[VETO SELL] ADX Too Low: ", adx_curr);
            return 0;
        }
        
        // FILTRO 5: RSI deve estar entre 30-55 (zona de momentum de baixa)
        if(rsi_now < 30.0 || rsi_now > 55.0)
        {
            Print("[VETO SELL] RSI Out of Range (30-55): ", rsi_now);
            return 0;
        }
        
        Print("[SIGNAL SELL] All filters passed!");
        return -1;
    }
    
    return 0;
}

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
    
    //==========================================================================
    // NOVA ESTRATÉGIA BASEADA NA ANÁLISE DAS IMAGENS:
    //
    // TRIGGER: MFI muda de cor (de amarelo/neutro para verde ou vermelho)
    //          OU FGM muda de fase (de 0 para +1/-1)
    //
    // FILTROS (todos devem estar alinhados):
    // 1. FGM: >0 para compra, <0 para venda (tendência definida)
    // 2. MFI: Verde(0) para compra, Vermelho(1) para venda (NÃO amarelo=2)
    // 3. RSIOMA: Vermelho ACIMA do azul = compra, Vermelho ABAIXO do azul = venda
    //            (NÃO é cruzamento, é POSIÇÃO ATUAL)
    // 4. ADX: Acima de 20 (tendência com força)
    //==========================================================================
    
    //--- Leitura dos indicadores
    int fgm_phase = (int)m_buf_fgm_phase[shift];
    int fgm_phase_prev = (int)m_buf_fgm_phase[prev_shift];
    
    int mfi_color = (int)m_buf_mfi_color[shift];
    int mfi_color_prev = (int)m_buf_mfi_color[prev_shift];
    double mfi_val = m_buf_mfi_val[shift];
    
    double rsi_val = m_buf_rsi_val[shift];
    double rsi_ma = m_buf_rsi_ma[shift];
    
    double adx_curr = m_buf_adx[shift];
    double adx_prev = m_buf_adx[prev_shift];
    
    //--- Condições de FILTRO (devem estar alinhadas ANTES do trigger)
    bool rsi_bullish = (rsi_val > rsi_ma);  // Vermelho ACIMA do azul
    bool rsi_bearish = (rsi_val < rsi_ma);  // Vermelho ABAIXO do azul
    
    bool fgm_bullish = (fgm_phase > 0);     // FGM indica alta
    bool fgm_bearish = (fgm_phase < 0);     // FGM indica baixa
    
    bool mfi_green = (mfi_color == 0);      // Pressão compradora
    bool mfi_red = (mfi_color == 1);        // Pressão vendedora
    bool mfi_yellow = (mfi_color == 2);     // Lateral - NÃO OPERA
    
    bool adx_strong = (adx_curr >= Inp_ADX_MinTrend);
    
    //--- TRIGGERS: Mudança de estado que gera entrada
    // Trigger 1: MFI saiu de amarelo/vermelho e ficou verde (início de pressão compradora)
    bool mfi_turned_green = (mfi_color == 0 && mfi_color_prev != 0);
    // Trigger 2: MFI saiu de amarelo/verde e ficou vermelho (início de pressão vendedora)
    bool mfi_turned_red = (mfi_color == 1 && mfi_color_prev != 1);
    // Trigger 3: FGM mudou para bullish
    bool fgm_turned_bullish = (fgm_phase > 0 && fgm_phase_prev <= 0);
    // Trigger 4: FGM mudou para bearish
    bool fgm_turned_bearish = (fgm_phase < 0 && fgm_phase_prev >= 0);
    
    // DEBUG: Log do estado atual
    PrintFormat("[DEBUG] %s | FGM=%d (prev=%d) | MFI_Color=%d (prev=%d) | RSI=%.2f MA=%.2f (%s) | ADX=%.2f",
                TimeToString(iTime(_Symbol, _Period, shift), TIME_DATE|TIME_MINUTES),
                fgm_phase, fgm_phase_prev,
                mfi_color, mfi_color_prev,
                rsi_val, rsi_ma, rsi_bullish ? "BULL" : (rsi_bearish ? "BEAR" : "NEUTRAL"),
                adx_curr);
    
    //==========================================================================
    // LÓGICA DE COMPRA
    //==========================================================================
    // Trigger: MFI ficou verde OU FGM virou bullish
    bool buy_trigger = (mfi_turned_green || fgm_turned_bullish);
    
    if(buy_trigger)
    {
        Print("[TRIGGER BUY] MFI_Green=", mfi_turned_green, " FGM_Bull=", fgm_turned_bullish);
        
        // FILTRO 1: MFI NÃO pode ser amarelo (lateral)
        if(mfi_yellow)
        {
            Print("[VETO BUY] MFI Lateral (Yellow)");
            return 0;
        }
        
        // FILTRO 2: MFI deve ser verde (pressão compradora)
        if(!mfi_green)
        {
            Print("[VETO BUY] MFI Not Green: ", mfi_color);
            return 0;
        }
        
        // FILTRO 3: FGM deve ser bullish (tendência de alta)
        if(!fgm_bullish)
        {
            Print("[VETO BUY] FGM Not Bullish: ", fgm_phase);
            return 0;
        }
        
        // FILTRO 4: RSIOMA vermelho deve estar ACIMA do azul
        if(!rsi_bullish)
        {
            Print("[VETO BUY] RSI Not Above MA: RSI=", rsi_val, " MA=", rsi_ma);
            return 0;
        }
        
        // FILTRO 5: ADX deve indicar tendência (>= 20)
        if(!adx_strong)
        {
            Print("[VETO BUY] ADX Too Low: ", adx_curr);
            return 0;
        }
        
        Print("[SIGNAL BUY] All filters aligned! FGM=", fgm_phase, " MFI=Green RSI>MA ADX=", adx_curr);
        return 1;
    }
    
    //==========================================================================
    // LÓGICA DE VENDA
    //==========================================================================
    // Trigger: MFI ficou vermelho OU FGM virou bearish
    bool sell_trigger = (mfi_turned_red || fgm_turned_bearish);
    
    if(sell_trigger)
    {
        Print("[TRIGGER SELL] MFI_Red=", mfi_turned_red, " FGM_Bear=", fgm_turned_bearish);
        
        // FILTRO 1: MFI NÃO pode ser amarelo (lateral)
        if(mfi_yellow)
        {
            Print("[VETO SELL] MFI Lateral (Yellow)");
            return 0;
        }
        
        // FILTRO 2: MFI deve ser vermelho (pressão vendedora)
        if(!mfi_red)
        {
            Print("[VETO SELL] MFI Not Red: ", mfi_color);
            return 0;
        }
        
        // FILTRO 3: FGM deve ser bearish (tendência de baixa)
        if(!fgm_bearish)
        {
            Print("[VETO SELL] FGM Not Bearish: ", fgm_phase);
            return 0;
        }
        
        // FILTRO 4: RSIOMA vermelho deve estar ABAIXO do azul
        if(!rsi_bearish)
        {
            Print("[VETO SELL] RSI Not Below MA: RSI=", rsi_val, " MA=", rsi_ma);
            return 0;
        }
        
        // FILTRO 5: ADX deve indicar tendência (>= 20)
        if(!adx_strong)
        {
            Print("[VETO SELL] ADX Too Low: ", adx_curr);
            return 0;
        }
        
        Print("[SIGNAL SELL] All filters aligned! FGM=", fgm_phase, " MFI=Red RSI<MA ADX=", adx_curr);
        return -1;
    }
    
    return 0;
}

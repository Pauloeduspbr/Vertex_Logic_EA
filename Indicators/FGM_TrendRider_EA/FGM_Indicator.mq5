//+------------------------------------------------------------------+
//|                                            FGM_Indicator_Pro.mq5 |
//|                                  Copyright 2025, ExpertTrader MQL5 |
//|                                         https://www.experttrader.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, ExpertTrader MQL5"
#property link      "https://www.experttrader.net"
#property version   "3.00" // Major update: Removed ATR, optimized for speed
#property description "FGM Advanced System - 5 EMAs with Percentage-Based Confluence"
#property indicator_chart_window
#property indicator_buffers 11
#property indicator_plots   11

//--- Plot EMA Lines (0-4: visíveis)
#property indicator_label1  "FGM_EMA1"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMagenta
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "FGM_EMA2"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "FGM_EMA3"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "FGM_EMA4"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrGreen
#property indicator_style4  STYLE_SOLID
#property indicator_width4  2

#property indicator_label5  "FGM_EMA5"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrGold
#property indicator_style5  STYLE_SOLID
#property indicator_width5  3

//--- Plot invisible buffers (6-10: dados para EA, não plotados)
#property indicator_label6  "FGM_Signal"
#property indicator_type6   DRAW_NONE
#property indicator_label7  "FGM_Strength"
#property indicator_type7   DRAW_NONE
#property indicator_label8  "FGM_Phase"
#property indicator_type8   DRAW_NONE
#property indicator_label9  "FGM_Entry"
#property indicator_type9   DRAW_NONE
#property indicator_label10 "FGM_Exit"
#property indicator_type10  DRAW_NONE
#property indicator_label11 "FGM_Confluence"
#property indicator_type11  DRAW_NONE

//--- Enums
enum SIGNAL_MODE {
    MODE_CONSERVATIVE = 0,  // Conservative (4-5 confirmations)
    MODE_MODERATE = 1,      // Moderate (3-4 confirmations)
    MODE_AGGRESSIVE = 2     // Aggressive (2+ confirmations)
};

enum MARKET_PHASE {
    PHASE_STRONG_BULL = 2,    // Strong Bullish Trend
    PHASE_WEAK_BULL = 1,      // Weak Bullish Trend
    PHASE_NEUTRAL = 0,        // Neutral/Consolidation
    PHASE_WEAK_BEAR = -1,     // Weak Bearish Trend
    PHASE_STRONG_BEAR = -2    // Strong Bearish Trend
};

enum CROSSOVER_TYPE {
    CROSS_EMA1_EMA2 = 0,   // EMA1 x EMA2 (Fastest)
    CROSS_EMA2_EMA3 = 1,   // EMA2 x EMA3 (Medium)
    CROSS_EMA3_EMA4 = 2,   // EMA3 x EMA4 (Slow)
    CROSS_CUSTOM = 3       // Custom Crossover
};

//--- Input parameters
//===== EMA Periods Configuration =====
input int              InpPeriod1   = 5;      // EMA 1 Period (Fastest)
input int              InpPeriod2   = 8;      // EMA 2 Period (Fast)
input int              InpPeriod3   = 21;     // EMA 3 Period (Medium)
input int              InpPeriod4   = 50;     // EMA 4 Period (Slow)
input int              InpPeriod5   = 200;    // EMA 5 Period (Slowest)
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // Applied Price

//===== Crossover Configuration =====
input CROSSOVER_TYPE   InpPrimaryCross = CROSS_EMA1_EMA2;    // Primary Crossover Signal
input CROSSOVER_TYPE   InpSecondaryCross = CROSS_EMA2_EMA3;  // Secondary Confirmation
input int              InpCustomCross1 = 1;   // Custom Cross EMA Index 1 (1-5)
input int              InpCustomCross2 = 2;   // Custom Cross EMA Index 2 (1-5)

//===== Signal Configuration =====
input SIGNAL_MODE      InpSignalMode = MODE_MODERATE;  // Signal Mode
input int              InpMinStrength = 3;             // Minimum Strength Required (1-5)
input double           InpConfluenceThreshold = 50.0;  // Min Confluence Level (0-100%)
input bool             InpRequireConfluence = false;   // Require Confluence Filter

//===== Confluence Configuration (Percentage Based) =====
// Substituindo ATR por % do preço para medir compressão
// Ex: 0.05% de range entre EMA1 e EMA5 = compressão extrema
input double           InpConfRangeMax = 0.05;         // Max Range % for 100% Confluence (Extreme Compression)
input double           InpConfRangeHigh = 0.10;        // Max Range % for 75% Confluence
input double           InpConfRangeMed = 0.20;         // Max Range % for 50% Confluence
input double           InpConfRangeLow = 0.30;         // Max Range % for 25% Confluence

//===== Visual Settings =====
input bool             InpShowArrows = true;           // Show Signal Arrows
input int              InpArrowDistance = 10;          // Arrow Distance (points)
input bool             InpShowEMA1 = true;             // Show EMA 1
input bool             InpShowEMA2 = true;             // Show EMA 2
input bool             InpShowEMA3 = true;             // Show EMA 3
input bool             InpShowEMA4 = true;             // Show EMA 4
input bool             InpShowEMA5 = true;             // Show EMA 5

//===== Alert Configuration =====
input bool             InpEnableAlerts = true;         // Enable Popup Alerts
input bool             InpEnablePush = false;          // Enable Push Notifications
input bool             InpEnableEmail = false;         // Enable Email Alerts
input bool             InpAlertOnBarClose = true;      // Alert Only on Bar Close
input int              InpAlertCooldown = 5;           // Alert Cooldown (bars)

//===== Display Options =====
input bool             InpShowEMAValues = true;        // Show EMA Values in Alert
input bool             InpShowPriceValue = true;       // Show Price in Alert
input bool             InpShowMarketPhase = true;      // Show Market Phase
input bool             InpShowConfluence = true;       // Show Confluence Level
input bool             InpShowStrength = true;         // Show Signal Strength

//===== Position Sizing Configuration =====
input double           InpPosSize1Star = 0.25;         // Position Size for 1-Star Signal
input double           InpPosSize2Star = 0.50;         // Position Size for 2-Star Signal
input double           InpPosSize3Star = 1.00;         // Position Size for 3-Star Signal
input double           InpPosSize4Star = 1.50;         // Position Size for 4-Star Signal
input double           InpPosSize5Star = 2.00;         // Position Size for 5-Star Signal

//--- Indicator buffers
double FGM_EMA1_Buffer[];
double FGM_EMA2_Buffer[];
double FGM_EMA3_Buffer[];
double FGM_EMA4_Buffer[];
double FGM_EMA5_Buffer[];
double FGM_Signal_Buffer[];
double FGM_Strength_Buffer[];
double FGM_Phase_Buffer[];
double FGM_Entry_Buffer[];
double FGM_Exit_Buffer[];
double FGM_Confluence_Buffer[];

//--- MA handles
int handle_ema1;
int handle_ema2;
int handle_ema3;
int handle_ema4;
int handle_ema5;

//--- Core engine enable flag
bool   CORE_Enabled = true;

//--- Global variables
datetime last_alert_time = 0;
int last_alert_bar = -1;
string last_signal_type = "";
int alert_cooldown_counter = 0;

//--- Market phase tracking
MARKET_PHASE current_phase = PHASE_NEUTRAL;
MARKET_PHASE previous_phase = PHASE_NEUTRAL;

//--- Period array for easy access
int ema_periods[5];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Store periods in array for easy access
    ema_periods[0] = InpPeriod1;
    ema_periods[1] = InpPeriod2;
    ema_periods[2] = InpPeriod3;
    ema_periods[3] = InpPeriod4;
    ema_periods[4] = InpPeriod5;
    
    //--- Validation of input parameters
    for(int i = 0; i < 5; i++)
    {
        if(ema_periods[i] <= 0)
        {
            Print("FGM_Pro Error: Invalid EMA period: ", ema_periods[i]);
            return(INIT_FAILED);
        }
    }
    
    //--- Check if periods are in ascending order
    for(int i = 0; i < 4; i++)
    {
        if(ema_periods[i] >= ema_periods[i+1])
        {
            Print("FGM_Pro Warning: EMAs should be in ascending order for best results.");
        }
    }
    
    //--- Validate custom crossover indices
    if(InpPrimaryCross == CROSS_CUSTOM)
    {
        if(InpCustomCross1 < 1 || InpCustomCross1 > 5 || 
           InpCustomCross2 < 1 || InpCustomCross2 > 5 ||
           InpCustomCross1 == InpCustomCross2)
        {
            Print("FGM_Pro Error: Invalid custom crossover indices.");
            return(INIT_FAILED);
        }
    }
    
    //--- Create MA handles
    handle_ema1 = iMA(_Symbol, _Period, InpPeriod1, 0, MODE_EMA, InpAppliedPrice);
    handle_ema2 = iMA(_Symbol, _Period, InpPeriod2, 0, MODE_EMA, InpAppliedPrice);
    handle_ema3 = iMA(_Symbol, _Period, InpPeriod3, 0, MODE_EMA, InpAppliedPrice);
    handle_ema4 = iMA(_Symbol, _Period, InpPeriod4, 0, MODE_EMA, InpAppliedPrice);
    handle_ema5 = iMA(_Symbol, _Period, InpPeriod5, 0, MODE_EMA, InpAppliedPrice);
    
    //--- Check handles
    if(handle_ema1 == INVALID_HANDLE || handle_ema2 == INVALID_HANDLE || 
       handle_ema3 == INVALID_HANDLE || handle_ema4 == INVALID_HANDLE || 
       handle_ema5 == INVALID_HANDLE)
    {
        Print("FGM_Pro Error: Failed to create EMA handles - running in disabled mode.");
        CORE_Enabled = false;
    }
    
    //--- Set indicator buffers
    SetIndexBuffer(0, FGM_EMA1_Buffer, INDICATOR_DATA);
    SetIndexBuffer(1, FGM_EMA2_Buffer, INDICATOR_DATA);
    SetIndexBuffer(2, FGM_EMA3_Buffer, INDICATOR_DATA);
    SetIndexBuffer(3, FGM_EMA4_Buffer, INDICATOR_DATA);
    SetIndexBuffer(4, FGM_EMA5_Buffer, INDICATOR_DATA);
    SetIndexBuffer(5, FGM_Signal_Buffer, INDICATOR_DATA);
    SetIndexBuffer(6, FGM_Strength_Buffer, INDICATOR_DATA);
    SetIndexBuffer(7, FGM_Phase_Buffer, INDICATOR_DATA);
    SetIndexBuffer(8, FGM_Entry_Buffer, INDICATOR_DATA);
    SetIndexBuffer(9, FGM_Exit_Buffer, INDICATOR_DATA);
    SetIndexBuffer(10, FGM_Confluence_Buffer, INDICATOR_DATA);
    
    //--- Configure visibility
    PlotIndexSetInteger(0, PLOT_DRAW_TYPE, InpShowEMA1 ? DRAW_LINE : DRAW_NONE);
    PlotIndexSetInteger(1, PLOT_DRAW_TYPE, InpShowEMA2 ? DRAW_LINE : DRAW_NONE);
    PlotIndexSetInteger(2, PLOT_DRAW_TYPE, InpShowEMA3 ? DRAW_LINE : DRAW_NONE);
    PlotIndexSetInteger(3, PLOT_DRAW_TYPE, InpShowEMA4 ? DRAW_LINE : DRAW_NONE);
    PlotIndexSetInteger(4, PLOT_DRAW_TYPE, InpShowEMA5 ? DRAW_LINE : DRAW_NONE);
    
    //--- Set buffer properties
    int max_period = InpPeriod5;
    for(int i = 0; i < 5; i++)
    {
        PlotIndexSetInteger(i, PLOT_DRAW_BEGIN, max_period);
        PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    }
    
    //--- Initialize buffers as series
    ArraySetAsSeries(FGM_EMA1_Buffer, true);
    ArraySetAsSeries(FGM_EMA2_Buffer, true);
    ArraySetAsSeries(FGM_EMA3_Buffer, true);
    ArraySetAsSeries(FGM_EMA4_Buffer, true);
    ArraySetAsSeries(FGM_EMA5_Buffer, true);
    ArraySetAsSeries(FGM_Signal_Buffer, true);
    ArraySetAsSeries(FGM_Strength_Buffer, true);
    ArraySetAsSeries(FGM_Phase_Buffer, true);
    ArraySetAsSeries(FGM_Entry_Buffer, true);
    ArraySetAsSeries(FGM_Exit_Buffer, true);
    ArraySetAsSeries(FGM_Confluence_Buffer, true);
    
    //--- Set indicator name
    string short_name = StringFormat("FGM Pro(%d,%d,%d,%d,%d)", 
                                     InpPeriod1, InpPeriod2, InpPeriod3, 
                                     InpPeriod4, InpPeriod5);
    IndicatorSetString(INDICATOR_SHORTNAME, short_name);
    
    //--- Set digits precision
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
    
    Print("════════════════════════════════════");
    Print("FGM_Pro initialized for: Pauloeduspbr");
    Print("EMAs: ", InpPeriod1, "/", InpPeriod2, "/", InpPeriod3, "/", 
        InpPeriod4, "/", InpPeriod5, " | CORE_Enabled=", (CORE_Enabled?"true":"false"));
    Print("Mode: ", EnumToString(InpSignalMode));
    Print("Confluence: Percentage Based (No ATR)");
    Print("Primary Cross: ", GetCrossoverName(InpPrimaryCross));
    Print("════════════════════════════════════");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Release indicator handles
    if(handle_ema1 != INVALID_HANDLE) IndicatorRelease(handle_ema1);
    if(handle_ema2 != INVALID_HANDLE) IndicatorRelease(handle_ema2);
    if(handle_ema3 != INVALID_HANDLE) IndicatorRelease(handle_ema3);
    if(handle_ema4 != INVALID_HANDLE) IndicatorRelease(handle_ema4);
    if(handle_ema5 != INVALID_HANDLE) IndicatorRelease(handle_ema5);
    
    //--- Clean up chart objects
    ObjectsDeleteAll(0, "FGM_", -1, -1);
    
    Print("FGM_Pro deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    //--- If core disabled, skip heavy calculations gracefully
    if(!CORE_Enabled)
        return(prev_calculated);
    //--- Check for sufficient data
    int min_bars = InpPeriod5 + 10;
    if(rates_total < min_bars)
        return(0);
    
    //--- Set arrays as series
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(open, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    //--- Copy EMA values
    int copied1 = CopyBuffer(handle_ema1, 0, 0, rates_total, FGM_EMA1_Buffer);
    int copied2 = CopyBuffer(handle_ema2, 0, 0, rates_total, FGM_EMA2_Buffer);
    int copied3 = CopyBuffer(handle_ema3, 0, 0, rates_total, FGM_EMA3_Buffer);
    int copied4 = CopyBuffer(handle_ema4, 0, 0, rates_total, FGM_EMA4_Buffer);
    int copied5 = CopyBuffer(handle_ema5, 0, 0, rates_total, FGM_EMA5_Buffer);
    
    //--- Check copy success
    if(copied1 <= 0 || copied2 <= 0 || copied3 <= 0 || 
       copied4 <= 0 || copied5 <= 0)
    {
        return(0);
    }
    
    //--- Calculate limit
    int limit;
    if(prev_calculated == 0)
    {
        limit = rates_total - min_bars;
    }
    else
    {
        limit = rates_total - prev_calculated + 1;
        if(limit > 2) limit = 2;
    }
    
    //--- Main calculation loop
    for(int i = 0; i < limit && i < rates_total - 1; i++)
    {
        //--- Calculate signal strength
        int strength = CalculateSignalStrength(i);
        FGM_Strength_Buffer[i] = strength;
        
        //--- Calculate market phase
        MARKET_PHASE phase = CalculateMarketPhase(i);
        FGM_Phase_Buffer[i] = (double)phase;
        
        //--- Calculate confluence (Percentage Based)
        double confluence = CalculateConfluence(i, close[i]);
        FGM_Confluence_Buffer[i] = confluence;
        
        //--- Check confluence filter if required
        bool confluence_ok = true;
        if(InpRequireConfluence && confluence < InpConfluenceThreshold)
            confluence_ok = false;
        
        //--- Generate entry/exit signals
        GenerateTradeSignals(i, strength, phase, confluence, confluence_ok, close[i], time[i]);
        
        //--- Update signal buffer
        if(strength >= InpMinStrength && confluence_ok)
        {
            if(phase > PHASE_NEUTRAL)
                FGM_Signal_Buffer[i] = strength; // Bullish
            else if(phase < PHASE_NEUTRAL)
                FGM_Signal_Buffer[i] = -strength; // Bearish
            else
                FGM_Signal_Buffer[i] = 0; // Neutral
        }
        else
        {
            FGM_Signal_Buffer[i] = 0;
        }
    }
    
    //--- Check for alerts
    int check_shift = InpAlertOnBarClose ? 0 : 0;
    if(rates_total > check_shift + 1)
    {
        CheckForAlerts(check_shift, time[check_shift], close[check_shift]);
    }
    
    //--- Update alert cooldown
    if(alert_cooldown_counter > 0)
        alert_cooldown_counter--;
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate Signal Strength (0-5 confirmations)                   |
//+------------------------------------------------------------------+
int CalculateSignalStrength(int index)
{
    int strength = 0;
    
    //--- Check if buffers have valid data
    if(index >= ArraySize(FGM_EMA1_Buffer) || index < 0)
        return 0;
    
    //--- Get EMA values using dynamic array
    double ema[5];
    ema[0] = FGM_EMA1_Buffer[index];
    ema[1] = FGM_EMA2_Buffer[index];
    ema[2] = FGM_EMA3_Buffer[index];
    ema[3] = FGM_EMA4_Buffer[index];
    ema[4] = FGM_EMA5_Buffer[index];
    
    //--- Validate EMA values
    for(int i = 0; i < 5; i++)
    {
        if(ema[i] == EMPTY_VALUE || ema[i] <= 0)
            return 0;
    }
    
    //--- Count bullish confirmations
    for(int i = 0; i < 4; i++)
    {
        if(ema[i] > ema[i+1])
            strength++;
    }
    
    //--- Price above slowest EMA adds extra confirmation
    double current_close = iClose(_Symbol, _Period, index);
    if(current_close > ema[4])
        strength++;
    
    //--- For bearish, invert the logic
    int bearish_strength = 0;
    for(int i = 0; i < 4; i++)
    {
        if(ema[i] < ema[i+1])
            bearish_strength++;
    }
    if(current_close < ema[4])
        bearish_strength++;
    
    //--- Return the dominant strength
    if(bearish_strength > strength)
        return -bearish_strength;
    
    return strength;
}

//+------------------------------------------------------------------+
//| Calculate Market Phase                                           |
//+------------------------------------------------------------------+
MARKET_PHASE CalculateMarketPhase(int index)
{
    if(index >= ArraySize(FGM_EMA1_Buffer) || index < 0)
        return PHASE_NEUTRAL;
    
    double ema[5];
    ema[0] = FGM_EMA1_Buffer[index];
    ema[1] = FGM_EMA2_Buffer[index];
    ema[2] = FGM_EMA3_Buffer[index];
    ema[3] = FGM_EMA4_Buffer[index];
    ema[4] = FGM_EMA5_Buffer[index];
    
    //--- Validate EMA values
    for(int i = 0; i < 5; i++)
    {
        if(ema[i] == EMPTY_VALUE || ema[i] <= 0)
            return PHASE_NEUTRAL;
    }
    
    //--- Get current price
    double current_close = iClose(_Symbol, _Period, index);
    if(current_close <= 0)
        return PHASE_NEUTRAL;
    
    //--- Check price position relative to EMA 200 (Trend Filter)
    bool price_above_trend = (current_close > ema[4]);
    bool price_below_trend = (current_close < ema[4]);
    
    //--- Check EMA alignment
    bool perfect_bull_alignment = true;
    bool perfect_bear_alignment = true;
    int bull_count = 0;
    int bear_count = 0;
    
    for(int i = 0; i < 4; i++)
    {
        if(ema[i] <= ema[i+1])
            perfect_bull_alignment = false;
        else
            bull_count++;
            
        if(ema[i] >= ema[i+1])
            perfect_bear_alignment = false;
        else
            bear_count++;
    }
    
    //--- STRONG_BULL: Perfect EMA alignment AND price above EMA 200
    if(perfect_bull_alignment && price_above_trend)
        return PHASE_STRONG_BULL;
    
    //--- STRONG_BEAR: Perfect EMA alignment AND price below EMA 200
    if(perfect_bear_alignment && price_below_trend)
        return PHASE_STRONG_BEAR;
    
    //--- WEAK_BULL: 3+ bullish conditions (Price doesn't strictly need to be above EMA 200 for early reversal)
    if(bull_count >= 3)
        return PHASE_WEAK_BULL;
    
    //--- WEAK_BEAR: 3+ bearish conditions
    if(bear_count >= 3)
        return PHASE_WEAK_BEAR;
    
    return PHASE_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Calculate Confluence (Percentage Based - No ATR)                 |
//+------------------------------------------------------------------+
double CalculateConfluence(int index, double current_price)
{
    if(index < 0 || index >= ArraySize(FGM_EMA1_Buffer))
        return 0.0;

    double ema1 = FGM_EMA1_Buffer[index];
    double ema5 = FGM_EMA5_Buffer[index];

    if(ema1 == EMPTY_VALUE || ema5 == EMPTY_VALUE || current_price <= 0)
        return 0.0;
    
    //--- Calculate range between fastest and slowest EMA
    double ema_range = MathAbs(ema1 - ema5);
    
    //--- Calculate range as percentage of price
    double range_percent = (ema_range / current_price) * 100.0;
    
    double confluence = 0.0;
    
    //--- Use configurable Percentage thresholds
    if(range_percent < InpConfRangeMax)
        confluence = 100.0;
    else if(range_percent < InpConfRangeHigh)
        confluence = 75.0;
    else if(range_percent < InpConfRangeMed)
        confluence = 50.0;
    else if(range_percent < InpConfRangeLow)
        confluence = 25.0;
    else
        confluence = 10.0;
    
    return confluence;
}

//+------------------------------------------------------------------+
//| Generate Trade Signals                                           |
//+------------------------------------------------------------------+
void GenerateTradeSignals(int index, int strength, MARKET_PHASE phase, 
                          double confluence, bool confluence_ok, 
                          double price, datetime time)
{
    FGM_Entry_Buffer[index] = 0;
    FGM_Exit_Buffer[index] = 0;
    
    //--- Determine minimum strength based on signal mode
    int min_strength = InpMinStrength;
    if(InpSignalMode == MODE_CONSERVATIVE && min_strength < 4)
        min_strength = 4;
    else if(InpSignalMode == MODE_AGGRESSIVE && min_strength > 2)
        min_strength = 2;
    
    //--- Get crossover EMAs based on configuration
    double ema_fast_curr = 0, ema_slow_curr = 0;
    double ema_fast_prev = 0, ema_slow_prev = 0;
    
    if(index > 0 && index < ArraySize(FGM_EMA1_Buffer) - 1)
    {
        //--- Determine which EMAs to use for crossover
        int fast_idx = 0, slow_idx = 1;
        
        switch(InpPrimaryCross)
        {
            case CROSS_EMA1_EMA2:
                fast_idx = 0; slow_idx = 1;
                break;
            case CROSS_EMA2_EMA3:
                fast_idx = 1; slow_idx = 2;
                break;
            case CROSS_EMA3_EMA4:
                fast_idx = 2; slow_idx = 3;
                break;
            case CROSS_CUSTOM:
                fast_idx = InpCustomCross1 - 1;
                slow_idx = InpCustomCross2 - 1;
                break;
        }
        
        //--- Get values based on indices
        switch(fast_idx)
        {
            case 0: ema_fast_curr = FGM_EMA1_Buffer[index]; ema_fast_prev = FGM_EMA1_Buffer[index + 1]; break;
            case 1: ema_fast_curr = FGM_EMA2_Buffer[index]; ema_fast_prev = FGM_EMA2_Buffer[index + 1]; break;
            case 2: ema_fast_curr = FGM_EMA3_Buffer[index]; ema_fast_prev = FGM_EMA3_Buffer[index + 1]; break;
            case 3: ema_fast_curr = FGM_EMA4_Buffer[index]; ema_fast_prev = FGM_EMA4_Buffer[index + 1]; break;
            case 4: ema_fast_curr = FGM_EMA5_Buffer[index]; ema_fast_prev = FGM_EMA5_Buffer[index + 1]; break;
        }
        
        switch(slow_idx)
        {
            case 0: ema_slow_curr = FGM_EMA1_Buffer[index]; ema_slow_prev = FGM_EMA1_Buffer[index + 1]; break;
            case 1: ema_slow_curr = FGM_EMA2_Buffer[index]; ema_slow_prev = FGM_EMA2_Buffer[index + 1]; break;
            case 2: ema_slow_curr = FGM_EMA3_Buffer[index]; ema_slow_prev = FGM_EMA3_Buffer[index + 1]; break;
            case 3: ema_slow_curr = FGM_EMA4_Buffer[index]; ema_slow_prev = FGM_EMA4_Buffer[index + 1]; break;
            case 4: ema_slow_curr = FGM_EMA5_Buffer[index]; ema_slow_prev = FGM_EMA5_Buffer[index + 1]; break;
        }
        
        //--- Bullish crossover
        if(ema_fast_prev <= ema_slow_prev && ema_fast_curr > ema_slow_curr)
        {
            // Check if Slow EMA is sloping UP (or at least not sharply down) to avoid false signals
            bool slope_ok = (ema_slow_curr >= ema_slow_prev);
            
            // Signal Condition: Strength + Confluence + Price above Slow MA (Sanity) + Slope
            if(strength >= min_strength && confluence_ok && price > ema_slow_curr && slope_ok)
            {
                FGM_Entry_Buffer[index] = 1; // Buy Signal
                DrawSignalArrow(index, price, time, true);
            }
        }
        //--- Bearish crossover
        else if(ema_fast_prev >= ema_slow_prev && ema_fast_curr < ema_slow_curr)
        {
            // Check if Slow EMA is sloping DOWN
            bool slope_ok = (ema_slow_curr <= ema_slow_prev);
            
            // Signal Condition: Strength + Confluence + Price below Slow MA (Sanity) + Slope
            if(MathAbs(strength) >= min_strength && confluence_ok && price < ema_slow_curr && slope_ok)
            {
                FGM_Entry_Buffer[index] = -1; // Sell Signal
                DrawSignalArrow(index, price, time, false);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Signal Arrow                                                |
//+------------------------------------------------------------------+
void DrawSignalArrow(int index, double price, datetime time, bool is_buy)
{
    if(!InpShowArrows) return;
    
    string name = "FGM_Arrow_" + TimeToString(time, TIME_DATE|TIME_MINUTES);
    
    //--- Remove old arrow if exists
    if(ObjectFind(0, name) >= 0)
        ObjectDelete(0, name);
        
    if(is_buy)
    {
        ObjectCreate(0, name, OBJ_ARROW_BUY, 0, time, price - InpArrowDistance * _Point);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    }
    else
    {
        ObjectCreate(0, name, OBJ_ARROW_SELL, 0, time, price + InpArrowDistance * _Point);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    }
}

//+------------------------------------------------------------------+
//| Check for Alerts                                                 |
//+------------------------------------------------------------------+
void CheckForAlerts(int shift, datetime bar_time, double price)
{
    if(!InpEnableAlerts && !InpEnablePush && !InpEnableEmail)
        return;
        
    //--- Check cooldown
    if(alert_cooldown_counter > 0)
        return;
        
    //--- Check for new signal
    int entry_signal = (int)FGM_Entry_Buffer[shift];
    
    if(entry_signal != 0)
    {
        //--- Avoid duplicate alerts for same bar
        if(bar_time == last_alert_time)
            return;
            
        string type = (entry_signal > 0) ? "BUY" : "SELL";
        int strength = (int)MathAbs(FGM_Strength_Buffer[shift]);
        double confluence = FGM_Confluence_Buffer[shift];
        MARKET_PHASE phase = (MARKET_PHASE)FGM_Phase_Buffer[shift];
        
        SendAdvancedAlert(type, bar_time, price, strength, confluence, phase);
        
        last_alert_time = bar_time;
        alert_cooldown_counter = InpAlertCooldown;
    }
}

//+------------------------------------------------------------------+
//| Send Advanced Alert                                              |
//+------------------------------------------------------------------+
void SendAdvancedAlert(string signal_type, datetime alert_time, double price,
                       int strength, double confluence, MARKET_PHASE phase)
{
    string message = StringFormat("FGM Pro Signal: %s\nSymbol: %s | Time: %s\nPrice: %.5f",
                                  signal_type, _Symbol, TimeToString(alert_time, TIME_MINUTES), price);
                                  
    if(InpShowStrength)
        message += StringFormat("\nStrength: %d/5 Stars", strength);
        
    if(InpShowConfluence)
        message += StringFormat("\nConfluence: %.1f%%", confluence);
        
    if(InpShowMarketPhase)
        message += StringFormat("\nPhase: %s", GetPhaseString(phase));
        
    if(InpShowEMAValues)
    {
        message += StringFormat("\nEMAs: %.5f / %.5f / %.5f", 
                                FGM_EMA1_Buffer[0], FGM_EMA3_Buffer[0], FGM_EMA5_Buffer[0]);
    }
    
    if(InpEnableAlerts)
        Alert(message);
        
    if(InpEnablePush)
        SendNotification(message);
        
    if(InpEnableEmail)
        SendMail("FGM Pro Signal", message);
}

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
string GetCrossoverName(CROSSOVER_TYPE type)
{
    switch(type)
    {
        case CROSS_EMA1_EMA2: return "EMA1 x EMA2 (Fastest)";
        case CROSS_EMA2_EMA3: return "EMA2 x EMA3 (Medium)";
        case CROSS_EMA3_EMA4: return "EMA3 x EMA4 (Slow)";
        case CROSS_CUSTOM:    return "Custom Crossover";
        default:              return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Get Market Phase String                                          |
//+------------------------------------------------------------------+
string GetPhaseString(MARKET_PHASE phase)
{
    switch(phase)
    {
        case PHASE_STRONG_BULL: return "Strong Bull";
        case PHASE_WEAK_BULL:   return "Weak Bull";
        case PHASE_NEUTRAL:     return "Neutral";
        case PHASE_WEAK_BEAR:   return "Weak Bear";
        case PHASE_STRONG_BEAR: return "Strong Bear";
        default:                return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Public Functions for EA Integration                              |
//+------------------------------------------------------------------+
double GetSignalStrength(int shift = 0)
{
    if(shift < 0 || shift >= ArraySize(FGM_Strength_Buffer)) return 0;
    return FGM_Strength_Buffer[shift];
}

int GetMarketPhase(int shift = 0)
{
    if(shift < 0 || shift >= ArraySize(FGM_Phase_Buffer)) return PHASE_NEUTRAL;
    return (int)FGM_Phase_Buffer[shift];
}

double GetConfluence(int shift = 0)
{
    if(shift < 0 || shift >= ArraySize(FGM_Confluence_Buffer)) return 0;
    return FGM_Confluence_Buffer[shift];
}

bool HasEntrySignal(int shift = 0)
{
    if(shift < 0 || shift >= ArraySize(FGM_Entry_Buffer)) return false;
    return FGM_Entry_Buffer[shift] != 0;
}

int GetEntrySignal(int shift = 0)
{
    if(shift < 0 || shift >= ArraySize(FGM_Entry_Buffer)) return 0;
    return (int)FGM_Entry_Buffer[shift];
}
//+------------------------------------------------------------------+
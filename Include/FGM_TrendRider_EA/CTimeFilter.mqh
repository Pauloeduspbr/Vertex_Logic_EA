//+------------------------------------------------------------------+
//|                                                  CTimeFilter.mqh |
//|                                 Copyright 2025, Pauloeduspbr     |
//|                      FGM Trend Rider - Versão Platina Final      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Pauloeduspbr"
#property version   "1.00"
#property strict

#ifndef CTIMEFILTER_MQH
#define CTIMEFILTER_MQH

#include "CAssetSpecs.mqh"

//+------------------------------------------------------------------+
//| Enumeração de Sessão Forex                                       |
//+------------------------------------------------------------------+
enum ENUM_FOREX_SESSION
{
   SESSION_SYDNEY,      // Sydney (22:00-07:00 UTC)
   SESSION_TOKYO,       // Tóquio (00:00-09:00 UTC)
   SESSION_LONDON,      // Londres (07:00-16:00 UTC)
   SESSION_NEWYORK,     // Nova York (12:00-21:00 UTC)
   SESSION_OVERLAP,     // Overlap London/NY (12:00-16:00 UTC)
   SESSION_NONE         // Fora de sessão
};

//+------------------------------------------------------------------+
//| Estrutura de configuração de horário B3                          |
//+------------------------------------------------------------------+
struct B3TimeConfig
{
   //--- Dias da semana
   bool     sundayActive;
   bool     mondayActive;
   bool     tuesdayActive;
   bool     wednesdayActive;
   bool     thursdayActive;
   bool     fridayActive;
   bool     saturdayActive;
   
   //--- Horários por dia
   string   mondayStart;
   string   mondayEnd;
   string   tuesdayStart;
   string   tuesdayEnd;
   string   wednesdayStart;
   string   wednesdayEnd;
   string   thursdayStart;
   string   thursdayEnd;
   string   fridayStart;
   string   fridayEnd;
   
   //--- Pausa almoço
   bool     lunchPauseActive;
   string   lunchStart;
   string   lunchEnd;
   
   //--- Soft/Hard Exit
   int      softExitMinutes;     // Minutos antes do fim para não abrir novas
   int      hardExitMinutes;     // Minutos antes do fim para fechar tudo
};

//+------------------------------------------------------------------+
//| Estrutura de configuração de horário Forex                       |
//+------------------------------------------------------------------+
struct ForexTimeConfig
{
   //--- Dias da semana
   bool     sundayActive;
   bool     mondayActive;
   bool     tuesdayActive;
   bool     wednesdayActive;
   bool     thursdayActive;
   bool     fridayActive;
   bool     saturdayActive;
   
   //--- Horários específicos
   string   sundayStart;         // Abertura domingo
   string   sundayEnd;
   string   fridayEnd;           // Fechamento sexta
   
   //--- Horários Gerais (Server Time)
   string   startTime;           // Início geral (ex: 00:00)
   string   endTime;             // Fim geral (ex: 23:59)
   
   //--- Sessões permitidas
   bool     allowSydney;
   bool     allowTokyo;
   bool     allowLondon;
   bool     allowNewYork;
   bool     preferOverlap;
   
   //--- Rollover
   bool     avoidRollover;
   string   rolloverStart;       // UTC
   string   rolloverEnd;         // UTC
   
   //--- Soft/Hard Exit
   int      softExitMinutes;
   int      hardExitMinutes;
   
   //--- Ajustes baixa liquidez
   int      lowLiqMinStrength;
   double   lowLiqLotMult;
   int      lowLiqMaxSpread;
};

//+------------------------------------------------------------------+
//| Estrutura de resultado do filtro de tempo                        |
//+------------------------------------------------------------------+
struct TimeFilterResult
{
   bool     canTrade;            // Pode operar
   bool     canOpenNew;          // Pode abrir nova posição
   bool     shouldClose;         // Deve fechar posição
   bool     isSoftExit;          // Em período soft exit
   bool     isHardExit;          // Em período hard exit
   bool     isLunchPause;        // Em pausa de almoço
   bool     isRollover;          // Em período de rollover
   bool     isLowLiquidity;      // Em baixa liquidez
   
   ENUM_FOREX_SESSION currentSession; // Sessão atual (Forex)
   string   message;             // Mensagem descritiva
   
   //--- Ajustes para baixa liquidez
   int      requiredStrength;    // Força mínima ajustada
   double   lotMultiplier;       // Multiplicador de lote
   int      maxSpread;           // Spread máximo ajustado
};

//+------------------------------------------------------------------+
//| Classe de Filtro de Tempo                                        |
//+------------------------------------------------------------------+
class CTimeFilter
{
private:
   CAssetSpecs*      m_asset;            // Ponteiro para especificações
   B3TimeConfig      m_b3Config;         // Configuração B3
   ForexTimeConfig   m_fxConfig;         // Configuração Forex
   bool              m_initialized;      // Flag de inicialização
   string            m_lastError;        // Último erro
   
   //--- Offset de timezone (broker vs UTC)
   int               m_brokerOffset;     // Offset do broker em horas
   
   //--- Métodos privados
   int               TimeToMinutes(string timeStr);
   bool              IsInTimeRange(int currentMinutes, int startMinutes, int endMinutes);
   bool              IsInTimeRange(datetime time, string startStr, string endStr);
   int               GetDayOfWeek();
   int               GetCurrentMinutes();
   datetime          GetCurrentTime();
   datetime          GetUTCTime();
   
   //--- Validação por tipo de mercado
   TimeFilterResult  CheckB3Time();
   TimeFilterResult  CheckForexTime();
   
public:
                     CTimeFilter();
                    ~CTimeFilter();
   
   //--- Inicialização
   bool              Init(CAssetSpecs* asset, int brokerOffsetHours = 0);
   void              Deinit();
   bool              IsInitialized() { return m_initialized; }
   string            GetLastError() { return m_lastError; }
   
   //--- Configuração B3
   void              SetB3Config(const B3TimeConfig& config) { m_b3Config = config; }
   B3TimeConfig      GetB3Config() { return m_b3Config; }
   void              SetDefaultB3Config();
   
   //--- Configuração Forex
   void              SetForexConfig(const ForexTimeConfig& config) { m_fxConfig = config; }
   ForexTimeConfig   GetForexConfig() { return m_fxConfig; }
   void              SetDefaultForexConfig();
   
   //--- Verificação principal
   TimeFilterResult  Check();
   bool              CanTrade();
   bool              CanOpenNewPosition();
   bool              ShouldClosePositions();
   
   //--- Verificações específicas
   bool              IsTradingDay();
   bool              IsInTradingHours();
   bool              IsInLunchPause();
   bool              IsSoftExitPeriod();
   bool              IsHardExitPeriod();
   bool              IsInRollover();
   bool              IsLowLiquidity();
   
   //--- Sessões Forex
   ENUM_FOREX_SESSION GetCurrentForexSession();
   bool              IsInAllowedSession();
   bool              IsInOverlapSession();
   string            GetSessionName(ENUM_FOREX_SESSION session);
   
   //--- Informações
   int               MinutesToClose();
   int               MinutesToOpen();
   string            GetNextTradingWindow();
   
   //--- Debug
   void              PrintTimeInfo();
   void              PrintConfig();
};

//+------------------------------------------------------------------+
//| Construtor                                                        |
//+------------------------------------------------------------------+
CTimeFilter::CTimeFilter()
{
   m_asset = NULL;
   m_initialized = false;
   m_lastError = "";
   m_brokerOffset = 0;
   
   SetDefaultB3Config();
   SetDefaultForexConfig();
}

//+------------------------------------------------------------------+
//| Destrutor                                                         |
//+------------------------------------------------------------------+
CTimeFilter::~CTimeFilter()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Inicialização                                                     |
//+------------------------------------------------------------------+
bool CTimeFilter::Init(CAssetSpecs* asset, int brokerOffsetHours = 0)
{
   if(asset == NULL || !asset.IsInitialized())
   {
      m_lastError = "CAssetSpecs inválido ou não inicializado";
      return false;
   }
   
   m_asset = asset;
   m_brokerOffset = brokerOffsetHours;
   
   m_initialized = true;
   Print("CTimeFilter: Inicializado. Broker Offset: ", brokerOffsetHours, "h");
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinicialização                                                   |
//+------------------------------------------------------------------+
void CTimeFilter::Deinit()
{
   m_initialized = false;
}

//+------------------------------------------------------------------+
//| Definir configuração padrão B3                                   |
//+------------------------------------------------------------------+
void CTimeFilter::SetDefaultB3Config()
{
   //--- Dias ativos
   m_b3Config.sundayActive = false;
   m_b3Config.mondayActive = true;
   m_b3Config.tuesdayActive = true;
   m_b3Config.wednesdayActive = true;
   m_b3Config.thursdayActive = true;
   m_b3Config.fridayActive = true;
   m_b3Config.saturdayActive = false;
   
   //--- Horários (BRT) - Abertura real do mercado
   //--- IMPORTANTE: Usar 09:00 para capturar sinais logo na abertura.
   //--- O mercado B3 abre oficialmente às 09:00 para mini-índice.
   m_b3Config.mondayStart = "09:00";      // Abertura do mercado
   m_b3Config.mondayEnd = "17:30";
   m_b3Config.tuesdayStart = "09:00";
   m_b3Config.tuesdayEnd = "17:30";
   m_b3Config.wednesdayStart = "09:00";
   m_b3Config.wednesdayEnd = "17:30";
   m_b3Config.thursdayStart = "09:00";
   m_b3Config.thursdayEnd = "17:30";
   m_b3Config.fridayStart = "09:00";
   m_b3Config.fridayEnd = "17:30";
   
   //--- Pausa almoço - DESATIVADA (mercado opera normalmente)
   m_b3Config.lunchPauseActive = false;
   m_b3Config.lunchStart = "12:00";
   m_b3Config.lunchEnd = "13:00";
   
   //--- Soft/Hard Exit
   m_b3Config.softExitMinutes = 45;
   m_b3Config.hardExitMinutes = 15;
}

//+------------------------------------------------------------------+
//| Definir configuração padrão Forex                                |
//+------------------------------------------------------------------+
void CTimeFilter::SetDefaultForexConfig()
{
   //--- Dias ativos
   m_fxConfig.sundayActive = true;
   m_fxConfig.mondayActive = true;
   m_fxConfig.tuesdayActive = true;
   m_fxConfig.wednesdayActive = true;
   m_fxConfig.thursdayActive = true;
   m_fxConfig.fridayActive = true;
   m_fxConfig.saturdayActive = false;
   
   //--- Horários específicos (UTC)
   m_fxConfig.sundayStart = "22:00";
   m_fxConfig.sundayEnd = "23:59";
   m_fxConfig.fridayEnd = "18:00";
   
   m_fxConfig.startTime = "00:00";
   m_fxConfig.endTime = "23:59";
   
   //--- Sessões permitidas
   m_fxConfig.allowSydney = false;
   m_fxConfig.allowTokyo = false;
   m_fxConfig.allowLondon = true;
   m_fxConfig.allowNewYork = true;
   m_fxConfig.preferOverlap = true;
   
   //--- Rollover
   m_fxConfig.avoidRollover = true;
   m_fxConfig.rolloverStart = "21:00";
   m_fxConfig.rolloverEnd = "00:00";
   
   //--- Soft/Hard Exit
   m_fxConfig.softExitMinutes = 30;
   m_fxConfig.hardExitMinutes = 15;
   
   //--- Baixa liquidez
   m_fxConfig.lowLiqMinStrength = 5;
   m_fxConfig.lowLiqLotMult = 0.5;
   m_fxConfig.lowLiqMaxSpread = 15;
}

//+------------------------------------------------------------------+
//| Converter string de hora para minutos                            |
//+------------------------------------------------------------------+
int CTimeFilter::TimeToMinutes(string timeStr)
{
   string parts[];
   int count = StringSplit(timeStr, ':', parts);
   
   if(count < 2)
      return 0;
   
   int hours = (int)StringToInteger(parts[0]);
   int minutes = (int)StringToInteger(parts[1]);
   
   return hours * 60 + minutes;
}

//+------------------------------------------------------------------+
//| Verificar se está em faixa de horário                            |
//+------------------------------------------------------------------+
bool CTimeFilter::IsInTimeRange(int currentMinutes, int startMinutes, int endMinutes)
{
   if(startMinutes <= endMinutes)
   {
      return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
   }
   else
   {
      //--- Atravessa meia-noite
      return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
   }
}

//+------------------------------------------------------------------+
//| Verificar se está em faixa de horário (por strings)              |
//+------------------------------------------------------------------+
bool CTimeFilter::IsInTimeRange(datetime time, string startStr, string endStr)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   int currentMinutes = dt.hour * 60 + dt.min;
   
   int startMinutes = TimeToMinutes(startStr);
   int endMinutes = TimeToMinutes(endStr);
   
   return IsInTimeRange(currentMinutes, startMinutes, endMinutes);
}

//+------------------------------------------------------------------+
//| Obter dia da semana                                              |
//+------------------------------------------------------------------+
int CTimeFilter::GetDayOfWeek()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.day_of_week;
}

//+------------------------------------------------------------------+
//| Obter minutos atuais                                             |
//+------------------------------------------------------------------+
int CTimeFilter::GetCurrentMinutes()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.hour * 60 + dt.min;
}

//+------------------------------------------------------------------+
//| Obter tempo atual do servidor                                    |
//+------------------------------------------------------------------+
datetime CTimeFilter::GetCurrentTime()
{
   return TimeCurrent();
}

//+------------------------------------------------------------------+
//| Obter tempo UTC                                                  |
//+------------------------------------------------------------------+
datetime CTimeFilter::GetUTCTime()
{
   return TimeCurrent() - (m_brokerOffset * 3600);
}

//+------------------------------------------------------------------+
//| Verificação principal                                            |
//+------------------------------------------------------------------+
TimeFilterResult CTimeFilter::Check()
{
   TimeFilterResult result;
   ZeroMemory(result);
   
   result.canTrade = false;
   result.canOpenNew = false;
   result.shouldClose = false;
   result.lotMultiplier = 1.0;
   result.requiredStrength = 3;
   result.maxSpread = 999;
   result.currentSession = SESSION_NONE;
   
   if(!m_initialized || m_asset == NULL)
   {
      result.message = "TimeFilter não inicializado";
      return result;
   }
   
   //--- Verificar por tipo de mercado
   if(m_asset.IsB3())
      return CheckB3Time();
   else if(m_asset.IsForex())
      return CheckForexTime();
   else
   {
      //--- Para outros mercados, permitir sempre
      result.canTrade = true;
      result.canOpenNew = true;
      result.message = "Mercado sem restrições de horário";
      return result;
   }
}

//+------------------------------------------------------------------+
//| Verificar horário B3                                             |
//+------------------------------------------------------------------+
TimeFilterResult CTimeFilter::CheckB3Time()
{
   TimeFilterResult result;
   ZeroMemory(result);
   
   result.canTrade = false;
   result.canOpenNew = false;
   result.lotMultiplier = 1.0;
   result.requiredStrength = 3;
   result.currentSession = SESSION_NONE;
   
   int dayOfWeek = GetDayOfWeek();
   int currentMinutes = GetCurrentMinutes();
   
   //--- Verificar dia ativo
   bool dayActive = false;
   string startTime = "";
   string endTime = "";
   
   switch(dayOfWeek)
   {
      case 0: // Domingo
         dayActive = m_b3Config.sundayActive;
         break;
      case 1: // Segunda
         dayActive = m_b3Config.mondayActive;
         startTime = m_b3Config.mondayStart;
         endTime = m_b3Config.mondayEnd;
         break;
      case 2: // Terça
         dayActive = m_b3Config.tuesdayActive;
         startTime = m_b3Config.tuesdayStart;
         endTime = m_b3Config.tuesdayEnd;
         break;
      case 3: // Quarta
         dayActive = m_b3Config.wednesdayActive;
         startTime = m_b3Config.wednesdayStart;
         endTime = m_b3Config.wednesdayEnd;
         break;
      case 4: // Quinta
         dayActive = m_b3Config.thursdayActive;
         startTime = m_b3Config.thursdayStart;
         endTime = m_b3Config.thursdayEnd;
         break;
      case 5: // Sexta
         dayActive = m_b3Config.fridayActive;
         startTime = m_b3Config.fridayStart;
         endTime = m_b3Config.fridayEnd;
         break;
      case 6: // Sábado
         dayActive = m_b3Config.saturdayActive;
         break;
   }
   
   if(!dayActive)
   {
      result.message = "Dia não ativo para operação";
      return result;
   }
   
   //--- Verificar horário de trading
   int startMinutes = TimeToMinutes(startTime);
   int endMinutes = TimeToMinutes(endTime);
   
   if(!IsInTimeRange(currentMinutes, startMinutes, endMinutes))
   {
      result.message = "Fora do horário de trading";
      return result;
   }
   
   //--- Verificar pausa de almoço
   if(m_b3Config.lunchPauseActive)
   {
      int lunchStart = TimeToMinutes(m_b3Config.lunchStart);
      int lunchEnd = TimeToMinutes(m_b3Config.lunchEnd);
      
      if(IsInTimeRange(currentMinutes, lunchStart, lunchEnd))
      {
         result.isLunchPause = true;
         result.canTrade = true;      // Pode gerenciar posições
         result.canOpenNew = false;   // Não abre novas
         result.message = "Pausa para almoço - apenas gestão de posições";
         return result;
      }
   }
   
   //--- Verificar Hard Exit
   int hardExitStart = endMinutes - m_b3Config.hardExitMinutes;
   if(currentMinutes >= hardExitStart)
   {
      result.isHardExit = true;
      result.shouldClose = true;
      result.canTrade = true;
      result.canOpenNew = false;
      result.message = "Hard Exit - fechar posições imediatamente";
      return result;
   }
   
   //--- Verificar Soft Exit
   int softExitStart = endMinutes - m_b3Config.softExitMinutes;
   if(currentMinutes >= softExitStart)
   {
      result.isSoftExit = true;
      result.canTrade = true;
      result.canOpenNew = false;
      result.message = "Soft Exit - apenas gestão de posições";
      return result;
   }
   
   //--- Tudo OK
   result.canTrade = true;
   result.canOpenNew = true;
   result.message = "Horário normal de operação";
   
   return result;
}

//+------------------------------------------------------------------+
//| Verificar horário Forex                                          |
//+------------------------------------------------------------------+
TimeFilterResult CTimeFilter::CheckForexTime()
{
   TimeFilterResult result;
   ZeroMemory(result);
   
   result.canTrade = false;
   result.canOpenNew = false;
   result.lotMultiplier = 1.0;
   result.requiredStrength = 3;
   
   int dayOfWeek = GetDayOfWeek();
   datetime utcTime = GetUTCTime();
   MqlDateTime utcDt;
   TimeToStruct(utcTime, utcDt);
   int utcMinutes = utcDt.hour * 60 + utcDt.min;
   
   //--- Verificar dia ativo
   bool dayActive = false;
   
   switch(dayOfWeek)
   {
      case 0: dayActive = m_fxConfig.sundayActive; break;
      case 1: dayActive = m_fxConfig.mondayActive; break;
      case 2: dayActive = m_fxConfig.tuesdayActive; break;
      case 3: dayActive = m_fxConfig.wednesdayActive; break;
      case 4: dayActive = m_fxConfig.thursdayActive; break;
      case 5: dayActive = m_fxConfig.fridayActive; break;
      case 6: dayActive = m_fxConfig.saturdayActive; break;
   }
   
   if(!dayActive)
   {
      result.message = "Dia não ativo para operação";
      result.currentSession = SESSION_NONE;
      return result;
   }
   
   //--- Verificar horário geral (Server Time)
   //--- Isso permite que o usuário restrinja o horário mesmo em Forex (ex: 09:00 as 17:00)
   int currentMinutes = GetCurrentMinutes(); // Server Time
   int startMinutes = TimeToMinutes(m_fxConfig.startTime);
   int endMinutes = TimeToMinutes(m_fxConfig.endTime);
   
   //--- DEBUG TEMPORÁRIO
   // Print(StringFormat("DEBUG TIME: Current=%d Start=%d End=%d ConfigStart='%s' ConfigEnd='%s'", 
   //       currentMinutes, startMinutes, endMinutes, m_fxConfig.startTime, m_fxConfig.endTime));
   
   if(!IsInTimeRange(currentMinutes, startMinutes, endMinutes))
   {
      result.message = StringFormat("Fora do horário de trading (Forex) - Curr:%d Start:%d End:%d", 
                                    currentMinutes, startMinutes, endMinutes);
      result.currentSession = SESSION_NONE;
      return result;
   }
   
   //--- Domingo: horário especial
   if(dayOfWeek == 0)
   {
      int sundayStart = TimeToMinutes(m_fxConfig.sundayStart);
      if(utcMinutes < sundayStart)
      {
         result.message = "Mercado ainda não abriu";
         result.currentSession = SESSION_NONE;
         return result;
      }
   }
   
   //--- Sexta: verificar fechamento
   if(dayOfWeek == 5)
   {
      int fridayEnd = TimeToMinutes(m_fxConfig.fridayEnd);
      
      //--- Hard Exit
      int hardExitStart = fridayEnd - m_fxConfig.hardExitMinutes;
      if(utcMinutes >= hardExitStart)
      {
         result.isHardExit = true;
         result.shouldClose = true;
         result.canTrade = true;
         result.canOpenNew = false;
         result.message = "Sexta - Hard Exit antes do fechamento";
         return result;
      }
      
      //--- Soft Exit
      int softExitStart = fridayEnd - m_fxConfig.softExitMinutes;
      if(utcMinutes >= softExitStart)
      {
         result.isSoftExit = true;
         result.canTrade = true;
         result.canOpenNew = false;
         result.message = "Sexta - Soft Exit antes do fechamento";
         return result;
      }
      
      if(utcMinutes >= fridayEnd)
      {
         result.message = "Mercado fechado";
         result.currentSession = SESSION_NONE;
         return result;
      }
   }
   
   //--- Verificar rollover
   if(m_fxConfig.avoidRollover)
   {
      int rolloverStart = TimeToMinutes(m_fxConfig.rolloverStart);
      int rolloverEnd = TimeToMinutes(m_fxConfig.rolloverEnd);
      
      if(IsInTimeRange(utcMinutes, rolloverStart, rolloverEnd))
      {
         result.isRollover = true;
         result.canTrade = true;      // Pode gerenciar
         result.canOpenNew = false;   // Não abre
         result.message = "Período de rollover - evitar novas posições";
         return result;
      }
   }
   
   //--- Determinar sessão atual
   result.currentSession = GetCurrentForexSession();
   
   //--- Verificar se sessão é permitida
   bool sessionAllowed = false;
   result.isLowLiquidity = false;
   
   switch(result.currentSession)
   {
      case SESSION_SYDNEY:
         sessionAllowed = m_fxConfig.allowSydney;
         if(!m_fxConfig.allowSydney && !m_fxConfig.allowTokyo && 
            !m_fxConfig.allowLondon && !m_fxConfig.allowNewYork)
            sessionAllowed = true; // Se nenhuma selecionada, permite todas
         break;
         
      case SESSION_TOKYO:
         sessionAllowed = m_fxConfig.allowTokyo;
         break;
         
      case SESSION_LONDON:
         sessionAllowed = m_fxConfig.allowLondon;
         break;
         
      case SESSION_NEWYORK:
         sessionAllowed = m_fxConfig.allowNewYork;
         break;
         
      case SESSION_OVERLAP:
         sessionAllowed = true; // Overlap sempre permitido
         break;
         
      default:
         sessionAllowed = false;
         break;
   }
   
   //--- Ajustes para baixa liquidez (Sydney/Tokyo)
   if(result.currentSession == SESSION_SYDNEY || result.currentSession == SESSION_TOKYO)
   {
      result.isLowLiquidity = true;
      result.requiredStrength = m_fxConfig.lowLiqMinStrength;
      result.lotMultiplier = m_fxConfig.lowLiqLotMult;
      result.maxSpread = m_fxConfig.lowLiqMaxSpread;
   }
   
   if(!sessionAllowed)
   {
      result.canTrade = true;         // Pode gerenciar posições existentes
      result.canOpenNew = false;      // Não abre novas
      result.message = "Sessão " + GetSessionName(result.currentSession) + " não permitida";
      return result;
   }
   
   //--- Tudo OK
   result.canTrade = true;
   result.canOpenNew = true;
   result.message = "Sessão " + GetSessionName(result.currentSession) + " ativa";
   
   return result;
}

//+------------------------------------------------------------------+
//| Verificar se pode operar (simplificado)                          |
//+------------------------------------------------------------------+
bool CTimeFilter::CanTrade()
{
   TimeFilterResult result = Check();
   return result.canTrade;
}

//+------------------------------------------------------------------+
//| Verificar se pode abrir nova posição                             |
//+------------------------------------------------------------------+
bool CTimeFilter::CanOpenNewPosition()
{
   TimeFilterResult result = Check();
   return result.canOpenNew;
}

//+------------------------------------------------------------------+
//| Verificar se deve fechar posições                                |
//+------------------------------------------------------------------+
bool CTimeFilter::ShouldClosePositions()
{
   TimeFilterResult result = Check();
   return result.shouldClose;
}

//+------------------------------------------------------------------+
//| Verificar se é dia de trading                                    |
//+------------------------------------------------------------------+
bool CTimeFilter::IsTradingDay()
{
   int dayOfWeek = GetDayOfWeek();
   
   if(m_asset == NULL)
      return false;
   
   if(m_asset.IsB3())
   {
      switch(dayOfWeek)
      {
         case 0: return m_b3Config.sundayActive;
         case 1: return m_b3Config.mondayActive;
         case 2: return m_b3Config.tuesdayActive;
         case 3: return m_b3Config.wednesdayActive;
         case 4: return m_b3Config.thursdayActive;
         case 5: return m_b3Config.fridayActive;
         case 6: return m_b3Config.saturdayActive;
      }
   }
   else if(m_asset.IsForex())
   {
      switch(dayOfWeek)
      {
         case 0: return m_fxConfig.sundayActive;
         case 1: return m_fxConfig.mondayActive;
         case 2: return m_fxConfig.tuesdayActive;
         case 3: return m_fxConfig.wednesdayActive;
         case 4: return m_fxConfig.thursdayActive;
         case 5: return m_fxConfig.fridayActive;
         case 6: return m_fxConfig.saturdayActive;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Verificar se está em horário de trading                          |
//+------------------------------------------------------------------+
bool CTimeFilter::IsInTradingHours()
{
   TimeFilterResult result = Check();
   return result.canTrade;
}

//+------------------------------------------------------------------+
//| Verificar se está em pausa de almoço                             |
//+------------------------------------------------------------------+
bool CTimeFilter::IsInLunchPause()
{
   TimeFilterResult result = Check();
   return result.isLunchPause;
}

//+------------------------------------------------------------------+
//| Verificar se está em Soft Exit                                   |
//+------------------------------------------------------------------+
bool CTimeFilter::IsSoftExitPeriod()
{
   TimeFilterResult result = Check();
   return result.isSoftExit;
}

//+------------------------------------------------------------------+
//| Verificar se está em Hard Exit                                   |
//+------------------------------------------------------------------+
bool CTimeFilter::IsHardExitPeriod()
{
   TimeFilterResult result = Check();
   return result.isHardExit;
}

//+------------------------------------------------------------------+
//| Verificar se está em rollover                                    |
//+------------------------------------------------------------------+
bool CTimeFilter::IsInRollover()
{
   TimeFilterResult result = Check();
   return result.isRollover;
}

//+------------------------------------------------------------------+
//| Verificar se está em baixa liquidez                              |
//+------------------------------------------------------------------+
bool CTimeFilter::IsLowLiquidity()
{
   TimeFilterResult result = Check();
   return result.isLowLiquidity;
}

//+------------------------------------------------------------------+
//| Obter sessão Forex atual                                         |
//+------------------------------------------------------------------+
ENUM_FOREX_SESSION CTimeFilter::GetCurrentForexSession()
{
   datetime utcTime = GetUTCTime();
   MqlDateTime utcDt;
   TimeToStruct(utcTime, utcDt);
   int utcMinutes = utcDt.hour * 60 + utcDt.min;
   
   //--- Sessões em UTC:
   //--- Sydney: 22:00-07:00 (atravessa meia-noite)
   //--- Tokyo: 00:00-09:00
   //--- London: 07:00-16:00
   //--- NewYork: 12:00-21:00
   //--- Overlap: 12:00-16:00
   
   int sydneyStart = 22 * 60;   // 22:00
   int sydneyEnd = 7 * 60;      // 07:00
   int tokyoStart = 0;          // 00:00
   int tokyoEnd = 9 * 60;       // 09:00
   int londonStart = 7 * 60;    // 07:00
   int londonEnd = 16 * 60;     // 16:00
   int nyStart = 12 * 60;       // 12:00
   int nyEnd = 21 * 60;         // 21:00
   int overlapStart = 12 * 60;  // 12:00
   int overlapEnd = 16 * 60;    // 16:00
   
   //--- Verificar overlap primeiro (maior prioridade)
   if(IsInTimeRange(utcMinutes, overlapStart, overlapEnd))
      return SESSION_OVERLAP;
   
   //--- Verificar Londres
   if(IsInTimeRange(utcMinutes, londonStart, londonEnd))
      return SESSION_LONDON;
   
   //--- Verificar Nova York
   if(IsInTimeRange(utcMinutes, nyStart, nyEnd))
      return SESSION_NEWYORK;
   
   //--- Verificar Tokyo
   if(IsInTimeRange(utcMinutes, tokyoStart, tokyoEnd))
      return SESSION_TOKYO;
   
   //--- Verificar Sydney (atravessa meia-noite)
   if(IsInTimeRange(utcMinutes, sydneyStart, sydneyEnd))
      return SESSION_SYDNEY;
   
   return SESSION_NONE;
}

//+------------------------------------------------------------------+
//| Verificar se está em sessão permitida                            |
//+------------------------------------------------------------------+
bool CTimeFilter::IsInAllowedSession()
{
   TimeFilterResult result = Check();
   return result.canOpenNew;
}

//+------------------------------------------------------------------+
//| Verificar se está em overlap                                     |
//+------------------------------------------------------------------+
bool CTimeFilter::IsInOverlapSession()
{
   return (GetCurrentForexSession() == SESSION_OVERLAP);
}

//+------------------------------------------------------------------+
//| Obter nome da sessão                                             |
//+------------------------------------------------------------------+
string CTimeFilter::GetSessionName(ENUM_FOREX_SESSION session)
{
   switch(session)
   {
      case SESSION_SYDNEY:  return "Sydney";
      case SESSION_TOKYO:   return "Tokyo";
      case SESSION_LONDON:  return "London";
      case SESSION_NEWYORK: return "New York";
      case SESSION_OVERLAP: return "London/NY Overlap";
      default:              return "Nenhuma";
   }
}

//+------------------------------------------------------------------+
//| Minutos até fechar                                               |
//+------------------------------------------------------------------+
int CTimeFilter::MinutesToClose()
{
   if(!m_initialized || m_asset == NULL)
      return 0;
   
   int currentMinutes = GetCurrentMinutes();
   int dayOfWeek = GetDayOfWeek();
   
   int endMinutes = 0;
   
   if(m_asset.IsB3())
   {
      switch(dayOfWeek)
      {
         case 1: endMinutes = TimeToMinutes(m_b3Config.mondayEnd); break;
         case 2: endMinutes = TimeToMinutes(m_b3Config.tuesdayEnd); break;
         case 3: endMinutes = TimeToMinutes(m_b3Config.wednesdayEnd); break;
         case 4: endMinutes = TimeToMinutes(m_b3Config.thursdayEnd); break;
         case 5: endMinutes = TimeToMinutes(m_b3Config.fridayEnd); break;
         default: return 0;
      }
   }
   else if(m_asset.IsForex() && dayOfWeek == 5)
   {
      endMinutes = TimeToMinutes(m_fxConfig.fridayEnd);
   }
   else
   {
      return 9999; // Forex 24h
   }
   
   if(endMinutes > currentMinutes)
      return endMinutes - currentMinutes;
   
   return 0;
}

//+------------------------------------------------------------------+
//| Minutos até abrir                                                |
//+------------------------------------------------------------------+
int CTimeFilter::MinutesToOpen()
{
   if(!m_initialized || m_asset == NULL)
      return 0;
   
   int currentMinutes = GetCurrentMinutes();
   int dayOfWeek = GetDayOfWeek();
   
   int startMinutes = 0;
   
   if(m_asset.IsB3())
   {
      switch(dayOfWeek)
      {
         case 1: startMinutes = TimeToMinutes(m_b3Config.mondayStart); break;
         case 2: startMinutes = TimeToMinutes(m_b3Config.tuesdayStart); break;
         case 3: startMinutes = TimeToMinutes(m_b3Config.wednesdayStart); break;
         case 4: startMinutes = TimeToMinutes(m_b3Config.thursdayStart); break;
         case 5: startMinutes = TimeToMinutes(m_b3Config.fridayStart); break;
         default: return 0;
      }
   }
   
   if(currentMinutes < startMinutes)
      return startMinutes - currentMinutes;
   
   return 0;
}

//+------------------------------------------------------------------+
//| Obter próxima janela de trading                                  |
//+------------------------------------------------------------------+
string CTimeFilter::GetNextTradingWindow()
{
   int minutesToOpen = MinutesToOpen();
   
   if(minutesToOpen > 0)
   {
      int hours = minutesToOpen / 60;
      int mins = minutesToOpen % 60;
      return StringFormat("Abre em %02d:%02d", hours, mins);
   }
   
   int minutesToClose = MinutesToClose();
   if(minutesToClose > 0 && minutesToClose < 9999)
   {
      int hours = minutesToClose / 60;
      int mins = minutesToClose % 60;
      return StringFormat("Fecha em %02d:%02d", hours, mins);
   }
   
   return "Mercado aberto";
}

//+------------------------------------------------------------------+
//| Imprimir informações de tempo (debug)                            |
//+------------------------------------------------------------------+
void CTimeFilter::PrintTimeInfo()
{
   TimeFilterResult result = Check();
   
   Print("═══════════════════════════════════════════════════════════");
   Print("CTimeFilter - Informações de Tempo");
   Print("═══════════════════════════════════════════════════════════");
   Print("Hora Servidor: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("Hora UTC:      ", TimeToString(GetUTCTime(), TIME_DATE|TIME_MINUTES));
   Print("Dia da Semana: ", GetDayOfWeek());
   Print("───────────────────────────────────────────────────────────");
   Print("Pode Operar:   ", result.canTrade ? "SIM" : "NÃO");
   Print("Pode Abrir:    ", result.canOpenNew ? "SIM" : "NÃO");
   Print("Deve Fechar:   ", result.shouldClose ? "SIM" : "NÃO");
   Print("───────────────────────────────────────────────────────────");
   Print("Soft Exit:     ", result.isSoftExit ? "SIM" : "NÃO");
   Print("Hard Exit:     ", result.isHardExit ? "SIM" : "NÃO");
   Print("Pausa Almoço:  ", result.isLunchPause ? "SIM" : "NÃO");
   Print("Rollover:      ", result.isRollover ? "SIM" : "NÃO");
   Print("Baixa Liquidez:", result.isLowLiquidity ? "SIM" : "NÃO");
   Print("───────────────────────────────────────────────────────────");
   Print("Sessão Atual:  ", GetSessionName(result.currentSession));
   Print("Min p/ Fechar: ", MinutesToClose());
   Print("Min p/ Abrir:  ", MinutesToOpen());
   Print("Próxima Janela:", GetNextTradingWindow());
   Print("───────────────────────────────────────────────────────────");
   Print("Mensagem:      ", result.message);
   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Imprimir configuração (debug)                                    |
//+------------------------------------------------------------------+
void CTimeFilter::PrintConfig()
{
   Print("═══════════════════════════════════════════════════════════");
   Print("CTimeFilter - Configuração");
   Print("═══════════════════════════════════════════════════════════");
   
   if(m_asset != NULL && m_asset.IsB3())
   {
      Print("Mercado: B3");
      Print("───────────────────────────────────────────────────────────");
      Print("Segunda: ", m_b3Config.mondayActive ? "Ativo" : "Inativo", 
            " | ", m_b3Config.mondayStart, " - ", m_b3Config.mondayEnd);
      Print("Terça:   ", m_b3Config.tuesdayActive ? "Ativo" : "Inativo", 
            " | ", m_b3Config.tuesdayStart, " - ", m_b3Config.tuesdayEnd);
      Print("Quarta:  ", m_b3Config.wednesdayActive ? "Ativo" : "Inativo", 
            " | ", m_b3Config.wednesdayStart, " - ", m_b3Config.wednesdayEnd);
      Print("Quinta:  ", m_b3Config.thursdayActive ? "Ativo" : "Inativo", 
            " | ", m_b3Config.thursdayStart, " - ", m_b3Config.thursdayEnd);
      Print("Sexta:   ", m_b3Config.fridayActive ? "Ativo" : "Inativo", 
            " | ", m_b3Config.fridayStart, " - ", m_b3Config.fridayEnd);
      Print("───────────────────────────────────────────────────────────");
      Print("Pausa Almoço: ", m_b3Config.lunchPauseActive ? "Ativo" : "Inativo",
            " | ", m_b3Config.lunchStart, " - ", m_b3Config.lunchEnd);
      Print("Soft Exit: ", m_b3Config.softExitMinutes, " min antes");
      Print("Hard Exit: ", m_b3Config.hardExitMinutes, " min antes");
   }
   else if(m_asset != NULL && m_asset.IsForex())
   {
      Print("Mercado: Forex");
      Print("───────────────────────────────────────────────────────────");
      Print("Sydney:  ", m_fxConfig.allowSydney ? "Permitido" : "Bloqueado");
      Print("Tokyo:   ", m_fxConfig.allowTokyo ? "Permitido" : "Bloqueado");
      Print("London:  ", m_fxConfig.allowLondon ? "Permitido" : "Bloqueado");
      Print("New York:", m_fxConfig.allowNewYork ? "Permitido" : "Bloqueado");
      Print("Overlap: ", m_fxConfig.preferOverlap ? "Preferido" : "Normal");
      Print("───────────────────────────────────────────────────────────");
      Print("Evitar Rollover: ", m_fxConfig.avoidRollover ? "Sim" : "Não");
      Print("Soft Exit: ", m_fxConfig.softExitMinutes, " min antes");
      Print("Hard Exit: ", m_fxConfig.hardExitMinutes, " min antes");
   }
   
   Print("═══════════════════════════════════════════════════════════");
}

#endif // CTIMEFILTER_MQH

//+------------------------------------------------------------------+

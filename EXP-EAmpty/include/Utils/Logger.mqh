#ifndef __EA_OCO_LOGGER_MQH__
#define __EA_OCO_LOGGER_MQH__

enum ELogLevel
{
   LOG_ERR  = 0,
   LOG_INFO = 1,
   LOG_DEBUG = 2
};

class CLogger
{
private:
   int m_level;
   bool m_print;

   void Log(const string msg)
   {
      if(m_print)
         Print(msg);
   }

public:
   void Init(const int level, const bool print_to_journal)
   {
      m_level = level;
      m_print = print_to_journal;
   }

   void Error(const string msg)
   {
      if(m_level >= LOG_ERR)
         Log(msg);
   }

   void Info(const string msg)
   {
      if(m_level >= LOG_INFO)
         Log(msg);
   }

   void Debug(const string msg)
   {
      if(m_level >= LOG_DEBUG)
         Log(msg);
   }
};

#endif

#ifndef __EA_OCO_POSITION_MANAGER_MQH__
#define __EA_OCO_POSITION_MANAGER_MQH__

class CPositionManager
{
private:
   string m_symbol;
   long m_magic;

public:
   void Init(const string symbol, const long magic)
   {
      m_symbol = symbol;
      m_magic = magic;
   }

   bool IsMine(const int index) const
   {
      ulong ticket = PositionGetTicket(index);
      if(ticket == 0) return false;
      if(!PositionSelectByTicket(ticket)) return false;
      if(PositionGetString(POSITION_SYMBOL) != m_symbol) return false;
      if((long)PositionGetInteger(POSITION_MAGIC) != m_magic) return false;
      return true;
   }

   int Count() const
   {
      int total = PositionsTotal();
      int count = 0;
      for(int i=0; i<total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetString(POSITION_SYMBOL) == m_symbol &&
               (long)PositionGetInteger(POSITION_MAGIC) == m_magic)
            {
               count++;
            }
         }
      }
      return count;
   }
};

#endif

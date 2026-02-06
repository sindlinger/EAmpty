void CEAController::OnTradeTransaction(const MqlTradeTransaction &trans,
                                       const MqlTradeRequest &request,
                                       const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(trans.deal == 0) return;
   if(!HistoryDealSelect(trans.deal)) return;

   string symbol = (string)HistoryDealGetString(trans.deal, DEAL_SYMBOL);
   if(symbol != _Symbol) return;

   long magic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(magic != m_cfg.MagicNumber) return;

   long entry = (long)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry == DEAL_ENTRY_IN) return; // só saídas

   long reason = (long)HistoryDealGetInteger(trans.deal, DEAL_REASON);
   double price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
   double volume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   ulong position_id = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   string comment = (string)HistoryDealGetString(trans.deal, DEAL_COMMENT);

   m_log.Info(StringFormat("Deal exit pos=%I64u reason=%s profit=%.2f price=%.5f vol=%.2f comment=%s",
                           position_id,
                           DealReasonText(reason),
                           profit,
                           price,
                           volume,
                           comment));
}

string CEAController::DealReasonText(const long reason) const
{
   switch(reason)
   {
      case DEAL_REASON_SL: return "SL";
      case DEAL_REASON_TP: return "TP";
      case DEAL_REASON_SO: return "STOP_OUT";
      case DEAL_REASON_CLOSE_BY: return "CLOSE_BY";
      case DEAL_REASON_ROLLOVER: return "ROLLOVER";
      case DEAL_REASON_EXTERNAL_CLIENT: return "CLIENT";
      case DEAL_REASON_MOBILE: return "MOBILE";
      case DEAL_REASON_WEB: return "WEB";
      case DEAL_REASON_EXPERT: return "EXPERT";
      case DEAL_REASON_SPLIT: return "SPLIT";
      case DEAL_REASON_PROFIT: return "PROFIT";
      case DEAL_REASON_REST: return "REST";
      default: return "OTHER";
   }
}

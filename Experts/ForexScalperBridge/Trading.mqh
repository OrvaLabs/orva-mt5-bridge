// Trading boundary. No trade requests are sent in this initial bridge.
#ifndef __FOREX_SCALPER_BRIDGE_TRADING_MQH__
#define __FOREX_SCALPER_BRIDGE_TRADING_MQH__

#include "Execution.mqh"

class CTrading
  {
private:
   bool m_initialized;

public:
   CTrading()
     {
      m_initialized = false;
     }

   bool Initialize(CExecution &execution)
     {
      // The execution boundary is injected now and will be used by future
      // order implementations.
      m_initialized = true;
      return true;
     }

   bool Buy(const string symbol, const double volume)
     {
      PrintFormat("Buy placeholder called for %s volume=%s", symbol, DoubleToString(volume, 2));
      return false;
     }

   bool Sell(const string symbol, const double volume)
     {
      PrintFormat("Sell placeholder called for %s volume=%s", symbol, DoubleToString(volume, 2));
      return false;
     }

   bool ClosePosition(const ulong position_ticket)
     {
      PrintFormat("Close position placeholder called for ticket=%I64u", position_ticket);
      return false;
     }

   bool CancelOrder(const ulong order_ticket)
     {
      PrintFormat("Cancel order placeholder called for ticket=%I64u", order_ticket);
      return false;
     }

   void Release()
     {
      m_initialized = false;
     }
  };
  
#endif

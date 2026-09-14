#ifndef __FOREX_SCALPER_BRIDGE_MARKET_DATA_MQH__
#define __FOREX_SCALPER_BRIDGE_MARKET_DATA_MQH__

class CMarketData
  {
private:
   string m_symbol;
   MqlTick m_tick;
   bool m_initialized;

public:
   CMarketData()
     {
      m_symbol = "";
      ZeroMemory(m_tick);
      m_initialized = false;
     }

   bool Initialize(const string symbol)
     {
      m_symbol = symbol;
      m_initialized = (m_symbol != "");
      return m_initialized;
     }

   bool Refresh()
     {
      if(!m_initialized)
         return false;
      return SymbolInfoTick(m_symbol, m_tick);
     }

   double GetBid() const { return m_tick.bid; }
   double GetAsk() const { return m_tick.ask; }
   double GetMid() const { return (m_tick.bid + m_tick.ask) / 2.0; }
   double GetSpread() const { return m_tick.ask - m_tick.bid; }
   datetime GetTimestamp() const { return m_tick.time; }
   MqlTick GetTick() const { return m_tick; }

   // Serialization is kept local so a future transport can reuse this interface.
   bool SerializeCurrentTick(string &payload) const
     {
      if(!m_initialized || m_tick.time == 0)
         return false;
      payload = StringFormat("{\"symbol\":\"%s\",\"bid\":%.10f,\"ask\":%.10f,\"time\":%I64d}",
                             m_symbol, m_tick.bid, m_tick.ask, m_tick.time);
      return true;
     }

   void Release()
     {
      m_symbol = "";
      ZeroMemory(m_tick);
      m_initialized = false;
     }
  };

#endif

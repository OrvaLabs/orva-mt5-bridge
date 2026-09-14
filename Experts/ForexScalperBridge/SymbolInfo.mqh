// Broker and symbol contract specifications.
#ifndef __FOREX_SCALPER_BRIDGE_SYMBOL_INFO_MQH__
#define __FOREX_SCALPER_BRIDGE_SYMBOL_INFO_MQH__

class CSymbolInfo
  {
private:
   string m_symbol;
   bool m_initialized;

public:
   CSymbolInfo()
     {
      m_symbol = "";
      m_initialized = false;
     }

   bool Initialize(const string symbol)
     {
      m_symbol = symbol;
      m_initialized = (m_symbol != "");
      return m_initialized;
     }

   int GetDigits() const { return (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS); }
   double GetPoint() const { return SymbolInfoDouble(m_symbol, SYMBOL_POINT); }
   double GetContractSize() const { return SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE); }
   double GetTickSize() const { return SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE); }
   double GetTickValue() const { return SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE); }
   double GetMinimumVolume() const { return SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN); }
   double GetMaximumVolume() const { return SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX); }
   double GetVolumeStep() const { return SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP); }
   long GetStopLevel() const { return SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL); }
   long GetFreezeLevel() const { return SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL); }

   void Release()
     {
      m_symbol = "";
      m_initialized = false;
     }
  };

#endif

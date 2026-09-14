// Account information read from the connected MT5 account.
#ifndef __FOREX_SCALPER_BRIDGE_ACCOUNT_MQH__
#define __FOREX_SCALPER_BRIDGE_ACCOUNT_MQH__

class CAccount
  {
private:
   bool m_initialized;

public:
   CAccount() { m_initialized = false; }

   bool Initialize()
     {
      m_initialized = true;
      return true;
     }

   double GetBalance() const { return AccountInfoDouble(ACCOUNT_BALANCE); }
   double GetEquity() const { return AccountInfoDouble(ACCOUNT_EQUITY); }
   double GetFreeMargin() const { return AccountInfoDouble(ACCOUNT_MARGIN_FREE); }
   double GetMarginLevel() const { return AccountInfoDouble(ACCOUNT_MARGIN_LEVEL); }
   string GetCurrency() const { return AccountInfoString(ACCOUNT_CURRENCY); }

   void Release() { m_initialized = false; }
  };

#endif

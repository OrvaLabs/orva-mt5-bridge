# ForexScalperBridge

`ForexScalperBridge` is the MT5/MQL5 adapter for the Forex Scalper system. It
reads broker-native data and sends newline-delimited JSON over one persistent
TCP connection to the NestJS market-data gateway. It is not the trading
strategy and does not execute orders.

## Files

- `ForexScalperBridge.mq5` - Expert Advisor entry point. It initializes the
  modules, refreshes market data on each tick, and releases resources on
  shutdown.
- `Config.mqh` - Centralized symbol, logging, and future backend settings.
- `MarketData.mqh` - Reads bid, ask, mid, spread, and timestamps from MT5 and
  exposes a placeholder tick serialization interface.
- `Trading.mqh` - Future buy, sell, close-position, and cancel-order boundary.
  All methods are placeholders and do not trade.
- `Account.mqh` - Reads account balance, equity, free margin, margin level, and
  currency.
- `SymbolInfo.mqh` - Reads broker and symbol contract specifications.
- `Execution.mqh` - Defines the future execution report and order-status model.
- `DataQuality.mqh` - Tracks tick age, duplicates, gaps, reconnections, and
  basic feed health.
- `TcpTransport.mqh` - Maintains the raw TCP connection for supported Windows
  MT5 environments.
- `HttpTransport.mqh` - Sends JSON with `WebRequest()` for MT5 on macOS.

## Architecture

The EA is the composition root. Its dependencies are intentionally one-way:

```text
ForexScalperBridge.mq5
        |
  +-----+----------+-----------+
  |     |          |           |
  v     v          v           v
MarketData Account SymbolInfo DataQuality
        |
        v
    Execution
        |
        v
     Trading
```

The EA sends the attached chart's symbol/timeframe through one selected
transport. Use HTTP on macOS and TCP on supported Windows MT5 environments.
Attach one instance per symbol/timeframe while developing.

## Build and run

1. Open MetaTrader 5 and choose **File -> Open Data Folder**.
2. Copy this directory into `MQL5/Experts/`, preserving the
   `ForexScalperBridge` folder.
3. Open `ForexScalperBridge.mq5` in MetaEditor.
4. Compile with **F7**. MetaEditor and the MQL5 compiler produce the `.ex5`
   artifact; this source tree does not include a manually-created binary.
5. In MT5 Navigator, refresh **Expert Advisors** and attach
   `ForexScalperBridge` to the desired chart.
6. Review lifecycle and optional tick logs in the Experts/Journal tabs.

Set the EA inputs to match the NestJS `.env` values:

- `InpBackendHost`: `127.0.0.1`
- `InpBackendPort`: `8080` when `InpTransport` is `TCP`
- `InpHttpPort`: `3000` when `InpTransport` is `HTTP`
- `InpBackendToken`: same value as `MT5_TCP_AUTH_TOKEN`
- `InpHeartbeatIntervalSeconds`: normally `10`
- `InpSnapshotIntervalSeconds`: account, symbol-info, and open-position update interval, normally `30`
- `InpTransport`: use `HTTP` for MT5 on macOS, or `TCP` for supported Windows MT5 environments.

MT5 may require enabling the destination in its permitted socket address list.

The Experts log should show `TCP connected` and `AUTH sent` immediately when
the EA initializes. If it does not, inspect the printed `SocketConnect` error
code; the NestJS console will not receive a connection until that succeeds.

The EA sends `AUTH`, `TICK`, `CANDLE`, `SYMBOL_INFO`, `ACCOUNT_INFO`,
`POSITION`, and `HEARTBEAT` messages. It does not send passwords, broker
credentials, or execute orders. ORDER and DEAL publishing can be added later
through `OnTradeTransaction` when execution is implemented.

For HTTP mode, use the NestJS HTTP port (normally `3000`) and allow
`http://127.0.0.1:3000` in MT5 WebRequest settings. TCP mode continues to use
the separate raw gateway on port `8080`.

VS Code is suitable for editing and reviewing the source files. MetaEditor is
the authoritative MQL5 editor/compiler and should be used to compile and run
the EA.

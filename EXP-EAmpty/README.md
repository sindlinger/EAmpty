# EA_Oco (MQL5)

EA modular com sinal BTick (buffers de estado) + trailing ATR desde o início.

## Project Map
- `EA_Oco.mq5` -> `EAController.mqh`
- `EAController.mqh` -> `Logger.mqh`, `Risk.mqh`, `Broker.mqh`, `PositionManager.mqh`, `BTickState.mqh`

## Como compilar
1. Coloque os arquivos nas pastas indicadas:
   - `MQL5/Experts/EA-Oco/EA_Oco.mq5`
   - `MQL5/Experts/EA-Oco/include/**`
2. Compile `EA_Oco.mq5` no MetaEditor.

## Inputs
- `StrategyPreset`: presets de estratégia (combo).
- `EntryOffsetPoints`: offset em pontos para ordens stop.
- `AllowTrading`: habilita envio de ordens.
- `MagicNumber`: magic do EA.
- `LotSize`: lote base.
- `MaxSpreadPips`: limite de spread (pips). <=0 desativa.
- `DeviationPoints`: slippage em pontos.
- `NumOrders`: número de ordens por sinal (default 2).
- `UseTrailingATR`: liga trailing ATR.
- `TPPoints`: TP provisório em pontos (default 10).
- `SLPoints`: SL provisório em pontos (default 5).
- `LogLevel`: 0=ERR,1=INFO,2=DEBUG.
- `PrintToJournal`: liga/desliga Print().

## Comportamento
- Entra **na barra 0** (candle atual) lendo buffers de estado:
  - Buffer 2: `State Buy = +1`
  - Buffer 3: `State Sell = -1`
- Abre **2 ordens** por sinal.
- Não guarda sinal: se não entrar na barra 1, expira.
- SL inicia pelo **trailing do indicador** (se disponível) e é atualizado a cada tick.
- Suporta múltiplas posições (hedge), inclusive na mesma direção.

### Presets
- `PRESET_STOP_TP4_SL2`: usa **ordem stop**, `TP=4 pontos`, `SL=2 pontos`.

## Indicadores
- O EA roda os indicadores **sem parâmetros** (iCustom somente com nome e timeframe atual).
- BTick: `IND-Btick\\BTick_v2.0.5_FFT`
- ATR trailing: `ATR_Trailing_Stop_1_Buffer`

# Hexesoft Inim → Home Assistant Bridge

Bridge .NET 9 che collega centrali antifurto **Inim Prime** (via protocollo PRIMELAN reversato, TCP porta 6004) a **Home Assistant** tramite MQTT auto-discovery.

## Architettura

Doppia connessione TCP alla centrale, un solo processo:

- **TCP MAIN** (`_protocol`): comandi arm/disarm/scenari/uscite ricevuti da MQTT, poll metadata (aree, uscite, log eventi ogni ~5s).
- **TCP ZONE** (`_zoneProtocol`): busy-poll dedicato dei terminali (~300ms), non contende con MAIN. Se la centrale rifiuta la seconda TCP il zone loop fa fallback su MAIN con lock esterno.

## Cosa espone in HA

| Componente HA | Origine dati | Cosa fa |
|---|---|---|
| `binary_sensor` per **zona** | Busy-poll cmd 7 `GET_TERMINAL_STATUS` su TCP ZONE dedicata | Sensori di movimento / contatti in tempo reale |
| `alarm_control_panel` per **area** | Poll AppHome + cmd 3 `ARM_PARTITION` | Stato + arm/disarm Totale (Away) / Parziale (Home) |
| `switch` bistabile per **coppia scenario** (On + Off automatico) | Discovery EEPROM + cmd 12 `ARM_SCENARIO` + cmd 5 `GET_SCENARIO modo=0` per stato | Attivazione bidirezionale scenari; stato sempre sincronizzato con la centrale |
| `switch` per **uscita/sirena** | Discovery EEPROM + cmd 8 `ATTIVA_USCITE` | ON/OFF relè, sirene, attuatori |
| `sensor` "Ultimo Evento" | cmd 18 + read EEPROM + cmd 31 filter_logger + resolver | Storico eventi decodificati (evento, area, agente, locazione, categoria) |
| ~20 sensori diagnostici (batteria, rete, GSM, tamper, tensioni, correnti) | cmd 64 `DATI_APP` (bundle) | Salute centrale |
| Button globali Stop Sirene / Reset Memoria / Rimuovi Tutto | cmd 57, 16 + cleanup MQTT | Azioni panel-wide |

## Struttura codice

```
Bridge/BridgeService.cs      → orchestrator (discovery + due poll loop paralleli + handler MQTT)
Inim/InimProtocol.cs         → framing PRIMELAN + AES + CRC + tutti i comandi
Inim/EventDecoder.cs         → risolve indici (codice/scenario/area) in nomi umani per log eventi
Inim/*Info, *Status, *Data   → modelli dati
Mqtt/BrokerClient.cs         → wrapper MQTTnet con dispatcher unico
Mqtt/HaPublisher.cs          → discovery + publish + subscribe HA
Configuration/AppSettings.cs → caricamento JSON (HA options.json → fallback appsettings.json)
Program.cs                   → entry point + DI + logging
```

## Configurazione

`appsettings.json` per sviluppo locale, `/data/options.json` in add-on Home Assistant. Il campo `contactpollinterval` (secondi) controlla la cadenza del poll metadata; le zone girano indipendentemente sulla TCP dedicata.

## Build & run

```bash
dotnet build
dotnet run
```

In DEBUG (Visual Studio) genera `log-inim-YYYYMMDD-HHmmss.txt` nel bin. In release solo console.

## Come è fatto il protocollo

Frame outer PRIMELAN (12 B header): `[SP][riservato][size][expected]`.
Frame interno standard (10 B): `[PP][CRC16][op][size][riservato]` + payload cifrato AES-128-CBC (chiave = password padded, IV = `i XOR key[i]`).

- Operazione `0x0000` = PROT_READ (lettura EEPROM diretta)
- Operazione `0x0001` = PROT_COMMAND (esecuzione comando API, prima uint32 = codice comando)
- PIN packato: ogni cifra ASCII → valore numerico (`'5'` → `0x05`), padding `0xFF`

Comandi principali usati:
- 3 `ARM_PARTITION` — inserimento/disinserimento aree
- 5 `GET_SCENARIO` — bitmap scenari (modo=0 attivi, modo=1 usabili)
- 6 `GET_AREE` — stato aree (non più usato direttamente, in AppHome)
- 7 `GET_TERMINAL_STATUS` — stato real-time zone (batch di 20)
- 8 `ATTIVA_USCITE` — accende/spegne uscite
- 12 `ARM_SCENARIO` — esegue uno scenario (indice 0-based)
- 16 `RESET_MEMORY` — reset memoria allarmi
- 18 `LEGGI_LOGGER` — puntatori buffer eventi
- 23 `INFO_CENTRALE` — modello/firmware/serial
- 31 `GET_LOGGER_RULES` — indirizzi filter_logger + max_ev_values
- 57 `STOP_ACTIONS` — silenzia sirene / stop telefonate
- 64 `DATI_APP` — bundle home (aree + status + uscite bitmap)

Per dettagli tecnici sui singoli comandi guardare `Inim/InimProtocol.cs` — le costanti in cima e i commenti nei metodi documentano offset, size e semantica di ogni struttura wire.

## Licenza

Uso interno Hexesoft.

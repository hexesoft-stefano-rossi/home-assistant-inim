# Hexesoft Inim → Home Assistant Bridge

Bridge .NET 9 che collega centrali antifurto **Inim Prime** (via protocollo PRIMELAN reversato, TCP porta 6004) a **Home Assistant** tramite MQTT.

Non usa l'SDK ufficiale `PrimeSDK 2.7` (troppo lento nel polling): il protocollo è stato ricostruito via reverse engineering del software `InimPrimeCore.dll` / `Centrale6.dll`.

## Cosa espone in HA

| Componente HA | Da dove viene | Cosa fa |
|---|---|---|
| `binary_sensor` per **zona** | Poll comando 7 `GET_TERMINAL_STATUS` (batch 20) | Sensori di movimento / contatti |
| `alarm_control_panel` per **area** | Poll comando 6 `GET_AREE` + comando 3 `ARM_PARTITION` | Stato + arm/disarm Away/Home/Night |
| `button` per **scenario** | Discovery EEPROM + comando 5 filtro + comando 59 `ARM_SCENARIO` | Esecuzione scenari configurati |
| `switch` per **uscita/sirena** | Discovery EEPROM + comando 8 `ATTIVA_USCITE` | ON/OFF relè, sirene, attuatori |
| **Button globali**: Stop Sirene, Reset Memoria, Rimuovi Tutto | Comandi 57, 16 + cleanup MQTT | Azioni panel-wide |
| ~20 **sensori diagnostici** (batteria, rete, GSM, tamper, tensioni, correnti) | Poll comando 13 `GET_STATUS` | Salute centrale sotto device Bridge |
| **PanelInfo device**: model / firmware / serial | Comando 23 `INFO_CENTRALE` (una volta all'avvio) | Metadati device HA |

## Struttura

```
Bridge/BridgeService.cs      → orchestrator (discovery + poll loop + handler MQTT)
Inim/InimProtocol.cs         → framing PRIMELAN + AES + CRC + tutti i comandi
Inim/Zone*, Area*, Panel*, Output*, Scenario*  → modelli dati
Mqtt/BrokerClient.cs         → MQTTnet wrapper
Mqtt/HaPublisher.cs          → discovery + publish + subscribe per HA
Configuration/AppSettings.cs → caricamento JSON con override locale
LogFormatter.cs              → console colorata + file logger
```

## Configurazione

Le credenziali reali vanno in `appsettings.local.json` (gitignored). `appsettings.json` contiene placeholder.

```json
// appsettings.local.json (NON committare)
{
  "inim": { "password": "yourpass", "pin": "123456" },
  "mqtt": { "username": "user", "password": "pass" }
}
```

`contactpollinterval` in appsettings controlla la cadenza minima del ciclo di polling:
- `0` = busy polling (~650ms/ciclo, massima reattività)
- `N` = attende almeno N secondi tra un ciclo e l'altro

## Prerequisiti

- Centrale Inim Prime PR500 (fw 3.x / 4.x). Altri modelli (PR060/120/240, SOL30) supportati con costanti diverse (`MAX_NUM_PARTIZIONI`, ecc.).
- Broker MQTT raggiungibile dalla rete del bridge.
- Home Assistant con integrazione MQTT abilitata (auto-discovery su `homeassistant/#`).
- PIN utente reale della centrale con permessi su tutte le aree/scenari che vuoi controllare.

## Build & run

```bash
dotnet build
dotnet run
```

In DEBUG (Visual Studio) genera anche `log-inim-YYYYMMDD-HHmmss.txt` nel bin. In release (Home Assistant add-on) solo console.

## Come è fatto il protocollo

Frame outer PRIMELAN (12 B header): `[SP][riservato][size][expected]`.
Frame interno standard (10 B): `[PP][CRC16][op][size][riservato]` + payload cifrato AES-128-CBC (chiave=password padded, IV=`i XOR key[i]`).

- Operazione `0x0000` = PROT_READ (lettura EEPROM diretta).
- Operazione `0x0001` = PROT_COMMAND (esecuzione comando API, prima uint32 = codice comando 1..90).
- PIN packato: ogni cifra ASCII → valore numerico (`'5'` → `0x05`), padding `0xFF`.

Per dettagli tecnici sui singoli comandi guardare `Inim/InimProtocol.cs` — le costanti in cima e i commenti nei metodi documentano offset, size e semantica di ogni struttura wire.

## Licenza

Uso interno Hexesoft.

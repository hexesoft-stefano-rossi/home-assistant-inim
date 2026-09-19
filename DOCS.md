# Hexesoft Inim Bridge

Add-on Home Assistant che collega una centrale antifurto **Inim Prime** (serie PR060 / PR120 / PR240 / PR500, firmware 3.x / 4.x) al tuo Home Assistant tramite MQTT auto-discovery. Nessuna configurazione manuale delle entità: aree, zone, scenari, uscite e diagnostica vengono create automaticamente all'avvio leggendo la programmazione dalla centrale.

## Cosa fa

Legge in tempo reale lo stato dell'impianto direttamente dalla centrale via LAN (protocollo PRIMELAN su porta 6004, cifrato AES-128-CBC) e lo pubblica su MQTT nel formato di discovery di Home Assistant. In un'unica installazione ottieni:

| In Home Assistant vedi | Come | Cosa puoi fare |
|---|---|---|
| Un `binary_sensor` per **ogni zona** attiva | Poll continuo su TCP dedicato (~300 ms) | Vedere sensori di movimento, contatti, tamper in tempo reale |
| Un `alarm_control_panel` per **ogni area** | Poll periodico + comandi arm/disarm | Inserire/disinserire in Totale, Parziale (solo dove supportato), Disattivato |
| Uno `switch` bistabile per **ogni coppia On/Off** di scenari | ARM_SCENARIO + GET_SCENARIO per sync | Attivare i macro-scenari programmati in centrale; lo switch si sincronizza da solo se cambi stato da tastiera/app |
| Un `button` per ogni scenario **non appaiato** | ARM_SCENARIO one-shot | Attivare scenari singoli |
| Uno `switch` per **ogni uscita** (relè onboard e su bus) | ATTIVA_USCITE | Accendere/spegnere singole uscite |
| Un `sensor` "Ultimo Evento" con storico ultimi 20 eventi | Poll log EEPROM + decodifica con risoluzione nomi | Vedere chi/quando/da dove è stata fatta un'azione (es. "Inserimento area X da codice utente Y su tastiera Z") |
| 23 sensori di diagnostica sotto il device Bridge | Poll `DATI_APP` | Tensione rete/batteria/bus, correnti, guasti alimentatore/GSM/telefono, tamper, jamming radio, sabotaggi wireless |
| 2 sensori "Poll Cycle Time" / "Poll Metadata Time" | Timing dei due loop | Diagnosticare la reattività del bridge |
| Button **Stop Sirene**, **Reset Memoria Allarmi**, **Rimuovi Tutto** | Comandi API + cleanup MQTT | Azioni panel-wide senza tastiera |

Il device MQTT principale mostra anche modello, firmware e serial della centrale letti automaticamente via `INFO_CENTRALE`.

## Perché

Il bridge usa una **connessione TCP dedicata al polling zone** (architettura dual-TCP), che porta la reazione dei sensori sotto il secondo — livello utilizzabile anche per automazioni real-time (es. accendere una luce quando si apre una porta). I comandi verso la centrale girano su una seconda connessione, serializzata, per non contendere con il poll.

Il bridge non richiede né modifiche alla configurazione centrale né SIA-IP / Nexus. Basta che la centrale sia raggiungibile in LAN sulla porta 6004.

## Installazione

Standard Home Assistant add-on:

1. Aggiungi il repository nell'add-on store
2. Cerca "Hexesoft Inim" e installalo
3. Configura le opzioni (vedi sotto)
4. Avvia l'add-on

Le entità appariranno automaticamente nell'integrazione MQTT dopo qualche secondo dall'avvio.

## Configurazione

```yaml
inim:
  host: "192.168.1.50"        # IP della centrale
  port: 6004                   # Porta PRIMELAN (default 6004)
  password: "yoursmartlanpwd"  # Password SmartLAN configurata in centrale
  pin: "123456"                # PIN utente con permessi su aree/scenari desiderati
  connectiontype: 2            # 0=seriale, 1=TCP grezzo, 2=PRIMELAN (lasciare 2)
  contactpollinterval: 5       # Secondi tra un poll metadata e il successivo (0=continuo)

mqtt:
  host: "core-mosquitto"       # Broker MQTT (l'add-on Mosquitto di HA)
  port: 1883
  username: "user"             # Utente MQTT (vuoto = anonimo)
  password: "pass"             # Password MQTT
  basetopic: "inim_bridge"     # Prefisso dei topic MQTT
  discoveryprefix: "homeassistant"  # Prefisso discovery HA (default)

systemsettings:
  loglevel: "info"             # debug | info | warning | error
```

### Note sui parametri

- **`inim.password`**: password della SmartLAN configurata in centrale (menu installatore → Configurazione → Rete → Password SmartLAN). Non è il codice utente. Usata come chiave AES-128-CBC del canale PRIMELAN.
- **`inim.pin`**: PIN utente reale della centrale. Deve avere permessi sulle aree e scenari che vuoi controllare da HA — le entità pubblicate rispecchieranno esattamente ciò che quell'utente può fare in centrale. Consiglio: crea un PIN dedicato "Home Assistant" così tutti gli eventi generati dal bridge sono identificabili nel log della centrale.
- **`inim.contactpollinterval`**: ogni quanti secondi il bridge rilegge aree, uscite, stato pannello e log eventi. Le zone (sensori) girano sempre in continuo su una connessione TCP dedicata, quindi restano reattive indipendentemente da questo valore.
- **`systemsettings.loglevel`**: usa `info` in produzione. `debug` triplica il volume di log (utile solo per diagnosi).

Il file `/data/options.json` di HA ha precedenza; in sviluppo standalone viene caricato `appsettings.json`.

## Entità pubblicate

### Zone (`binary_sensor`)

Ogni zona configurata (rilevata leggendo la tabella terminali) viene esposta come **device HA separato** con `device_class="motion"`, collegato al device Bridge via `via_device`.

- **State topic**: `{basetopic}/zone/{id}/state` — `ON` / `OFF`
- **Attributes topic**: `{basetopic}/zone/{id}/attributes` — JSON con:
  - `zone1_raw`, `zone2_raw` — lettura grezza dei due canali (per zone doppie)
  - `zone1_enabled`, `zone2_enabled` — flag di abilitazione
  - `zone1_excluded`, `zone2_excluded` — se la zona è stata esclusa
  - `mem_alarm`, `mem_tamper` — memorie allarme/sabotaggio
  - `terminal`, `slot` — riferimento fisico centrale

Sono supportati sia i terminali `InputOnly` sia `InputAndOutput` sia `DoubleZone` (2 zone logiche per terminale).

### Aree (`alarm_control_panel`)

Ogni area (partizione) configurata in centrale diventa un `alarm_control_panel` in un proprio device HA.

- **State topic**: `{basetopic}/area/{id}/state` — `disarmed` | `armed_away` | `armed_home` | `triggered`
- **Command topic**: `{basetopic}/area/{id}/set` — `DISARM` | `ARM_AWAY` | `ARM_HOME` | `ARM_NIGHT`
- **Attributes topic**: `{basetopic}/area/{id}/attributes` — `arm_mode`, `rt_state`, `mem_alarm`, `mem_sabotage`, `mem_short`, `mem_fault`, `valid_partition`
- `code_arm_required` / `code_disarm_required` = `false` — il PIN è gestito lato bridge

**Rilevamento automatico Parziale (STAY)**: all'avvio il bridge legge la tabella EEPROM `exf_prg_scenari` (indice 76) e, per ogni area, verifica se almeno uno scenario configurato la inserisce in modalità STAY (Parziale). Le aree che nessuno scenario mette mai in Parziale espongono in HA solo `arm_away`; le altre hanno anche `arm_home`. Nessuna euristica sul nome, nessuna configurazione manuale — è letto direttamente dalla programmazione della centrale.

Se il tuo dashboard Tile-Card usa `features → alarm-modes → modes:` con lista esplicita, va allineato alla programmazione (togliendo `armed_home` per le aree che non lo supportano).

### Scenari

Il bridge legge le descrizioni dei 50 slot scenari e li tratta in due modi:

- **Coppie On/Off** (`switch` bistabile): scenari il cui nome inizia con "On " e "Off " seguiti dallo stesso testo (case-insensitive, es. "On XYZ" + "Off XYZ") vengono accoppiati automaticamente in una singola entità `switch` chiamata come la parte comune (es. "XYZ") sotto il device Bridge. Icona `mdi:home-lock`. Lo stato viene sincronizzato leggendo `GET_SCENARIO modo=0` (bitmap scenari attivi).
- **Scenari singoli** (`button`): scenari senza controparte On/Off restano `button` one-shot.

**Cooldown per-pair**: quando premi uno switch scenario da HA, per i successivi 8 secondi il bridge ignora il sync ciclico per quella coppia (evita il flicker dovuto a `GET_SCENARIO` che restituisce lo stato "vecchio" durante la stabilizzazione delle aree).

### Uscite (`switch`)

Ogni terminale di tipo output (Relè onboard, Uscita1, Uscita2, `+Aux1`, `+Aux2`, oltre a tutte le uscite bus del tipo `OutputOnly` / `InputAndOutput` / `OutputDimming` / `OutputDac` / `OutputAnalog`) viene esposto come `switch` con proprio device HA.

- **State topic**: `{basetopic}/output/{id}/state` — `ON` / `OFF`
- **Command topic**: `{basetopic}/output/{id}/set`
- **Icone**: `mdi:flash` / `mdi:electric-switch`
- Lo stato viene aggiornato dal poll metadata leggendo la bitmap `uscite_attive` restituita da `DATI_APP`.

### Diagnostica centrale (`sensor` / `binary_sensor` sotto il device Bridge, `entity_category=diagnostic`)

Publicati sotto un unico device "Bridge":

**Alimentazione**
- `mains_voltage` (V), `battery_voltage` (V), `bus_voltage` (V), `bus_current` (A) — sensori numerici
- `low_battery`, `mains_failure`, `power_supply_fault` — binary
- `wls_low_battery` — batteria wireless bassa

**Comunicazioni**
- `internet_connected`, `internet_disconnected` — stato connettività
- `phone_line_failure`, `gsm_failure` — guasti linea telefonica / GSM

**Sabotaggi / Guasti**
- `panel_tamper_missing`, `panel_tamper_dislodged`, `panel_tamper_opened` — tamper centrale
- `wls_missing` — periferica wireless scomparsa
- `radio_jamming`, `radio_keypad_issue` — jamming radio / problemi tastiere radio
- `zone_fault`, `siren_fault` — guasti zone / sirene
- `dusty_sensor` — sensore sporco
- `panel_in_programming`, `service_jumper` — stati di servizio

### Ultimo Evento (`sensor`)

Sensore `sensor.hexesoft_inim_bridge_ultimo_evento` con:
- **state**: riga sintetica dell'ultimo evento (`HH:mm:ss - descrizione - maschera - agente`, troncata a 250 char)
- **attributi**: `last_event_time`, `description`, `category`, `mask`, `agent`, `location`, `activation`, `type_id`, e un array `history` con gli ultimi 20 eventi decodificati.

Ogni voce di `history` ha `{time, evento, categoria, maschera, agente, locazione, attivazione, type_id}`. Utilizzabile in un `markdown` card per lo storico.

**Decodifica evento**: il bridge legge le regole (`GET_LOGGER_RULES` + PROT_READ della tabella `filter_logger`) e mappa il numero evento grezzo → tipo evento (0..113). Poi risolve gli indici presenti nel record (codice utente, chiave, tastiera, inseritore, area, zona, scenario) leggendo le rispettive tabelle EEPROM di descrizioni, quindi genera stringhe umane come *"Inserimento area &lt;nome area&gt; da codice &lt;nome utente&gt; su tastiera &lt;nome tastiera&gt;"*.

### Button globali (sotto device Bridge)

- **Stop Sirene** (`button`, `mdi:volume-off`) — invia `STOP_ACTIONS(StopAlarms)` (comando 57) su tutte le aree
- **Reset Memoria Allarmi** (`button`, `mdi:bell-off`) — invia `RESET_MEMORY` (comando 16, mask=0xFFFFFFFF) su tutte le aree; poi rilegge lo stato
- **Rimuovi Tutto** (`button`, `mdi:delete-alert`, `entity_category=config`) — pulisce dal broker MQTT tutte le entità pubblicate da questo bridge (zone 1..300, aree 1..50, uscite 1..300, scenari 1..60, sensori diagnostica e singleton bridge). Utile prima di rinominare o dopo una migrazione.

## Architettura e comandi

### Dual-TCP

Il bridge apre **due connessioni TCP separate** alla centrale, entrambe cifrate AES-128-CBC:

- **MAIN** (`_protocol`): eseguono tutti i comandi (arm/disarm, scenari, uscite, reset, letture EEPROM, poll metadata). Serializzata via `_protocolLock` in modo che nessun comando si sovrapponga.
- **ZONE** (`_zoneProtocol`): dedicata al busy-poll continuo delle zone via `GET_TERMINAL_STATUS` (comando 7), batch da 20 zone per giro. Non contende con la MAIN, quindi la reattività dei sensori resta ~300 ms indipendentemente da altri comandi in corso.

Se la connessione ZONE cade (o non riesce ad aprirsi), il bridge fa fallback sul poll delle zone sulla MAIN. Su errore fatale della MAIN il bridge chiama `FullReconnectAsync` (chiusura entrambe + rilettura di tutta la discovery).

### Loop di polling

- **PollZonesLoopAsync** — ciclo continuo, no delay. Reconnect preemptivo su `IsConnected==false`. Sull'errore: delay 2s + retry.
- **PollMetadataLoopAsync** — cadenza `contactpollinterval` secondi. Per ciclo:
  1. `DATI_APP` (comando 64) — bundle da 773 B: 30 aree + PanelStatus 54 B + bitmap 127 B uscite attive
  2. aggiorna aree, diagnostica, uscite
  3. sincronizza switch scenario (`GET_SCENARIO modo=0`), rispettando i cooldown
  4. `READ_LOGGER` (comando 18) — legge gli ultimi 20 slot dal ring buffer eventi
  5. decodifica e pubblica lo storico

### Comandi API centrale usati

| Cmd | Nome | Uso |
|---|---|---|
| 3 | `ARM_PARTITION` | Arm/disarm di singola area |
| 5 | `GET_SCENARIO` | Bitmap scenari `activable` (all'avvio) e `attivi` (poll) |
| 6 | `GET_AREE` | Stato runtime aree (fallback) |
| 7 | `GET_TERMINAL_STATUS` | Poll zone continuo (batch 20) |
| 8 | `ATTIVA_USCITE` | Comando switch uscita |
| 12 | `ARM_SCENARIO` | Esecuzione scenario |
| 16 | `RESET_MEMORY` | Reset memorie allarme (button Reset Memoria) |
| 18 | `READ_LOGGER` | Lettura ring buffer eventi (fino a 4000 slot per PR500) |
| 23 | `INFO_CENTRALE` | Modello / firmware / serial per il device MQTT |
| 31 | `GET_LOGGER_RULES` | Regole filter_logger per mapping event_number → EVT_TYPE |
| 57 | `STOP_ACTIONS` | Stop sirene (button Stop Sirene) |
| 64 | `DATI_APP` | Bundle aree + stato pannello + uscite (poll metadata) |

Sono usate anche letture EEPROM dirette (PROT_READ) per: tabella indirizzi, terminali (`exf_prg_terminals`), descrizioni zone/aree/scenari/codici/chiavi/tastiere/inseritori, uscite onboard (`out_rele`), programmazione scenari (`exf_prg_scenari`, per Parziale).

### Comandi da HA gestiti

| Sorgente HA | Handler | Comando centrale |
|---|---|---|
| `alarm_control_panel.set` (DISARM/ARM_AWAY/ARM_HOME/ARM_NIGHT) | `HandleAreaCommandAsync` | ARM_PARTITION (3) |
| `switch` scenario bistabile | `HandleScenarioPairCommandAsync` | ARM_SCENARIO (12) — poi cooldown 8s + republish |
| `button` scenario singolo | `HandleScenarioCommandAsync` | ARM_SCENARIO (12) |
| `switch` uscita | `HandleOutputCommandAsync` | ATTIVA_USCITE (8) |
| Button "Stop Sirene" | `HandleStopSirensAsync` | STOP_ACTIONS(StopAlarms) (57) |
| Button "Reset Memoria" | `HandleResetMemoryAsync` | RESET_MEMORY (16, mask=0xFFFFFFFF) |
| Button "Rimuovi Tutto" | `RemoveAllDiscoveryAsync` | Nessuno — cleanup MQTT |

Dopo un ARM/DISARM/scenario che completa con `Done`, il bridge repubblica subito lo stato delle aree senza aspettare il poll successivo (feedback immediato in HA).

### Riconnessione automatica

- **MAIN**: preemptivo prima di ogni poll metadata + `FullReconnectAsync` (ripete tutta la discovery) su errore fatale.
- **ZONE**: preemptivo prima di ogni ciclo poll zone + retry dopo eccezione, con fallback finale sulla MAIN.
- **MQTT**: `BrokerClient` gestisce disconnect inaspettati con backoff esponenziale 2s → 60s (max 10 tentativi). Al reconnect ripubblica `Online` sul topic di availability e ri-sottoscrive tutti gli handler.
- **Last Will**: `{basetopic}/status` = `Offline` (retain). Tutte le entità pubblicate hanno `availability` che punta a quel topic, quindi HA le mostra come "non disponibili" se il bridge cade.

### Migrazione discovery precedenti

- Aree pubblicate in vecchie versioni come `binary_sensor`: il nuovo `PublishAreaDiscoveryAsync` pubblica prima un payload vuoto sul vecchio topic `binary_sensor/{uid}/config` per rimuoverle da HA.
- Scenari e uscite non più presenti nella programmazione: il bridge itera un range fisso di ID (fino a 50 per scenari, 200 per uscite) e pubblica payload vuoto sui topic non riconosciuti.
- Retained `PRESS` residui sui topic dei button vengono puliti pre-emptivamente prima di risottoscrivere.

## Logging

- **Console** — formatter `clean`: `[HH:mm:ss.fff] LIVELLO | Messaggio` con colori ANSI (rosso=Error, giallo=Warning, verde=Info, magenta=Debug). Prefissi convenzionali:
  - `CORE -> HEXE` = sistema/orchestrazione
  - `HEXE -> INIM` = comandi verso la centrale
  - `INIM -> HEXE` = risposte / lettura dalla centrale
  - `MQTT -> HEXE` = comandi ricevuti da HA
  - `HEXE -> MQTT` = publish verso HA
- **File** — solo in build debug: viene creato un file `log-inim-{yyyyMMdd-HHmmss}.txt` per ogni sessione, formato in chiaro senza ANSI, `AutoFlush=true`, `FileShare.ReadWrite` (leggibile mentre il bridge gira). Non attivo nel container add-on release.

Il livello di log applicato in `SystemSettings.LogLevel` viene forzato con `AddFilter(null, level)` per superare l'ereditarietà `appsettings.json`. Il logger `Microsoft.*` è silenziato a Warning per non annegare i log MQTT/TCP.

## Cosa NON fa (limiti attuali)

- Non gestisce termostati Inim (esistono in centrale ma sono fuori scope antifurto)
- Non gestisce chiavi/proxi come entità separate (i loro nomi sono usati per etichettare gli eventi nel log storico)
- Non permette il cambio codice utente da Home Assistant
- Se accedi al bridge tramite lo stesso PIN di un utente reale, tutte le azioni fatte da HA compaiono nel log della centrale come "da remoto" attribuite a quel PIN — usa un PIN dedicato se vuoi distinguere gli eventi

## Cosa serve nella centrale

Nulla di speciale — configurazione standard SmartLAN già presente su ogni PR500 collegata alla rete locale. Verifica solo che:

- La SmartLAN sia raggiungibile dal server Home Assistant (`ping <ip>` e connessione a `<ip>:6004`)
- Nella centrale la porta 6004 sia abilitata
- Il PIN che usi abbia permessi sulle aree/scenari che intendi controllare

## Panel supportati

Testato su **PR500 fw 4.07**. Il protocollo PRIMELAN è comune ai firmware 3.x/4.x, quindi dovrebbe funzionare anche su modelli minori (PR060 / PR120 / PR240) e sulla serie SOL. Se hai un firmware più vecchio (1.x / 2.x) alcuni comandi cambiano numerazione — in quel caso apri una segnalazione.

## Sicurezza e privacy

Il bridge parla **solo** con la centrale (LAN) e il broker MQTT (LAN). Nessuna telemetria, nessuna connessione a servizi cloud terzi, nessuna raccolta dati. Tutti i comandi verso la centrale sono cifrati AES-128-CBC come da specifica PRIMELAN (chiave = password SmartLAN paddata a 16 byte, IV[i] = i XOR K[i]).

## Supporto

Log completo dell'add-on visibile dalla scheda "Log" in Home Assistant. Per problemi apri una issue nel repository di questo add-on riportando la sezione di log con il comando che ha fallito.

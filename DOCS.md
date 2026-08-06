# Hexesoft Inim Bridge

Add-on Home Assistant che collega una centrale antifurto **Inim Prime** (serie PR060 / PR120 / PR240 / PR500, firmware 3.x / 4.x) al tuo Home Assistant tramite MQTT auto-discovery. Nessuna configurazione manuale delle entità: aree, zone, scenari, uscite e diagnostica vengono create automaticamente all'avvio leggendo la configurazione dalla centrale.

## Cosa fa

Legge in tempo reale lo stato dell'impianto direttamente dalla centrale via rete locale (protocollo PRIMELAN sulla porta 6004) e lo pubblica su MQTT nel formato di discovery di Home Assistant. In un'unica installazione ottieni:

| In Home Assistant vedi | Come | Cosa puoi fare |
|---|---|---|
| Un `binary_sensor` per **ogni zona** | Poll continuo del reale stato dei terminali | Vedere in tempo reale sensori di movimento, contatti, tamper (~300 ms di reazione) |
| Un `alarm_control_panel` per **ogni area** | Poll + comando arm/disarm | Inserire e disinserire in modalità Totale / Parziale / Disattivato, ricevere lo stato reale |
| Uno `switch` bistabile per **ogni scenario** configurato in centrale (coppia On/Off automatica) | Comando ARM_SCENARIO + lettura `GET_SCENARIO modo=0` per lo stato reale | Attivare/disattivare scenari macro (Tutto, Notte, ecc); lo switch si sincronizza da solo quando la centrale cambia stato via tastiera o app |
| Uno `switch` per **ogni uscita** (relè, sirene, attuatori onboard e su bus) | Comando ATTIVA_USCITE | Accendere/spegnere singole uscite |
| Un `sensor` "Ultimo Evento" con lo **storico ultimi eventi** | Poll del log EEPROM + decodifica via filter_logger + risoluzione nomi (codici / chiavi / tastiere) | Vedere chi/quando/da dove ha fatto un'azione (es. "Inserimento area Esterno 1 da codice Stefano su Tastiera 1 Ingresso") |
| Circa 20 sensori diagnostici sotto il device Bridge | Poll comando GET_STATUS | Tensione rete, batteria, bus, correnti, guasti alimentatore/GSM/telefono, tamper, jamming radio |
| **Button globali** Stop Sirene, Reset Memoria, Rimuovi Tutto | Comandi API centrale + cleanup MQTT | Azioni panel-wide senza tastiera |

Il device MQTT principale mostra anche modello, firmware e serial della centrale letti automaticamente via `INFO_CENTRALE`.

## Perché

L'app ufficiale Inim Cloud e il PrimeSDK originale sono lenti per un utilizzo tipico di domotica: il ciclo di refresh non scende sotto qualche secondo. Questo bridge riscritto usa una connessione TCP dedicata al polling zone (architettura dual-TCP), riportando la reazione dei sensori sotto il secondo — livello utilizzabile anche per automazioni real-time in Home Assistant (es. accendere una luce quando si apre una porta).

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
  connectiontype: 2            # 2 = PRIMELAN diretto (lasciare così)
  contactpollinterval: 5       # Sec tra un poll metadata e il successivo (aree/uscite/eventi)

mqtt:
  host: "core-mosquitto"       # Broker MQTT (l'add-on Mosquitto di HA)
  port: 1883
  username: "user"             # Utente MQTT (vuoto = anonimo)
  password: "pass"             # Password MQTT
  basetopic: "inim_bridge"     # Prefisso dei topic MQTT
  discoveryprefix: "homeassistant"  # Prefisso discovery HA (default)

systemsettings:
  loglevel: "info"             # info | debug | warning | error
```

### Note sui parametri

**`inim.password`** è la password della SmartLAN configurata nella centrale (menu installatore → Configurazione → Rete → Password SmartLAN). Non è il codice utente.

**`inim.pin`** è un PIN utente reale della centrale. Deve avere permessi sulle aree e scenari che vuoi controllare da Home Assistant. Se un utente ha permessi solo su Casa 1, dal bridge potrai armare/disarmare solo Casa 1.

**`contactpollinterval`** controlla ogni quanti secondi il bridge rilegge aree, uscite e log eventi. Le zone (sensori) girano sempre in continuo su una connessione TCP dedicata, quindi restano reattive indipendentemente da questo valore.

**`systemsettings.loglevel`**: usa `info` in produzione. `debug` triplica il volume di log (utile solo per diagnosi).

## Cosa NON fa (limiti attuali)

- Non gestisce termostati Inim (esistono in centrale ma sono al di fuori dello scope antifurto)
- Non gestisce chiavi/proxi come entità separate (i loro nomi sono usati per etichettare gli eventi nel log storico)
- Non permette il cambio codice utente da Home Assistant
- Se accedi al bridge tramite lo stesso PIN di un utente reale, tutte le azioni fatte da HA compaiono nel log della centrale come "da remoto" attribuite a quel PIN — usa un PIN dedicato se vuoi distinguere gli eventi

## Cosa serve nella centrale

Nulla di speciale — configurazione standard SmartLAN già presente su ogni PR500 collegata alla rete locale. Verifica solo che:

- La SmartLAN sia raggiungibile dal server Home Assistant (`ping <ip>` e `telnet <ip> 6004`)
- Nella centrale la porta 6004 sia abilitata
- Il PIN che usi abbia permessi sulle aree/scenari che intendi controllare

## Panel supportati

Testato su **PR500 fw 4.07**. Il protocollo PRIMELAN è comune ai firmware 3.x/4.x, quindi dovrebbe funzionare anche su modelli minori (PR060 / PR120 / PR240) e sulla serie SOL. Se hai un firmware più vecchio (1.x / 2.x) alcuni comandi cambiano numerazione — in quel caso apri una segnalazione.

## Sicurezza e privacy

Il bridge parla **solo** con la centrale (LAN) e il broker MQTT (LAN). Nessuna telemetria, nessuna connessione a servizi cloud terzi, nessuna raccolta dati. Tutti i comandi verso la centrale sono cifrati AES-128-CBC come da specifica PRIMELAN.

## Supporto

Log completo dell'add-on visibile dalla scheda "Log" in Home Assistant. Per problemi apri una issue nel repository di questo add-on riportando la sezione di log con il comando che ha fallito.

# Hexesoft Inim Bridge

Add-on per Home Assistant che collega una centrale antifurto **Inim Prime**
(PR060 / PR120 / PR240 / PR500) alla tua casa domotica tramite MQTT.
Non devi creare a mano nessuna entità: zone, aree, scenari, uscite e
diagnostica compaiono da sole nel tuo Home Assistant leggendo direttamente
la programmazione della centrale.

Chi usa l'antifurto da Home Assistant potrà:
- vedere in tempo reale quali zone (sensori di movimento, contatti porta,
  tamper) sono attive;
- inserire e disinserire singole aree digitando il proprio PIN;
- applicare o togliere gli scenari (es. "Notte", "Fuori casa", "Tutto")
  digitando il proprio PIN;
- fermare le sirene, cancellare le telefonate in uscita o cancellare la
  memoria allarmi — sempre digitando il proprio PIN;
- leggere nella plancia **Attività** di Home Assistant lo storico eventi
  della centrale con lo stesso dettaglio del software Inim (evento,
  maschera, agente, locazione, categoria);
- monitorare 23 stati di diagnostica della centrale (alimentazione,
  batterie, GSM, sabotaggi, guasti, jamming radio, ecc.).

---

## Indice

1. [Prerequisiti](#1-prerequisiti)
2. [Configurazione della centrale (**importante, da fare PRIMA**)](#2-configurazione-della-centrale)
3. [Installazione dell'add-on](#3-installazione-delladd-on)
4. [Configurazione dell'add-on](#4-configurazione-delladd-on)
5. [Cosa compare in Home Assistant](#5-cosa-compare-in-home-assistant)
6. [Come funziona il PIN (modello di sicurezza)](#6-come-funziona-il-pin)
7. [Esempio di dashboard](#7-esempio-di-dashboard)
8. [Cosa NON fa questo add-on](#8-cosa-non-fa-questo-add-on)
9. [Risoluzione problemi](#9-risoluzione-problemi)
10. [Note tecniche per curiosi](#10-note-tecniche-per-curiosi)

---

## 1. Prerequisiti

- Una centrale **Inim Prime** (PR060 / PR120 / PR240 / PR500), firmware
  3.x o 4.x, collegata alla LAN di casa tramite la sua **SmartLAN**.
- Home Assistant OS o Supervised (altre installazioni funzionano, ma
  l'installazione dell'add-on è più semplice in queste due).
- Il broker **MQTT** installato in Home Assistant. Il più comune è
  l'add-on ufficiale **Mosquitto broker**: se non ce l'hai, installalo
  prima di questo (Impostazioni → Add-on → aggiungi "Mosquitto broker").
- Il software **Prime/STUDIO** di Inim (il gestionale che usi per
  programmare la centrale). Ti serve per creare l'utente dedicato
  descritto al punto 2.
- Dalla rete di Home Assistant, la centrale deve rispondere sulla porta
  TCP **6004** (porta standard della SmartLAN Inim). Puoi verificarlo
  anche solo con un `ping` dell'indirizzo IP della centrale dal server
  di Home Assistant.

Avere a portata di mano prima di iniziare:
- indirizzo IP della centrale (es. `192.168.1.50`);
- password della **SmartLAN** (NON è un codice utente — è una password
  separata che l'installatore ha configurato nel menu Rete della centrale);
- i PIN degli utenti Inim di casa — quelli reali, che useranno i membri
  della famiglia per inserire/disinserire l'allarme da Home Assistant.

---

## 2. Configurazione della centrale

Questa sezione è la parte **più importante** di tutta l'installazione.
Serve a creare un codice utente dedicato al bridge, con permessi di **sola
lettura** sulla centrale.

### Perché un utente dedicato?

L'add-on ha bisogno di un codice utente per autenticarsi alla centrale e
poter leggere lo stato (quali aree sono armate, se c'è un allarme, cosa
succede nel log eventi, ecc.). Questo PIN deve essere scritto nel file
di configurazione dell'add-on: diventa visibile a chiunque abbia accesso
ai file di Home Assistant (backup compresi).

Per questo motivo, dalla versione 1.2.0 il bridge usa un modello di
sicurezza "a due livelli":
- Il PIN scritto nella configurazione (che chiamiamo **PIN di sistema**)
  ha permessi di **sola lettura** — non può inserire, disinserire, né
  cambiare niente.
- Tutte le azioni che modificano lo stato dell'allarme richiedono il
  **PIN di un utente vero**, che l'utente digita al momento nel popup
  tastierino di Home Assistant (e che non viene mai memorizzato).

In questo modo, anche se il file di configurazione finisce nelle mani
sbagliate, il PIN che contiene non può fare danni.

### Creare il codice "HA Bridge"

Nel software **Prime/STUDIO**, apri il progetto della tua centrale e vai
in **Centrale → Codici**. Crea un nuovo codice e configuralo così:

**Scheda principale**

- **Descrizione**: `HA Bridge` (o qualsiasi nome tu preferisca).
- **Tipo**: `Utente`.
- **Filtro su aree**: non spuntato.
- **Codice a lunghezza fissa**: come preferisci (indifferente ai fini del
  bridge).
- **Aree** (checkbox a sinistra con i nomi delle tue aree): **spuntale
  tutte**. Spuntare un'area dà a questo codice il diritto di *leggerne
  lo stato*, non di armarla o disarmarla. Senza la spunta, la centrale
  rifiuta di dire anche lo stato di quell'area, e il bridge non potrà
  sincronizzarla.

**Scheda "Dettaglio abilitazioni"**

Spunta **solo queste due** voci:
- ✅ **Menu visualizzazione** — fondamentale: senza questa, la centrale
  non lascia leggere il bitmap degli scenari attivi, e gli scenari in
  Home Assistant si "spengono" da soli dopo pochi secondi.
- ✅ **Menu gestione allarmi** — serve per leggere la memoria allarmi
  nelle aree.

**Tutte le altre devono restare NON spuntate**, in particolare:
- ⬜ Menu inserimenti
- ⬜ Menu attivazioni
- ⬜ Menu di controllo uscite
- ⬜ Menu cambio PIN
- ⬜ Menu impostazione tastiera
- ⬜ Menu funzioni vocali
- ⬜ Menu data/ora
- ⬜ Numeri di telefono
- ⬜ Impostazioni
- ⬜ Richiesta straordinario
- ⬜ Termostato ambientale
- ⬜ Codici
- ⬜ Timers

**Scheda "Abilitazione uscite"**

Tutte le uscite devono essere **NON spuntate**. Questo blocca il codice
"HA Bridge" dal poter comandare qualsiasi uscita, incluse le sirene.

**Scheda "Modifica PIN utente"**

Imposta un PIN numerico di 4-6 cifre, diverso dai PIN degli utenti reali.
Scriviti questo valore: è quello che andrà messo in `inim.pin` nella
configurazione dell'add-on (punto 4).

**Scrittura in centrale**

Dopo aver finito, premi `Scrivi` nel software Prime/STUDIO per inviare
la configurazione aggiornata alla centrale.

### Verifica rapida

Dopo aver creato il codice, se vuoi puoi testarlo alla tastiera della
centrale: digitandolo, il menu utente deve aprire la sola voce
"Visualizzazione" (e, se spunti anche Gestione allarmi, "Gestione
allarmi"). Nessun'altra voce. Se vedi altro, ricontrolla le abilitazioni.

---

## 3. Installazione dell'add-on

In Home Assistant:

1. Vai in **Impostazioni → Add-on → Store add-on**.
2. Menu in alto a destra → **Repository**, incolla l'URL del repository
   dell'add-on Hexesoft e salva.
3. Cerca **"Hexesoft Inim"** nell'elenco e clicca su di esso.
4. Premi **Installa**. L'operazione può richiedere qualche minuto.
5. Non avviarlo ancora: prima bisogna configurarlo (punto 4).

---

## 4. Configurazione dell'add-on

Nella scheda **Configurazione** dell'add-on compili questo modulo:

```yaml
inim:
  host: "192.168.1.50"          # IP della tua centrale
  port: 6004                     # Porta SmartLAN, non toccare
  password: "la_tua_password_smartlan"
  pin: "1234"                    # PIN del codice "HA Bridge" creato al punto 2
  connectiontype: 2              # Non toccare
  contactpollinterval: 5         # Ogni quanti secondi il bridge rilegge aree/log

mqtt:
  host: "core-mosquitto"         # Lascia così se usi l'add-on Mosquitto broker
  port: 1883
  username: ""                   # Vuoto se MQTT è anonimo
  password: ""                   # Vuoto se MQTT è anonimo
  basetopic: "inim_bridge"       # Prefisso dei topic MQTT, non toccare
  discoveryprefix: "homeassistant"

systemsettings:
  loglevel: "info"               # "debug" solo in caso di problemi
```

**Spiegazione dei campi che contano davvero**:

- `inim.host`: l'IP della centrale sulla LAN. Lo trovi dal menu
  installatore della centrale oppure dalla pagina DHCP del tuo router.
- `inim.password`: la password della SmartLAN, NON un codice utente. È la
  stessa che l'installatore ha impostato nel menu *Configurazione → Rete
  → Password SmartLAN* della centrale.
- `inim.pin`: il PIN del codice "HA Bridge" che hai creato al punto 2.
  **Non** un PIN reale di casa.
- `inim.contactpollinterval`: ogni quanti secondi il bridge aggiorna lo
  stato delle aree, delle uscite, della diagnostica e legge nuovi eventi
  dal log. Le zone (sensori di movimento, contatti) sono invece aggiornate
  di continuo, su una connessione TCP dedicata, con reattività sotto il
  secondo. 5 secondi è un buon compromesso per tutto il resto. Puoi
  mettere `3` se vuoi tempi più reattivi, `10` se preferisci alleggerire
  il carico sulla centrale.
- `systemsettings.loglevel`: `info` in condizioni normali. `debug` solo
  quando stai cercando di capire un problema (produce molto log).

Dopo aver salvato, premi **Avvia** nell'intestazione dell'add-on. Nella
scheda **Registro** devi vedere qualcosa tipo:

```
INFO  | HEXE -> INIM | Connesso a 192.168.1.50:6004
INFO  | INIM -> HEXE | PanelInfo: PR500 fw 4.07 serial XXXXXXXXXX
INFO  | INIM -> HEXE | Trovate 152 zone attive ...
INFO  | INIM -> HEXE | Trovate 7 aree configurate ...
INFO  | INIM -> HEXE | Trovati 12 scenari configurati ...
INFO  | MQTT -> HEXE | Connesso al broker con successo.
```

Se vedi errori di autenticazione, ricontrolla `inim.password` (SmartLAN)
e `inim.pin` (codice HA Bridge). Se vedi timeout di rete, controlla
l'IP e che la porta 6004 sia raggiungibile.

---

## 5. Cosa compare in Home Assistant

Dopo l'avvio, nel giro di 10-20 secondi, nelle **Impostazioni → Dispositivi
e Servizi → MQTT** vedrai apparire tanti dispositivi.

### Il device "Hexesoft Inim Bridge"

È il device padre. Al suo interno trovi:

**Comandi globali (tutti richiedono PIN utente)**
- `lock.stop_sirene` — **Ferma allarmi**: clicca il lucchetto, digita il
  tuo PIN, l'azione parte e il lucchetto si "richiude" da solo.
- `lock.cancella_telefonate` — **Cancella telefonate**: svuota la coda
  delle chiamate PSTN/GSM che la centrale sta tentando di fare.
- `lock.reset_memoria_allarmi` — **Cancella memoria allarme**: azzera i
  flag di "memoria allarme" / "memoria sabotaggio" su tutte le aree.

**Scenari (uno per coppia On X / Off X configurata in centrale)**

Gli scenari che l'installatore ha configurato in centrale a coppie "On X"
+ "Off X" (es. "On Notte" / "Off Notte", "On Tutto" / "Off Tutto")
compaiono come entità `lock.hexesoft_inim_bridge_<nome>`:
- Lucchetto **chiuso** = scenario applicato.
- Lucchetto **aperto** = scenario revertito.
- Clic sul lucchetto apre il tastierino PIN; dopo che digiti il tuo PIN
  utente la centrale esegue lo scenario e lo stato cambia di conseguenza.

Esempi di entity id (il nome dipende da come hai chiamato lo scenario in
centrale):
- `lock.hexesoft_inim_bridge_tutto`
- `lock.hexesoft_inim_bridge_notte`
- `lock.hexesoft_inim_bridge_esterno_1`

**Storico eventi della centrale**
- Un'entità `event.evento_centrale` che genera una riga nella plancia
  **Attività** di Home Assistant per ogni nuovo evento registrato dalla
  centrale (allarmi, inserimenti, scenari, codici riconosciuti, test
  periodici, chiamate telefoniche, guasti, ecc.), con lo stesso dettaglio
  del software Inim.

**Diagnostica (23 sensori)**

Sotto il device Bridge trovi 23 sensori diagnostici organizzati in:
- *Alimentazione*: tensione rete, tensione batteria, tensione bus,
  corrente bus, batteria bassa, batteria wireless bassa, mancanza rete,
  guasto alimentatore.
- *Comunicazioni*: internet connesso, evento scomparsa internet, guasto
  GSM, guasto linea telefonica.
- *Sabotaggi / guasti*: tamper scomparsa, tamper antistrappo, tamper
  antiapertura, sensore wireless scomparso, jamming radio, problema
  tastiere radio, guasto zona, guasto sirena, sensore sporco, ponticello
  di servizio, centrale in programmazione.

**Diagnostica del ponte stesso**
- `sensor.poll_cycle_time` — millisecondi dell'ultimo ciclo di polling
  zone (utile per capire se il ponte sta dialogando reattivamente).
- `sensor.poll_metadata_time` — millisecondi dell'ultimo ciclo di polling
  metadata (aree, uscite, log, diagnostica).

**Pulsante di manutenzione**
- `button.rimuovi_tutto` — pulisce dal broker MQTT tutte le entità
  pubblicate dal bridge. Usalo solo se devi reinstallare da zero o
  rinominare la centrale. Richiede riavvio dell'add-on dopo averlo
  premuto.

### Un device per ogni area

Ogni area che l'installatore ha configurato in centrale (es. "Casa 1",
"Garage", "Esterno 1") diventa un `alarm_control_panel.area_<nome>`:
- Richiede il PIN **sia per inserire** sia per disinserire.
- Mostra come modi disponibili *Fuori casa (ARM_AWAY)* e, solo per le
  aree che la programmazione della centrale mette anche in "Parziale",
  *In casa (ARM_HOME)*. Il rilevamento è automatico leggendo la tabella
  degli scenari di inserimento: non devi configurare niente a mano.
- Lo stato è uno fra *Disattivo*, *Fuori casa* (Totale), *In casa*
  (Parziale), *Allarme in corso*.

### Un device per ogni zona

Ogni zona (sensore di movimento, contatto porta, tamper) diventa un
`binary_sensor` di tipo "motion":
- Stato *ON* quando la zona è "aperta" o rilevata.
- Stato *OFF* quando è a riposo.
- Reattività sotto il secondo perché il bridge ha una connessione TCP
  dedicata al polling delle zone.

### Un device per ogni uscita

Ogni uscita (relè onboard, uscite su bus) diventa un `switch`:
- Puoi accenderla/spegnerla manualmente.
- Lo stato ON/OFF rispecchia quello reale della centrale.

> **Nota**: nel modello di sicurezza 1.2.0+ gli switch uscita NON
> richiedono PIN per essere comandati, perché l'add-on non li protegge
> con tastierino. Se nella tua centrale certe uscite sono sensibili
> (es. sirene, elettroserrature) puoi dichiarare un codice bridge
> addizionale che ne blocca il comando, oppure gestirle con una
> automazione HA che chiede conferma.

---

## 6. Come funziona il PIN

Dalla versione 1.2.0 ogni azione che modifica lo stato della centrale
richiede il PIN di un utente vero, inserito al momento. Il PIN **non
viene mai memorizzato** da Home Assistant né dall'add-on: viene
intercettato dal popup, passato alla centrale che lo valida contro la sua
tabella codici, e poi scartato.

**Chi digita cosa**

- Inserire o disinserire un'area → popup PIN → digita il tuo PIN Inim.
- Applicare o revertire uno scenario → popup PIN → digita il tuo PIN.
- Ferma allarmi / Cancella telefonate / Cancella memoria → popup PIN →
  digita il tuo PIN.

**Chi può fare cosa**

I permessi li controlla la centrale, NON Home Assistant. Se Mario ha un
PIN che può armare Casa 1 ma non Garage, cliccando "Fuori casa" sul
Garage digiterà il suo PIN e la centrale rifiuterà il comando (con
registrazione nel log "codice errato"). Il bridge si limita a passare
il PIN; la centrale decide.

Ogni azione viene tracciata nel log della centrale col **nome dell'utente
vero** (quello del PIN digitato), non genericamente col nome del bridge.

**Popup tastierino in HA**

- Perché il popup compaia, nelle tile delle aree devi usare la feature
  `alarm-modes`. Vedi l'esempio di dashboard al punto 7.
- Per gli scenari e i comandi globali (lock entity), il popup è
  automatico: cliccare il lucchetto apre direttamente il tastierino.

---

## 7. Esempio di dashboard

Esempio minimale di una vista "Antifurto" con aree, scenari e comandi
centrale. Richiede Home Assistant 2024.11 o successivo per il popup
tastierino sulle features.

```yaml
views:
  - title: Antifurto
    path: antifurto
    type: sections
    icon: mdi:shield-home
    sections:
      - type: grid
        cards:
          - type: heading
            heading: Aree
          - type: tile
            entity: alarm_control_panel.area_casa_1
            name: Casa 1
            features:
              - type: alarm-modes
                modes:
                  - armed_away
                  - armed_home
          - type: tile
            entity: alarm_control_panel.area_garage
            name: Garage
            features:
              - type: alarm-modes
                modes:
                  - armed_away

      - type: grid
        cards:
          - type: heading
            heading: Scenari
          - type: tile
            entity: lock.hexesoft_inim_bridge_tutto
            name: Tutto
            icon: mdi:shield-lock
          - type: tile
            entity: lock.hexesoft_inim_bridge_notte
            name: Notte
            icon: mdi:weather-night

      - type: grid
        cards:
          - type: heading
            heading: Comandi centrale
          - type: tile
            entity: lock.stop_sirene
            name: Ferma allarmi
            icon: mdi:volume-off
            color: red
          - type: tile
            entity: lock.cancella_telefonate
            name: Cancella telefonate
            icon: mdi:phone-off
          - type: tile
            entity: lock.reset_memoria_allarmi
            name: Cancella memoria allarme
            icon: mdi:bell-off
```

---

## 8. Cosa NON fa questo add-on

- Non gestisce i termostati Inim (esistono nelle centrali Prime ma sono
  fuori scope antifurto).
- Non gestisce chiavi di prossimità o contatti RFID come entità separate
  — vengono però usate per etichettare i loro eventi nel log storico.
- Non permette di modificare PIN, utenti o programmazione della centrale
  da Home Assistant.
- Non comunica con servizi cloud di terze parti (Inim Cloud o altri).
  Il bridge parla solo con la tua centrale in LAN e con il tuo broker
  MQTT in LAN.
- Non richiede modifiche alla programmazione della centrale oltre alla
  creazione del codice "HA Bridge" descritto al punto 2.

---

## 9. Risoluzione problemi

### L'add-on non si avvia o si scollega

Guarda nella scheda **Registro** dell'add-on. Gli errori più comuni:

- `Autenticazione fallita` → `inim.password` sbagliata. È la password
  SmartLAN, non un PIN.
- `Timeout` / `host unreachable` → l'IP della centrale è sbagliato o
  la centrale non è raggiungibile. Controlla con `ping`.
- `PIN non valido` → il PIN nel `config.yaml` non è stato riconosciuto
  dalla centrale. Verifica che il codice "HA Bridge" esista nella
  centrale e che il PIN coincida.

### Vedo "Entità non trovata" in dashboard

Succede se cambi l'entity_id lato dashboard senza allineare il backend,
o se l'entità è stata rimossa. Controlla in **Impostazioni → Dispositivi
e Servizi → MQTT** quali entità il bridge ha effettivamente registrato,
e correggi il tuo YAML di dashboard di conseguenza.

### Gli scenari si "spengono" da soli dopo pochi secondi

Il codice "HA Bridge" non ha i permessi di **lettura** sugli scenari
attivi. Torna al punto 2 e verifica che nelle *Abilitazioni* del codice
sia spuntato **"Menu visualizzazione"** (voce indispensabile).

### Il popup PIN non compare quando clicco "Fuori casa"

Succede se il tile nella tua dashboard non ha le `features: alarm-modes`
oppure se la tua versione di Home Assistant è anteriore alla 2024.11
(il popup tastierino sui pulsanti feature è stato introdotto in quella
versione). Soluzioni:
- aggiornare HA all'ultima versione;
- oppure, in dashboard, cambiare `type: tile` in `type: alarm-panel`
  (card dedicata, mostra il tastierino sempre visibile, ma occupa più
  spazio).

### Un'azione viene rifiutata ("Codice errato" nel log)

Succede quando il PIN digitato dall'utente non ha i permessi per fare
quella specifica azione (es. Mario tenta di disarmare Casa 3 ma non ha
quell'area tra le sue). Quella politica è decisa in centrale, non dal
bridge: per cambiarla modifica i permessi dell'utente nel software
Prime/STUDIO.

### Voglio reinstallare da zero

Premi il button `Rimuovi Tutto` sotto il device Bridge in Home Assistant
→ attendi 5 secondi → riavvia l'add-on. Tutte le entità vengono
ricreate dalla discovery.

---

## 10. Note tecniche per curiosi

Questa sezione è per chi vuole farsi un'idea di come lavora il bridge.
Non è necessaria per usarlo.

**Due connessioni separate alla centrale**: il bridge dialoga con la
centrale aprendo due canali di rete distinti. Uno è riservato al
controllo continuo dello stato delle zone (sensori di movimento,
contatti), l'altro gestisce tutto il resto (comandi di inserimento /
disinserimento, scenari, lettura degli eventi, diagnostica). Grazie a
questa divisione la reattività dei sensori resta sotto il secondo anche
mentre l'add-on sta facendo operazioni più lunghe sull'altro canale.

**Autenticazione**: ogni azione che modifica lo stato della centrale
(inserimento, disinserimento, applicazione di uno scenario, fermata
delle sirene, cancellazione memoria) viene inviata insieme al PIN
dell'utente che l'ha richiesta — quello che viene digitato nel popup
tastierino di Home Assistant. È la centrale a validare quel PIN e a
decidere se l'utente ha i permessi per fare quella specifica azione.
Il PIN scritto nella configurazione dell'add-on (il PIN del codice
"HA Bridge") viene invece usato solo per le letture periodiche (stato
delle aree, scenari attivi, eventi nel log, diagnostica), e non è in
grado di modificare nulla — per questo si consiglia di crearlo come
service account di sola lettura (vedi punto 2).

**Riconnessione automatica**: tutte le connessioni (verso la centrale
e verso il broker MQTT) hanno riconnessione automatica con tentativi a
cadenza crescente. Se la centrale si rende temporaneamente non
raggiungibile — perché l'installatore ne sta aggiornando la
programmazione, perché sta facendo un riavvio o per un problema di
rete — il bridge aspetta e riprova finché non torna disponibile, senza
che tu debba intervenire. Se cade il broker MQTT, tutte le entità
pubblicate dal bridge compaiono come "non disponibili" in Home
Assistant; tornano disponibili da sole alla riconnessione.

---

## Supporto

Per problemi non risolti dal punto 9: apri una issue nel repository
dell'add-on allegando le righe pertinenti della scheda **Registro**. Se
riporti un bug di comportamento, imposta `systemsettings.loglevel: debug`
per qualche minuto prima di catturare il log — contiene molti più
dettagli diagnostici.

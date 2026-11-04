# Changelog

Elenco delle novità, migliorie e correzioni introdotte in ogni versione
dell'add-on Hexesoft Inim Bridge, descritte dal punto di vista di chi lo
usa in Home Assistant.

Il numero di versione segue la convenzione MAJOR.MINOR.PATCH:
- **MAJOR**: cambia qualcosa che richiede un intervento di configurazione
  (per esempio modificare il file delle impostazioni dell'add-on o rifare
  la dashboard).
- **MINOR**: nuove funzioni che si aggiungono senza rompere quelle esistenti.
- **PATCH**: correzioni di bug o migliorie che non cambiano il modo di
  usare l'add-on.

---

## 1.2.5

### Documentazione
- **Riscritta la sezione finale "Note tecniche per curiosi" di DOCS.md**
  in forma più sintetica. La versione precedente entrava nel dettaglio di
  nomi di protocollo, numeri di comando e strutture interne della
  centrale; adesso descrive solo, ad alto livello, i due canali di
  comunicazione verso la centrale (uno dedicato al polling delle zone,
  l'altro a comandi/scenari/log), il fatto che ogni azione viaggia con
  il PIN dell'utente che l'ha richiesta, e la riconnessione automatica.
  Nessun cambio di comportamento, solo documentazione.

---

## 1.2.4

### Correzioni
- **L'add-on non si spegne più se la centrale rifiuta la connessione
  all'avvio.** Capita tipicamente quando l'installatore sta scrivendo la
  programmazione dalla centrale col software Prime/STUDIO (la SmartLAN
  rifiuta connessioni in quel momento), quando la centrale si sta
  riavviando dopo un aggiornamento, o quando la rete fa i capricci. Fino
  alla 1.2.3 un singolo rifiuto bastava a far crashare l'add-on, che
  andava riavviato a mano. Dalla 1.2.4 il bridge aspetta e riprova con
  cadenza crescente (5, 10, 20, 40, poi 60 secondi) fino a quando la
  centrale torna raggiungibile.
- Il messaggio nei log è più chiaro: invece di stampare uno stack trace
  di "SocketException 10061", adesso scrive *"Centrale 192.168.x.y:6004
  ha rifiutato la connessione TCP (SmartLAN occupata, centrale in
  programmazione o porta chiusa?)"*, oppure *"Timeout di 15s
  connettendomi a ... (host offline, rete non raggiungibile o firewall?)"*.
  Lo stesso trattamento vale sia per la connessione iniziale sia per le
  riconnessioni a regime dopo un errore di comunicazione.

---

## 1.2.3

### Novità — Permessi richiesti al codice del bridge in centrale

La raccomandazione introdotta nella 1.2.0 ("crea un utente dedicato
al bridge con permessi di sola autenticazione") era insufficiente: senza
nessun permesso, la centrale non lascia leggere nemmeno lo stato in
tempo reale degli scenari, e il bridge finisce per considerare sempre
"disinseriti" gli scenari che l'utente ha appena attivato dal tastierino
HA. Il circuit-breaker messo in 1.2.2 per mascherare il problema è stato
rimosso (perdeva la sincronizzazione con comandi dati dal tastierino
fisico, un prezzo troppo alto).

Il modello corretto è: il codice del bridge deve avere i permessi minimi
di **LETTURA** su tutto, e **nessun** permesso di scrittura.

**Permessi da assegnare al codice "HA Bridge" nella centrale** (software
Prime/STUDIO, scheda Codici):
- Tipo: **Utente**
- **Tutte le aree** spuntate sulla colonna di sinistra (Casa 1/2/3, Garage,
  Esterno 1/2/3, eventuali altre). Spuntare un'area dà il permesso di
  leggerne lo stato, non di armarla.
- Abilitazioni: spuntare solo **"Menu visualizzazione"** e
  **"Menu gestione allarmi"**. Tutte le altre devono restare non spuntate.
- Abilitazione uscite (riquadro a destra): tutte NON spuntate.

Con questi permessi la centrale lascia al PIN del bridge la lettura
completa (stato aree, bitmap scenari attivi, memoria allarmi, diagnostica)
ma rifiuta qualunque azione (ARM/DISARM/scenari/sirene/memoria) perché
manca il "Menu inserimenti" e le altre abilitazioni di gestione. Quelle
azioni continueranno a funzionare solo quando saranno lanciate col PIN
di un utente vero digitato nel popup di Home Assistant.

### Correzioni / Rimosso
- Rimosso il circuit-breaker 1.2.2 che disabilitava automaticamente la
  sincronizzazione degli scenari quando il PIN del bridge appariva
  read-only. Dava sì stabilità al lucchetto "attivato dall'utente ma
  rilevato come inattivo dalla centrale", ma al prezzo di ignorare per
  sempre le azioni fatte dal tastierino fisico. Con i nuovi permessi
  descritti qui sopra la sincronizzazione torna a funzionare in entrambe
  le direzioni.

---

## 1.2.1

### Correzioni
- **Gli scenari ora compaiono anche col PIN "service account" read-only.**
  Chi, seguendo la guida di 1.2.0, ha messo nel `config.yaml` il PIN di un
  utente Inim di sola lettura si trovava con tutte le entità lock degli
  scenari sparite dalla dashboard (Home Assistant diceva "Entità non
  trovata"). Era un filtro troppo stretto nella fase di discovery: il
  bridge chiedeva alla centrale "quali scenari è autorizzato ad attivare
  questo PIN?" e, giustamente, la centrale rispondeva "nessuno". Il
  filtro adesso usa solo il nome registrato in centrale per distinguere
  scenari veri dai placeholder di fabbrica ("Scenario 25", "Scenario 26",
  ecc.): se lo scenario esiste, viene pubblicato in HA. L'autorizzazione
  viene comunque controllata al momento del click, con il PIN digitato
  dall'utente nel popup.
- Lo stesso problema potrebbe presentarsi anche dopo aver cambiato l'utente
  della centrale associato al bridge: non serve più riavviare o ripartire
  da zero, basta aggiornare a questa versione.

---

## 1.2.0

### Novità — PIN obbligatorio per ogni azione, PIN di sistema solo in lettura

Questa versione cambia il modello di sicurezza del ponte. L'obiettivo è che
il PIN scritto in `config.yaml` possa essere un codice "innocuo", capace
solo di leggere lo stato della centrale, e che ogni azione che cambia
davvero qualcosa (inserire, disinserire, applicare uno scenario, fermare
sirene, ecc.) richieda il PIN del vero utente, digitato lì per lì sul
tastierino di Home Assistant.

**Cosa devi fare prima di aggiornare**

Nel software di programmazione Inim, crea un utente dedicato al ponte (per
esempio chiamalo "HA Bridge") con:
- accesso in lettura a tutte le aree,
- **nessun permesso** di inserimento, disinserimento, scenari e comandi
  globali (ferma sirene, cancella chiamate, cancella memoria).

Poi, in `config.yaml` dell'add-on, metti il PIN di quel nuovo utente nel
campo `inim.pin`. Se qualcuno dovesse leggere il file di configurazione o
un backup, trova un PIN che non può disinserire l'allarme.

**Novità in Home Assistant**

- **Inserimento area protetto da PIN.** Il tile `alarm_control_panel`
  adesso apre il tastierino PIN anche quando premi "Fuori casa" o "In casa",
  non solo su "Disattiva". Niente modifiche alla dashboard: i tile esistenti
  si adeguano al primo riavvio.
- **"Ferma allarmi", "Cancella telefonate", "Cancella memoria" ora
  richiedono il PIN.** Questi 3 comandi non sono più pulsanti semplici: sono
  diventati lucchetti (entità `lock`). Cliccandoli HA apre il tastierino PIN
  come per gli scenari, poi esegue l'azione e il lucchetto si "richiude"
  da solo.

  **Modifica necessaria nelle dashboard**: dove oggi hai
  `button.stop_sirene`, `button.cancella_telefonate` o
  `button.reset_memoria_allarmi`, sostituisci con:
  - `lock.stop_sirene`
  - `lock.cancella_telefonate`
  - `lock.reset_memoria_allarmi`

  Al primo riavvio i vecchi `button.*` spariscono dal registro HA e
  compaiono al loro posto i nuovi `lock.*`.

### Rimosso
- **Fallback silenzioso sul PIN di sistema.** Prima, se un'azione partiva
  senza PIN, il bridge usava di nascosto il PIN di `config.yaml`. Adesso
  non più: senza PIN valido nel popup l'azione viene rifiutata e nei log
  dell'add-on vedi scritto "senza PIN utente: rifiutato". Questo riguarda
  inserimento/disinserimento aree, scenari e i 3 comandi globali.

### Note di sicurezza
- Il PIN in `config.yaml` adesso serve **solo** per polling, discovery e
  lettura del log eventi. Non viene mai usato per cambiare lo stato della
  centrale, né è disponibile un'opzione per tornare al vecchio
  comportamento: ogni azione richiede il PIN digitato dall'utente, senza
  eccezioni. Per questo conviene che il PIN qui dentro sia di un utente
  Inim creato apposta, con permessi di sola lettura: se un domani il file
  di configurazione o un backup finissero in mani sbagliate, quel PIN non
  può comunque disinserire niente.
- Tutte le azioni che cambiano stato della centrale vengono tracciate nel
  log Inim col nome dell'utente reale (quello del PIN digitato), non più
  genericamente col nome del ponte.

---

## 1.1.4

### Correzioni
- **Lucchetti degli scenari ora reagiscono al PIN.** Nella versione 1.1.3 il
  tastierino PIN degli scenari (entità `lock.hexesoft_inim_bridge_<nome>`)
  si apriva ma, anche digitando il codice corretto, lo scenario non veniva
  applicato o revertito. Era un problema di configurazione del tastierino
  che Home Assistant mostrava senza mai inviare il comando alla centrale.
  Adesso il PIN viene validato correttamente e lo scenario parte come
  atteso. Nessuna modifica necessaria alle dashboard: basta riavviare
  l'add-on.

---

## 1.1.3

### Novità
- **Disattivazione area protetta da PIN utente.** Quando premi "Disattiva"
  su un'area dalla dashboard di Home Assistant, HA apre un popup con
  tastierino numerico e ti chiede di digitare il tuo PIN della centrale
  Inim. Il PIN viene passato direttamente alla centrale che lo valida e
  applica i tuoi permessi: se non sei autorizzato a disattivare
  quell'area, il comando viene rifiutato e l'evento "Codice errato"
  compare nella plancia Attività. L'inserimento (Fuori casa / In casa)
  continua invece a non richiedere PIN, perché è un'azione sicura.
  Nessuna modifica necessaria alle tue dashboard: i tile `alarm_control_panel`
  esistenti attivano automaticamente il popup al primo riavvio dopo
  l'aggiornamento.

- **Scenari protetti da PIN utente.** Gli scenari (Tutto, Esterno, Garage,
  Notte 1/2/3, ecc.) vengono ora pubblicati in Home Assistant come entità
  `lock` (lucchetto) anziché come `switch`. Quando premi uno scenario per
  applicarlo o revertirlo, HA apre il popup del tastierino numerico e ti
  chiede il tuo PIN della centrale, esattamente come per il disarmo area.
  Significato: lucchetto chiuso = scenario applicato; lucchetto aperto =
  scenario revertito.
  **Modifica necessaria nelle tue dashboard**: nei tile e nelle card che
  oggi riferiscono `switch.hexesoft_inim_bridge_scenario_<nome>` sostituisci
  con `lock.hexesoft_inim_bridge_<nome>` (senza "scenario_" nel mezzo).
  Esempi:
  - `switch.hexesoft_inim_bridge_scenario_1` → `lock.hexesoft_inim_bridge_1`
  - `switch.hexesoft_inim_bridge_scenario_notte_1` → `lock.hexesoft_inim_bridge_notte_1`
  - `switch.hexesoft_inim_bridge_scenario_garage` → `lock.hexesoft_inim_bridge_garage`

  Al primo riavvio dopo l'aggiornamento il vecchio `switch` sparisce dal
  registro di HA e compare al suo posto il nuovo `lock`.

- **Storico eventi della centrale nella plancia "Attività" di Home Assistant.**
  Tutti gli eventi che la centrale registra nel suo log (allarmi,
  inserimenti, scenari, codici riconosciuti, test periodici, telefonate,
  ecc.) compaiono automaticamente nella sidebar **Attività** di Home
  Assistant, con lo stesso dettaglio del software di programmazione Inim:
  evento, maschera, agente, locazione, categoria. Non serve più aggiungere
  card personalizzate alla dashboard per leggere il log — basta aprire
  Attività.

### Miglioramenti
- I nomi degli eventi della centrale ora sono tutti leggibili. Prima alcuni
  eventi comparivano come "Evento tipo 8923" (un numero grezzo poco
  comprensibile); ora vengono mostrati con il loro nome vero ("Test
  periodico", "Mancanza internet", "Allarme globale", "Telefonata in corso"
  ecc.), identico a quello che si vede nel software Inim.
- Compatibilità garantita anche con le centrali Prime a firmware più recente
  (4.07 e successivi), che riportano alcuni tipi di evento aggiuntivi.

### Rimosso
- Il sensore `sensor.ultimo_evento` (quello che veniva usato dalle vecchie
  markdown card in dashboard per mostrare l'elenco degli ultimi 20 eventi)
  è stato eliminato. Lo storico eventi si consulta ora direttamente dalla
  plancia **Attività** di Home Assistant. Al primo riavvio dopo
  l'aggiornamento, l'entità sparisce in autonomia dal registro di HA.
  **Se nella tua dashboard avevi una markdown card che leggeva
  `sensor.ultimo_evento`, rimuovila a mano**: non mostrerà più nulla.

### Correzioni
- Risolto il problema per cui l'add-on, in certi casi, non riusciva a
  tradurre gli eventi della centrale in nomi leggibili. Ora, al primo
  avvio, l'add-on carica correttamente la tabella di decodifica degli
  eventi dalla centrale; se qualcosa dovesse andare storto, nei log
  dell'add-on viene scritto in modo chiaro cosa non ha funzionato.

---

## 1.1.2

Prima versione di cui si tiene traccia in questo changelog. Comprende:

- Connessione stabile alla centrale Inim Prime PR500 con riconnessione
  automatica in caso di caduta della rete.
- Pulsanti globali per: fermare gli allarmi, cancellare le telefonate in
  coda, cancellare la memoria degli allarmi.
- Gestione corretta degli scenari di inserimento, con riconoscimento
  automatico delle aree che supportano l'inserimento parziale.
- Pubblicazione automatica in Home Assistant (tramite MQTT auto-discovery)
  di: zone, aree, uscite, scenari, sensori diagnostici.

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

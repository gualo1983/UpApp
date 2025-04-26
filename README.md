# UpApp - Script di Aggiornamento del Sistema

[![Stato: In Sviluppo]][status-badge]

[status-badge]: https://img.shields.io/badge/Stato-In%20Sviluppo-yellow

**UpApp** è uno script Bash progettato per semplificare l'aggiornamento del sistema operativo e delle applicazioni Flatpak su diverse distribuzioni Linux. L'obiettivo principale è automatizzare il processo di aggiornamento, fornendo notifiche visive sullo stato e registrando le operazioni in un file di log.

## Funzionalità

* **Rilevamento Automatico della Distribuzione:** Identifica la distribuzione Linux in uso tramite il file standard `/etc/os-release`.
* **Aggiornamento del Sistema:** Esegue i comandi specifici per l'aggiornamento del sistema in base alla distribuzione rilevata (supporta Debian, Fedora, Arch Linux e openSUSE).
* **Pulizia del Sistema:** Rimuove pacchetti orfani o non necessari dopo l'aggiornamento.
* **Aggiornamento Flatpak:** Aggiorna tutte le applicazioni Flatpak installate e rimuove quelle inutilizzate.
* **Notifiche Desktop:** Utilizza `notify-send` per fornire feedback visivo all'utente sull'avanzamento e sul risultato delle operazioni. Richiede `libnotify-bin` (o pacchetti equivalenti) installato.
* **Log Dettagliato:** Registra tutte le operazioni, gli errori e gli avvisi in un file di log (`UpApp.log`) nella cartella delle risorse.
* **Gestione della Lingua:** Supporto per diverse lingue tramite file di configurazione `.ini`. L'inglese è la lingua predefinita, con possibilità di aggiungere traduzioni.
* **Configurazione:** Utilizza un file di configurazione (`config.ini`) per memorizzare lo stato e le impostazioni del programma.
* **Gestione degli Errori:** Implementa una gestione degli errori con logging e notifiche visive.
* **Tentativi di Inizializzazione:** Tenta l'inizializzazione (creazione di directory e file necessari) fino a un massimo di 3 volte in caso di fallimento iniziale.

## Prerequisiti

* **Bash:** Una shell Bash compatibile.
* **sudo:** Permessi di amministratore (saranno richiesti per gli aggiornamenti del sistema).
* **notify-send:** Utilità per l'invio di notifiche desktop (solitamente fornita dal pacchetto `libnotify-bin` o equivalente). Lo script tenta di installarlo se non trovato.
* **Flatpak:** Installato sul sistema per l'aggiornamento delle applicazioni Flatpak.

## Struttura delle Cartelle
```
UpApp/
├── resources/
│   ├── config.ini            # File di configurazione
│   ├── lang/
│   │   ├── en.ini            # File di lingua predefinito (inglese)
│   │   └── it.ini            # File di lingua corrente (italiano)
│   │   └── en_missing.ini    # File per le chiavi di lingua mancanti
│   ├── icon/
│   │   ├── success.svg       # Icona di successo per le notifiche
│   │   └── running.svg       # Icona di operazione in corso per le notifiche
│   │   └── error.svg         # Icona di errore per le notifiche
├── UpApp.sh                  # Lo script principale
├── LICENSE                   # File della  licenza GPLv3
└── README.md                 # File in markdown per la spiegazione del progetto
```

## Come Utilizzare

1.  **Clona il repository:**
    ```bash
    git clone <repository_url>
    cd UpApp
    ```

2.  **Rendi lo script eseguibile:**
    ```bash
    chmod +x UpApp.sh
    ```

3.  **Esegui lo script:**
    ```bash
    ./UpApp.sh
    ```

    Lo script eseguirà l'inizializzazione, verificherà e (se necessario) installerà `notify-send`, aggiornerà il sistema operativo e le applicazioni Flatpak, e mostrerà notifiche sullo stato. I dettagli saranno registrati nel file `resources/UpApp.log`.

## Configurazione

La configurazione principale è gestita internamente dallo script tramite il file `resources/config.ini`. Questo file memorizza lo stato dell'inizializzazione e la distribuzione rilevata. Non è generalmente necessario modificarlo manualmente.

I file di lingua (`.ini`) nella cartella `resources/lang` contengono le traduzioni dei messaggi visualizzati. Per aggiungere o modificare una lingua, è possibile creare un nuovo file `.ini` (seguendo la convenzione `[codice_lingua].ini`) e impostare la variabile `CURRENT_LANG` nello script al codice della lingua desiderata.

## Gestione degli Errori

Lo script include una gestione degli errori che registra i problemi nel file `UpApp.log` e visualizza notifiche desktop utilizzando icone specifiche per indicare successo, operazione in corso o errore.

## Supporto Distribuzioni

Attualmente, lo script supporta le seguenti distribuzioni Linux:

* Debian e derivate (es. Ubuntu)
* Fedora
* Arch Linux
* openSUSE

Il supporto per altre distribuzioni potrebbe essere aggiunto in futuro.

## Personalizzazione

* **Lingue:** È possibile aggiungere traduzioni per nuove lingue creando file `.ini` nella cartella `resources/lang`.
* **Comandi di Aggiornamento:** Per supportare altre distribuzioni, sarà necessario aggiungere i comandi di aggiornamento specifici all'interno della funzione `update_system()`.
* **Notifiche:** Le icone delle notifiche possono essere sostituite modificando i file `.svg` nella cartella `resources`.

## Contribuire

Le contribuzioni sono benvenute! Se hai suggerimenti, segnalazioni di bug o vuoi aggiungere il supporto per nuove distribuzioni, apri una issue o invia una pull request su GitHub.

## Icone

Le icone utilizzate per le notifiche sono state rilasciate nel pubblico dominio sotto la licenza [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/) e provengono da [vivek-g](https://iconduck.com/designers/vivek-g)

## Autore

gualo1983

## Licenza

Questo script è distribuito sotto la GNU General Public License v3.0.

Per maggiori dettagli, consultare il file [LICENSE](LICENSE).
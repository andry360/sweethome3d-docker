# 🚀 Sweet Home 3D Docker - Next Steps

## ✅ Completed

- [x] Dockerfile multi-stage per compilare Sweet Home 3D da sorgente
- [x] docker-compose.yml con configurazione completa
- [x] File .env.example per parametri configurabili
- [x] Script Proxmox ct/sweethome3d.sh
- [x] Script install/sweethome3d-install.sh
- [x] README.md con documentazione completa
- [x] Script backup-homes.sh e restore-homes.sh
- [x] File .gitignore e LICENSE

## 📝 To-Do Before Production Use

### 1. Testare la Build del Dockerfile
**Priorità: ALTA**

Il Dockerfile attuale assume che i sorgenti di Sweet Home 3D siano disponibili localmente nel path:
```
COPY SweetHome3D-7.7-Online/sweethome3d-code-r9047-branches-develop-SweetHome3D-7.7-Online-SweetHome3DJS /build/
```

**Opzioni:**

#### Opzione A: Build dal Workspace Locale (Testing)
1. Posizionarsi nella root del workspace dove si trova `SweetHome3D-7.7-Online/`
2. Copiare il Dockerfile nella root
3. Eseguire: `docker build -t sweethome3d-online:7.7 .`

#### Opzione B: Clone da Repository Ufficiale (Raccomandato)
Modificare il Dockerfile per clonare direttamente il repository:

```dockerfile
# Stage 1: Build Environment
FROM eclipse-temurin:11-jdk as builder

RUN apt-get update && apt-get install -y \
    ant git subversion wget unzip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Clone from official Sweet Home 3D repository
RUN svn checkout https://sourceforge.net/p/sweethome3d/code/HEAD/tarball?path=/branches/develop-SweetHome3D-7.7-Online/SweetHome3DJS sweethome3djs && \
    cd sweethome3djs && \
    tar -xzf downloaded
    
# Continue with build...
```

#### Opzione C: Download Release Pre-compilata
Se disponibile una versione pre-compilata, scaricarla direttamente:

```dockerfile
FROM php:8.2-apache

RUN wget -O /tmp/sh3d.zip https://sweethome3d.com/download/SweetHome3DJS-7.7-Online.zip && \
    unzip /tmp/sh3d.zip -d /var/www/html/ && \
    rm /tmp/sh3d.zip
```

### 2. Verificare i File di Deploy PHP

**Priorità: ALTA**

Controllare che i file in `deployDirectHomeRecorder/` siano completi:
- [x] `index.html` - Frontend
- [x] `writeData.php` - Salvataggio progetti
- [x] `deleteHome.php` - Eliminazione progetti
- [x] `listHomes.php` - Elencazione progetti
- [x] `readHome.php` - Caricamento progetti (opzionale)

Verificare che questi file funzionino con la versione compilata di Sweet Home 3D JS.

### 3. Configurare l'Autenticazione HTTP Basic

**Priorità: MEDIA**

Attualmente il file `.htaccess` ha le linee di autenticazione commentate. Per abilitarla:

1. Modificare `docker/htaccess.conf` decommentando le linee
2. Nel Dockerfile o docker-compose, aggiungere:
   ```dockerfile
   # Create htpasswd file with credentials
   RUN apt-get install -y apache2-utils && \
       htpasswd -bc /var/www/.htpasswd ${AUTH_USERNAME} ${AUTH_PASSWORD}
   ```

Oppure usare un entrypoint script che genera dinamicamente le credenziali.

### 4. Pubblicare su GitHub

**Priorità: MEDIA**

1. Creare repository su GitHub: `sweethome3d-docker`
2. Pushare il codice:
   ```bash
   cd sweethome3d-docker
   git init
   git add .
   git commit -m "Initial commit: Sweet Home 3D 7.7-Online Docker setup"
   git remote add origin https://github.com/YOUR_USERNAME/sweethome3d-docker.git
   git push -u origin main
   ```
3. Aggiornare i link nel README.md con l'URL corretto del repository

### 5. Distribuire su Community Scripts (Opzionale)

**Priorità: BASSA**

Per integrare con community-scripts.org:

1. Fork del repository [ProxmoxVED](https://github.com/community-scripts/ProxmoxVED)
2. Copiare `ct/sweethome3d.sh` e `install/sweethome3d-install.sh` nella fork
3. Creare file JSON metadata per il sito web
4. Aprire PR per review

**Nota:** Gli script dovranno essere adattati per scaricare i file Docker da un repository pubblico.

### 6. Test Completo End-to-End

**Priorità: ALTA**

Checklist testing:

- [ ] Build Docker image completa con successo
- [ ] Container parte correttamente su porta 8080
- [ ] Interfaccia Sweet Home 3D carica nel browser
- [ ] Possibile creare un nuovo progetto
- [ ] Salvataggio progetto funziona (file .sh3d creato in `homes/`)
- [ ] Caricamento progetto salvato funziona
- [ ] Eliminazione progetto funziona
- [ ] Autenticazione HTTP Basic funziona (se abilitata)
- [ ] Script Proxmox crea LXC container correttamente
- [ ] Script di backup/restore funzionano
- [ ] Container può essere aggiornato senza perdita dati

### 7. Ottimizzare le Dimensioni dell'Immagine

**Priorità: BASSA**

L'immagine multi-stage potrebbe essere grande. Ottimizzazioni:

- Usare `alpine` invece di `debian` per lo stage runtime
- Rimuovere file non necessari dopo la build
- Minificare ulteriormente file JS/CSS
- Usare `.dockerignore` per evitare di copiare file inutili

### 8. Aggiungere Health Check più Robusto

**Priorità: BASSA**

Il current health check verifica solo se Apache risponde. Migliorarlo:

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost/ && \
        test -f /var/www/html/index.html && \
        test -d /var/www/html/homes || exit 1
```

### 9. Configurazione NPMplus Automatizzata

**Priorità: BASSA**

Creare uno script o documentazione per automatizzare la configurazione NPMplus:
- Script Terraform/Ansible
- Template configurazione NPMplus
- Script bash che usa API di NPMplus

### 10. Monitoraggio e Logging

**Priorità: BASSA**

Aggiungere:
- Integrazione con Prometheus per metriche
- Log aggregation (Loki, ELK)
- Alert per spazio disco esaurito su `homes/`

## 🔄 Workflow Consigliato

1. **Prima fase - Testing Locale**
   - Testare build Docker sul tuo sistema locale
   - Verificare che Sweet Home 3D funzioni
   - Testare salvataggio/caricamento progetti

2. **Seconda fase - Proxmox Testing**
   - Creare manualmente un container LXC
   - Installare Docker e copiare i file
   - Testare deploy completo

3. **Terza fase - Script Automation**
   - Testare script Proxmox `ct/sweethome3d.sh`
   - Verificare installazione automatica
   - Testare funzione update

4. **Quarta fase - Produzione**
   - Pubblicare su GitHub
   - Documentare configurazione NPMplus
   - Setup backup automatici

## 🛠️ Quick Test Command

Per testare rapidamente la build Docker:

```bash
cd c:/docker/side-projects/self-hosting/swwthome3d
docker build -f sweethome3d-docker/Dockerfile -t sweethome3d-online:test .
docker run -d -p 8080:80 --name sh3d-test sweethome3d-online:test
```

Poi apri: http://localhost:8080

Per cleanup:
```bash
docker stop sh3d-test
docker rm sh3d-test
docker rmi sweethome3d-online:test
```

## 📞 Support

Per domande o problemi durante i test, consulta:
- [Sweet Home 3D Forum](https://www.sweethome3d.com/support/forum/)
- [Docker Documentation](https://docs.docker.com/)
- [Proxmox VE Forum](https://forum.proxmox.com/)

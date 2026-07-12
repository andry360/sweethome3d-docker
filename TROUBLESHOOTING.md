# 🔧 Troubleshooting - SweetHome3D Docker

## ❌ Problema 1: "Connessione non riuscita" da browser (192.168.4.25:8080)

### 🔍 Diagnosi

#### Step 1: Verificare che il container sia running

```bash
# Su Proxmox host, sostituire <CTID> con l'ID del container (es: 106)
pct exec <CTID> -- docker compose -C /opt/sweethome3d ps
```

**Output atteso:** Status deve essere "Up"

```
CONTAINER ID   IMAGE                         COMMAND                  STATUS
abc123...      sweethome3d-online:7.7       "/usr/local/bin/ent..."  Up 2 minutes
```

#### Step 2: Verificare che Apache ascolti sulla porta 80

```bash
pct exec <CTID> -- netstat -tulpn | grep 80
```

**Output atteso:**
```
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      12345/apache2
```

#### Step 3: Testare connettività da dentro il container

```bash
pct exec <CTID> -- curl -I http://localhost:80
```

**Output atteso:**
```
HTTP/1.1 200 OK
```

oppure (se autenticazione abilitata):
```
HTTP/1.1 401 Unauthorized
```

#### Step 4: Testare connettività da Proxmox host

```bash
curl -I http://192.168.4.25:8080
```

#### Step 5: Verificare i log del container

```bash
pct exec <CTID> -- docker compose -C /opt/sweethome3d logs --tail=50
```

Cercare errori tipo:
- `AH00558: apache2: Could not reliably determine the server's FQDN`
- `listen: Permission denied`
- File permission errors

#### Step 6: Controllare la configurazione di rete del container

```bash
# Verificare IP del container
pct exec <CTID> -- ip addr show

# Verificare routing
pct exec <CTID> -- ip route

# Testare DNS
pct exec <CTID> -- nslookup google.com
```

### ✅ Soluzioni

#### Soluzione 1: Container non è running

Se `docker compose ps` mostra "Exited":

```bash
# Rebuild e restart
pct exec <CTID> -- bash -c "cd /opt/sweethome3d && docker compose down && docker compose build && docker compose up -d"

# Aspettare 30 secondi e verificare i log
sleep 30
pct exec <CTID> -- docker compose -C /opt/sweethome3d logs --tail=100
```

#### Soluzione 2: Problema di build del Dockerfile

La build di SweetHome3D richiede 20-30 minuti e ~4GB di RAM.

Se il build è fallito per mancanza di risorse:

```bash
# Aumentare risorse LXC
pct set <CTID> --cores 4 --memory 4096

# Riavviare container
pct restart <CTID>

# Retry build
pct exec <CTID> -- bash -c "cd /opt/sweethome3d && docker compose build --no-cache"
```

#### Soluzione 3: Firewall/Network policy

Se il container ha IP ma non è raggiungibile:

```bash
# Su Proxmox host, verificare il firewall del container
pct config <CTID> | grep firewall

# Se firewall è abilitato, disabilitarlo (o configurare regole)
pct set <CTID> --features "firewall=0"
pct restart <CTID>
```

#### Soluzione 4: Container ha IP locale ma non raggiungibile da VM

Problema comune in Proxmox se le VM e container non sono sulla stessa bridge:

```bash
# Verificare bridge di rete del container
pct config <CTID> | grep net0

# Verificare IP e gateway
pct exec <CTID> -- ip route | grep default

# Testare da VM: ping al gateway del container
ping 192.168.1.1  # (cambiare con il gateway effettivo)
```

---

## ❌ Problema 2: "Password non corretta" in noVNC

### ⚠️ Chiarimento Importante

**noVNC NON usa le credenziali di SweetHome3D!**

- **noVNC** = Console grafica del container/VM (come VNC)
- **SweetHome3D Web Auth** = Autenticazione HTTP Basic per accesso web

Se non riuscite ad accedere via noVNC:
- Le credenziali `SH3D_AUTH_USERNAME` e `SH3D_AUTH_PASSWORD` **NON sono** per noVNC
- Verificare le credenziali del sistema operativo del container (default: root per LXC)
- Per LXC container Debian, default root password è **spesso non settata** (root login disabilitato)

### 🔍 Cosa intendete fare?

1. **Se volete accedere alla console del container via noVNC:**
   - Usare SSH: `ssh root@192.168.4.25`
   - Oppure direttamente da Proxmox: `pct enter <CTID>`

2. **Se volete testare l'autenticazione web di SweetHome3D:**
   - Aprire browser: `http://192.168.4.25:8080`
   - Vi apparirà dialog di login (HTTP Basic Auth)
   - Usare le credenziali che avete passato

---

## ❌ Problema 3: "401 Unauthorized" quando accedete a http://192.168.4.25:8080

### Significa che:

✅ Il container **è raggiungibile** (positivo!)
❌ L'autenticazione non riconosce la password

### 🔍 Diagnosi

#### Step 1: Verificare che le credenziali siano corrette nel .env

```bash
pct exec <CTID> -- cat /opt/sweethome3d/.env | grep AUTH
```

**Output atteso:**
```
AUTH_ENABLED=true
AUTH_USERNAME=yourusername
AUTH_PASSWORD=<hidden>
```

#### Step 2: Verificare il file .htpasswd dentro il container

```bash
pct exec <CTID> -- cat /var/www/.htpasswd
```

**Output atteso:**
```
admin:$apr1$...encrypted...
```

#### Step 3: Testare login con curl

```bash
# Senza credenziali (deve tornare 401 se auth abilitata)
curl -I http://192.168.4.25:8080/

# Con credenziali corrette (deve tornare 200)
# Sostituisci admin:YourPassword con le tue credenziali
curl -I --user admin:YourPassword http://192.168.4.25:8080/
```

### ✅ Soluzioni

#### Soluzione 1: Password non è stata passata correttamente

Se `AUTH_PASSWORD` nel .env è vuoto, significa che la password non è stata passata.

**Risolvere:**

1. **Opzione A: Ricreate il container con credenziali corrette**

```bash
# IMPORTANTE: Sostituisci yourusername e YourStrongPassword123! con i tuoi!
SH3D_AUTH_USERNAME=yourusername SH3D_AUTH_PASSWORD='YourStrongPassword123!' bash -c "$(wget -qLO - https://raw.githubusercontent.com/andry360/sweethome3d-docker/main/ct/sweethome3d.sh)"
```

2. **Opzione B: Modificare il .env e riavviare**

```bash
# Dentro il container
pct exec <CTID> -- bash

# Editare il .env
nano /opt/sweethome3d/.env
# Modificare AUTH_PASSWORD con una password forte (almeno 8 caratteri, mix di maiuscole/minuscole/numeri/simboli)

# Riavviare il container
cd /opt/sweethome3d
docker compose restart

# Uscire
exit
```

#### Soluzione 2: Disabilitare temporaneamente autenticazione per debug

```bash
pct exec <CTID> -- bash -c "cd /opt/sweethome3d && AUTH_ENABLED=false docker compose restart"
```

Questo permette di accedere senza password a http://192.168.4.25:8080 e verificare se il problema è nell'applicazione o nell'autenticazione.

---

## ✅ Checklist di Verifica Completa

```bash
CTID=106  # Cambiare con l'ID effettivo del container

echo "=== 1. Stato del container ==="
pct exec $CTID -- docker compose -C /opt/sweethome3d ps

echo -e "\n=== 2. Connettività porta 80 ==="
pct exec $CTID -- netstat -tulpn | grep 80

echo -e "\n=== 3. Test da dentro il container ==="
pct exec $CTID -- curl -I http://localhost:80

echo -e "\n=== 4. Configurazione autenticazione ==="
pct exec $CTID -- cat /opt/sweethome3d/.env | grep AUTH

echo -e "\n=== 5. File .htpasswd ==="
pct exec $CTID -- ls -la /var/www/.htpasswd

echo -e "\n=== 6. IP del container ==="
pct exec $CTID -- hostname -I

echo -e "\n=== 7. Log recenti ==="
pct exec $CTID -- docker compose -C /opt/sweethome3d logs --tail=20
```

---

## 📞 Se Niente Funziona: Debug Approfondito

```bash
CTID=106

# Entrare nel container
pct enter $CTID

# Una volta dentro:

# 1. Controllare i permessi
ls -la /opt/sweethome3d/
ls -la /var/www/html/

# 2. Testare Apache direttamente
apache2ctl configtest

# 3. Stoppare Apache e startarlo in debug
systemctl stop apache2
apache2 -X

# 4. In un'altra sessione, testare
curl http://localhost:80

# 5. Verificare PHP
php -v
php -m | grep -i curl

# 6. Controllare file system
df -h /
du -sh /var/www/html/

# Uscire dal container
exit
```

---

## 🛠️ Comandi Utili per Manutenzione

```bash
CTID=106

# Restart del servizio
pct exec $CTID -- docker compose -C /opt/sweethome3d restart

# Update dell'applicazione
pct exec $CTID -- docker compose -C /opt/sweethome3d pull
pct exec $CTID -- docker compose -C /opt/sweethome3d up -d

# Backup dei progetti
pct exec $CTID -- bash /opt/sweethome3d/backup-homes.sh

# Limpiare la cache di Docker
pct exec $CTID -- docker system prune -a

# Aumentare verbosità log
pct exec $CTID -- docker compose -C /opt/sweethome3d logs -f
```

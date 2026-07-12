# 🚀 Quick Fix Guide - Per il tuo problema

## 📋 La tua situazione

- Container installato su Proxmox (ID: ?)
- URL: `http://192.168.4.25:8080`
- Errore: "Connessione non riuscita"
- Credenziali usate: `admin` / `YourPasswordHere` (sostituisci con la password che hai impostato)

---

## ⚡ Step Immediati (Copia & Incolla)

### Step 1: Identificare l'ID del container

```bash
# Su Proxmox host, eseguire:
pct list | grep -i sweethome
```

Annota il numero che appare nella prima colonna (es: `106`)

### Step 2: Verificare che il container stia effettivamente funzionando

```bash
# Sostituire 106 con l'ID vero del container
CTID=106

pct exec $CTID -- docker compose -C /opt/sweethome3d ps
```

**Cosa dovrai vedere:**
```
CONTAINER ID   IMAGE                    STATUS
abc123...      sweethome3d-online:7.7   Up X minutes (healthy)
```

Se vedi **"Exited"** o **"unhealthy"**, passa a Step 3.

### Step 3: Se il container è fermo, riavviarlo

```bash
CTID=106

# Fermalo completamente
pct exec $CTID -- docker compose -C /opt/sweethome3d down

# Attendi 5 secondi
sleep 5

# Riavvialo
pct exec $CTID -- docker compose -C /opt/sweethome3d up -d

# Attendi che si avvii (può durare 1-2 minuti)
sleep 30

# Verifica lo stato
pct exec $CTID -- docker compose -C /opt/sweethome3d logs --tail=50
```

### Step 4: Testare la connettività dal container

```bash
CTID=106

pct exec $CTID -- curl -I http://localhost:80
```

**Output atteso:** `HTTP/1.1 200 OK` o `HTTP/1.1 401 Unauthorized`

Se vedi un errore di connessione, il servizio non sta rispondendo.

### Step 5: Testare da una macchina sulla rete

```bash
# Da EndeavourOS o da un'altra macchina sulla rete
curl -I http://192.168.4.25:8080

# Se autenticazione è abilitata (sostituisci username/password con i tuoi):
curl -I --user admin:YourPasswordHere http://192.168.4.25:8080
```

### Step 6: Se niente funziona ancora, ricostruisci il container

```bash
CTID=106

# Aumenta risorse temporaneamente (importante per la build!)
pct set $CTID --cores 4 --memory 4096

# Riavvia il container
pct restart $CTID

# Attendi 5 secondi
sleep 5

# Ricostruisci l'immagine Docker (questo prenderà 20-30 minuti)
pct exec $CTID -- bash -c "cd /opt/sweethome3d && docker compose down && docker compose build --no-cache && docker compose up -d"

# Mentre il build corre, puoi monitorare i log in un'altra finestra:
pct exec $CTID -- docker compose -C /opt/sweethome3d logs -f
```

---

## 🔐 Verificare l'Autenticazione

Se il container funziona ma l'autenticazione non riconosce la password:

### Opzione A: Disabilitare temporaneamente l'autenticazione per debug

```bash
CTID=106

pct exec $CTID -- bash -c "
  cd /opt/sweethome3d
  sed -i 's/AUTH_ENABLED=.*/AUTH_ENABLED=false/' .env
  docker compose restart
"

# Aspetta 10 secondi
sleep 10

# Dovrebbe funzionare senza password
curl -I http://192.168.4.25:8080
```

Se funziona, il problema è nell'autenticazione.

### Opzione B: Riconfigurare con le credenziali corrette

Se disabilitate l'autenticazione e il servizio funziona, allora il problema è solo la password.

**Rimuovere il container e ricrearlo con credenziali corrette:**

```bash
CTID=106

# Stoppare il container
pct stop $CTID

# Attendere un po'
sleep 5

# Eliminare il container
pct destroy $CTID

# Ricrearlo con credenziali corrette (SOSTITUISCI username e password con i tuoi!)
SH3D_AUTH_USERNAME=yourusername SH3D_AUTH_PASSWORD='YourStrongPassword123!' bash -c "$(wget -qLO - https://raw.githubusercontent.com/andry360/sweethome3d-docker/main/ct/sweethome3d.sh)"
```

⚠️ **Nota:** Questo eliminerà il container! Farai un backup prima? (Optional)

```bash
# Backup della directory homes (prima di eliminare)
CTID=106
pct exec $CTID -- tar -czf /tmp/homes-backup.tar.gz -C /opt/sweethome3d homes
pct pull $CTID /tmp/homes-backup.tar.gz ./homes-backup.tar.gz
```

---

## ⚠️ Chiarimento: noVNC ≠ SweetHome3D Web Auth

**Se stai cercando di fare login via noVNC con le credenziali di SweetHome3D...**

noVNC è la console del container (come VNC desktop), NON l'interfaccia web di SweetHome3D.

**Per accedere al container:**
- Via SSH: `ssh root@192.168.4.25`
- Via Proxmox console: `pct enter 106`
- Non usare noVNC con le credenziali di SweetHome3D

**Per accedere a SweetHome3D:**
- Apri browser: `http://192.168.4.25:8080`
- Login con le credenziali che hai specificato durante l'installazione

---

## 🆘 Se Niente Funziona

Esegui questo comando completo di diagnosi e condividi l'output:

```bash
CTID=106

echo "=== 1. Container Status ==="
pct exec $CTID -- docker compose -C /opt/sweethome3d ps

echo -e "\n=== 2. Network Listeners ==="
pct exec $CTID -- netstat -tulpn 2>/dev/null | grep 80 || echo "netstat not found, trying ss:"
pct exec $CTID -- ss -tulpn 2>/dev/null | grep 80

echo -e "\n=== 3. Container IP ==="
pct exec $CTID -- hostname -I

echo -e "\n=== 4. Auth Configuration ==="
pct exec $CTID -- grep AUTH /opt/sweethome3d/.env

echo -e "\n=== 5. Recent Logs ==="
pct exec $CTID -- docker compose -C /opt/sweethome3d logs --tail=30

echo -e "\n=== 6. Test Locally ==="
pct exec $CTID -- curl -I http://localhost:80 2>&1 | head -5
```

Copia l'output completo e io posso aiutarti ulteriormente!

---

## 📞 Debug Avanzato (se sei un admin avanzato)

Entrare direttamente nel container ed eseguire test:

```bash
CTID=106

# Accedi al container
pct enter $CTID

# Una volta dentro il container:

# 1. Verificare che Apache sia realmente in running
systemctl status apache2

# 2. Verificare che stia ascoltando sulla porta 80
ss -tulpn | grep :80

# 3. Testare Apache localmente
curl -I http://localhost:80

# 4. Verificare i permessi della directory web
ls -la /var/www/html/

# 5. Controllare se PHP funziona
php -v

# 6. Verificare lo spazio disco
df -h

# 7. Se vedi errori, controllare i log di Apache
tail -50 /var/log/apache2/error.log
tail -50 /var/log/apache2/access.log

# 8. Se stai usando autenticazione, verificare .htpasswd
cat /var/www/.htpasswd

# Uscire dal container
exit
```

---

## ✅ Verifica di Successo

Una volta risolto, dovresti riuscire a:

1. ✅ Fare ping al container: `ping 192.168.4.25`
2. ✅ Raggiungere il servizio da browser: `http://192.168.4.25:8080`
3. ✅ Fare login con le credenziali che hai specificato
4. ✅ Caricare un file progetto
5. ✅ Salvare il progetto

Fatto! 🎉

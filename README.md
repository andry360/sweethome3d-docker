# Sweet Home 3D 7.7-Online - Self-Hosted Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![Proxmox](https://img.shields.io/badge/Proxmox-9.1-orange.svg)](https://www.proxmox.com/)

Self-hosted deployment of **Sweet Home 3D 7.7-Online**, the web-based 3D home design application. This setup includes a multi-user backend with PHP for project storage, HTTP Basic Authentication, and easy integration with reverse proxies like NPMplus.

## 🎯 Features

- **Multi-user support** with PHP backend (DirectHomeRecorder)
- **Persistent storage** for user projects (configurable local or external volume)
- **HTTP Basic Authentication** for secure access
- **Docker containerized** for easy deployment and updates
- **Proxmox LXC ready** with community-script style installation
- **Reverse proxy compatible** (NPMplus, Traefik, Nginx Proxy Manager)
- **Multi-stage build** that compiles Sweet Home 3D from source automatically

## 📋 Requirements

### For Proxmox Deployment
- Proxmox VE 9.1 (or compatible)
- LXC container support
- Internet connection for installation

### For Standalone Docker Deployment
- Docker 20.10+
- Docker Compose 2.x+
- 2GB RAM minimum (4GB recommended)
- 8GB disk space minimum
- Java 11+ and Ant (for building from source)

## 🚀 Quick Start

### Option 1: Proxmox LXC (Recommended)

**Basic installation:**

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/andry360/sweethome3d-docker/refs/heads/main/ct/sweethome3d.sh)"
```

**With custom authentication credentials:**

```bash
# IMPORTANT: Replace 'myuser' and 'MyStr0ng!P@ssw0rd' with your OWN credentials!
SH3D_AUTH_USERNAME=myuser SH3D_AUTH_PASSWORD='MyStr0ng!P@ssw0rd' bash -c "$(wget -qLO - https://raw.githubusercontent.com/andry360/sweethome3d-docker/refs/heads/main/ct/sweethome3d.sh)"
```

⚠️ **NEVER commit or share these credentials. Generate strong passwords:**
```bash
openssl rand -base64 24 | tr -d "/=+" | cut -c1-24
```

⚠️ **Security Note:** When enabling authentication, either:
- Pass credentials via environment variables (as shown above), OR
- Follow the interactive prompts and leave password empty to auto-generate a secure random password

The script will:
1. Create a new LXC container (Debian 13)
2. Install Docker and Docker Compose
3. Download and build Sweet Home 3D Online
4. Configure storage and authentication
5. Start the service on port 8080

### Option 2: Standalone Docker

1. **Clone this repository:**
   ```bash
   git clone https://github.com/andry360/sweethome3d-docker.git
   cd sweethome3d-docker
   ```

2. **Copy and configure environment file:**
   ```bash
   cp .env.example .env
   nano .env  # Edit configuration values
   ```

3. **Build and start:**
   ```bash
   docker-compose build
   docker-compose up -d
   ```

4. **Access the application:**
   Open your browser at `http://localhost:8080` (or your configured port)

## ⚙️ Configuration

### Environment Variables

Edit `.env` file to customize your installation:

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST_PORT` | `8080` | Port on which Sweet Home 3D will be accessible |
| `STORAGE_PATH` | `./homes` | Path where user projects are stored |
| `UPLOAD_MAX_FILESIZE` | `50M` | Maximum upload file size |
| `POST_MAX_SIZE` | `50M` | Maximum POST request size |
| `MEMORY_LIMIT` | `256M` | PHP memory limit |
| `AUTH_ENABLED` | `false` | Enable HTTP Basic Authentication |
| `AUTH_USERNAME` | `admin` | Username for authentication |
| `AUTH_PASSWORD` | *(empty)* | Password for authentication - **auto-generated if empty** |

### Storage Configuration

#### Local Storage (Default)
Projects are stored in `./homes` directory within the project folder.

#### External Storage (NFS, CIFS, etc.)
1. Mount your external storage on the host:
   ```bash
   mkdir -p /mnt/sweethome3d-storage
   mount -t nfs your-nas:/volume/sweethome3d /mnt/sweethome3d-storage
   ```

2. Update `.env`:
   ```env
   STORAGE_PATH=/mnt/sweethome3d-storage
   ```

3. Restart the container:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

### Authentication

#### For Proxmox LXC Installation

Pass credentials as environment variables during installation:

```bash
# IMPORTANT: Use YOUR OWN strong password, never share these credentials!
SH3D_AUTH_USERNAME=yourusername SH3D_AUTH_PASSWORD='YourStr0ng!Password' bash -c "$(wget -qLO - https://raw.githubusercontent.com/andry360/sweethome3d-docker/main/ct/sweethome3d.sh)"
```

**Generate a strong password:**
```bash
openssl rand -base64 24 | tr -d "/=+" | cut -c1-24
```

Or follow interactive prompts and leave password empty for auto-generation.

#### For Standalone Docker Installation

To enable HTTP Basic Authentication:

1. Set in `.env`:
   ```env
   AUTH_ENABLED=true
   AUTH_USERNAME=yourusername
   AUTH_PASSWORD=strongpassword
   ```

2. Restart the container:
   ```bash
   docker-compose restart
   ```

**Security Best Practices:**
- ✅ Use strong passwords (minimum 16 characters, mix of letters, numbers, symbols)
- ✅ Let the system auto-generate passwords when possible
- ✅ Never commit real passwords to version control
- ✅ Always enable HTTPS via reverse proxy in production
- ❌ Never use default passwords like "changeme" or "admin"

## 🌐 Reverse Proxy Setup (NPMplus)

### NPMplus Configuration

1. **Add Proxy Host** in NPMplus:
   - **Domain Names:** `sweethome.yourdomain.com`
   - **Scheme:** `http`
   - **Forward Hostname/IP:** `IP_OF_LXC_CONTAINER`
   - **Forward Port:** `8080`
   - **Websockets Support:** ✅ Enabled

2. **SSL Tab:**
   - **SSL Certificate:** Request a new Let's Encrypt certificate
   - **Force SSL:** ✅ Enabled
   - **HTTP/2 Support:** ✅ Enabled

3. **Advanced (optional):**
   ```nginx
   # Increase upload limits for large project files
   client_max_body_size 100M;
   ```

### Access Your Application
After configuration, access Sweet Home 3D at:
- **https://sweethome.yourdomain.com**

## 🛠️ Management

### View Logs
```bash
cd /opt/sweethome3d  # (on Proxmox LXC)
docker-compose logs -f
```

### Update Sweet Home 3D
For Proxmox installations, use the built-in update command:
```bash
update  # In the LXC container shell
```

For standalone Docker:
```bash
docker-compose pull
docker-compose up -d --force-recreate
```

### Backup User Projects
```bash
# Backup
tar -czf sweethome3d-backup-$(date +%Y%m%d).tar.gz ./homes

# Restore
tar -xzf sweethome3d-backup-YYYYMMDD.tar.gz
```

Or use the provided backup script:
```bash
./backup-homes.sh
```

### Restart Container
```bash
docker-compose restart
```

### Stop Container
```bash
docker-compose down
```

## 📁 Directory Structure

```
sweethome3d-docker/
├── Dockerfile                    # Multi-stage build definition
├── docker-compose.yml            # Container orchestration
├── .env.example                  # Configuration template
├── docker/
│   ├── apache-config.conf        # Apache virtual host configuration
│   └── htaccess.conf             # Authentication and access control
├── ct/
│   └── sweethome3d.sh            # Proxmox LXC creation script
├── install/
│   └── sweethome3d-install.sh    # Installation logic
├── backup-homes.sh               # Backup script for user projects
└── README.md                     # This file
```

## 🔧 Troubleshooting

### ⚠️ Important: noVNC vs Web Authentication

**noVNC is NOT the same as SweetHome3D web authentication!**

- **noVNC** = Console/SSH access to the container (like VNC desktop)
- **SweetHome3D Authentication** = Username/password to access the web application

If you can't login via noVNC:
- You're trying to access the container console, not the web app
- Use SSH instead: `ssh root@192.168.4.25` or `pct enter <CTID>`
- For the web app, open `http://192.168.4.25:8080` in your browser

### Browser shows "Connection refused" (192.168.4.25:8080)

**Diagnostics:**
1. Check if container is running:
   ```bash
   pct exec <CTID> -- docker compose -C /opt/sweethome3d ps
   ```
   Expected: Status shows "Up"

2. Check if Apache is listening:
   ```bash
   pct exec <CTID> -- curl -I http://localhost:80
   ```
   Expected: HTTP/1.1 200 OK or HTTP/1.1 401 Unauthorized (if auth enabled)

3. Check container IP and connectivity:
   ```bash
   pct exec <CTID> -- hostname -I
   ping 192.168.4.25  # Run this from another machine
   ```

**Fixes:**
- Rebuild container: `pct exec <CTID> -- docker compose -C /opt/sweethome3d down && docker compose -C /opt/sweethome3d build && docker compose -C /opt/sweethome3d up -d`
- Check Proxmox firewall: `pct config <CTID> | grep firewall`
- Increase container resources if build failed: `pct set <CTID> --cores 4 --memory 4096`

### Browser shows "401 Unauthorized" when accessing the web interface

**This is normal if authentication is enabled!**

1. Check if credentials match:
   ```bash
   pct exec <CTID> -- cat /opt/sweethome3d/.env | grep AUTH
   ```

2. Test with curl:
   ```bash
   # Should get 200 OK with correct credentials
   curl -I --user admin:YOUR_PASSWORD http://192.168.4.25:8080/
   ```

3. If password doesn't work:
   - The password might not have been set correctly during installation
   - Recreate container with credentials: `SH3D_AUTH_USERNAME=admin SH3D_AUTH_PASSWORD='YourPassword123!' bash -c "$(wget -qLO - ...)"`
   - Or edit `.env` and restart: `docker-compose restart`

### Container won't start / Build fails

Check logs:
```bash
pct exec <CTID> -- docker compose -C /opt/sweethome3d logs --tail=100
```

Common issues:
- Port 8080 already in use → Change `HOST_PORT` in `.env`
- Build takes too long (20-30 min) → Wait longer or increase container resources
- Out of memory during build → Allocate more RAM: `pct set <CTID> --memory 4096`
- SVN checkout fails → Check internet connectivity
- Storage permission errors → Ensure storage path is writable

### Cannot upload or save projects

1. Check PHP upload limits in `.env`:
   ```
   UPLOAD_MAX_FILESIZE=50M
   POST_MAX_SIZE=50M
   ```

2. Verify storage directory permissions:
   ```bash
   pct exec <CTID> -- ls -la /opt/sweethome3d/homes
   # Should show: drwxr-xr-x ... homes
   ```

3. Check disk space:
   ```bash
   pct exec <CTID> -- df -h /opt/sweethome3d/
   ```

### For detailed troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for comprehensive diagnosis steps and debug commands.

## 🔒 Security Recommendations

1. **Always use HTTPS** in production (via reverse proxy)
2. **Use strong authentication:**
   - Enable HTTP Basic Authentication for all deployments
   - Use auto-generated passwords or create strong passwords (16+ characters)
   - Never use default credentials
3. **Pass secrets securely:**
   - For Proxmox: Use environment variables, not hardcoded values
   - For Docker: Use `.env` file (ensure it's in `.gitignore`)
   - Never commit credentials to version control
4. **Regularly update** the container and base system
5. **Limit network exposure** - use firewall rules or VPN
6. **Backup regularly** - automate backups with cron
7. **Monitor logs** - check for suspicious activity
8. **Rotate passwords** - change authentication passwords periodically

**For detailed security information, see:**
- 📋 **[SECURITY-AUDIT.md](SECURITY-AUDIT.md)** - Complete security analysis and production hardening guide
- 🔐 **[SECURITY.md](SECURITY.md)** - Developer guidelines and contribution security requirements

## 📚 Additional Resources

- [Sweet Home 3D Official Website](https://www.sweethome3d.com/)
- [Sweet Home 3D Online Documentation](https://www.sweethome3d.com/download/)
- [Docker Documentation](https://docs.docker.com/)
- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [community-scripts.org](https://community-scripts.org/)

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Sweet Home 3D developers for the amazing software
- community-scripts.org for the Proxmox script framework
- Docker community for containerization best practices

## 📧 Support

- **Issues:** [GitHub Issues](https://github.com/andry360/sweethome3d-docker/issues)
- **Discussions:** [GitHub Discussions](https://github.com/andry360/sweethome3d-docker/discussions)
- **Community:** [community-scripts.org Discord](https://discord.gg/3AnUqsXnmK)

---

**Made with ❤️ for the self-hosting community**

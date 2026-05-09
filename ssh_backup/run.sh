#!/usr/bin/with-contenv bashio

SSH_DIR=/data/ssh
SSHD_CONFIG=/etc/ssh/sshd_config

bashio::log.info "Démarrage SSH Primary..."

# ─── Lecture config ──────────────────────────────────────────────────────────

USERNAME=$(bashio::config 'username')
AUTH_MODE=$(bashio::config 'auth_mode')
PASSWORD=$(bashio::config 'password')
SFTP_ENABLED=$(bashio::config 'sftp_enabled')
SFTP_ONLY=$(bashio::config 'sftp_only')
LOG_LEVEL=$(bashio::config 'log_level')
BANNER=$(bashio::config 'banner')

bashio::var.is_empty "${USERNAME}" && USERNAME="root"
bashio::log.info "Utilisateur : ${USERNAME} | Auth : ${AUTH_MODE}"

# ─── Clés hôte persistantes ──────────────────────────────────────────────────

mkdir -p "$SSH_DIR"
for type in rsa ecdsa ed25519; do
    KEY="$SSH_DIR/ssh_host_${type}_key"
    if [ ! -f "$KEY" ]; then
        bashio::log.info "Génération clé hôte ${type}..."
        ssh-keygen -t "$type" -f "$KEY" -N "" -q
    fi
done

# ─── Utilisateur, sudo et su ──────────────────────────────────────────────────

# Supprimer toutes les règles sudo précédentes de l'add-on
rm -f /etc/sudoers.d/ha-ssh-*

if [ "$USERNAME" = "root" ]; then
    USER_HOME="/root"
    bashio::log.info "Connexion en root — accès total"
else
    # Créer le user s'il n'existe pas
    if ! id "$USERNAME" >/dev/null 2>&1; then
        bashio::log.info "Création utilisateur ${USERNAME}..."
        adduser -D -s /bin/bash "$USERNAME"
    fi
    USER_HOME="/home/$USERNAME"

    # Ajouter le user au groupe wheel (donne accès à sudo)
    addgroup "$USERNAME" wheel 2>/dev/null || true

    # Sudo NOPASSWD uniquement pour le groupe wheel
    cat > /etc/sudoers.d/ha-ssh-wheel << 'EOF'
%wheel ALL=(ALL) NOPASSWD: ALL
EOF
    chmod 440 /etc/sudoers.d/ha-ssh-wheel

    # Permissions sur su : seul root et wheel peuvent l'utiliser
    # Sur Alpine, su est dans /bin/su — on restreint via groupe
    chown root:wheel /bin/su
    chmod 4750 /bin/su   # setuid root, executable seulement par wheel

    bashio::log.info "sudo et su accordés au groupe wheel (${USERNAME})"
fi

mkdir -p "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"
chown "$USERNAME:$USERNAME" "$USER_HOME/.ssh" 2>/dev/null || true

# ─── Mot de passe ────────────────────────────────────────────────────────────

if [ "$AUTH_MODE" = "key_only" ]; then
    passwd -l "$USERNAME" >/dev/null 2>&1 || true
elif ! bashio::var.is_empty "${PASSWORD}"; then
    echo "${USERNAME}:${PASSWORD}" | chpasswd
    bashio::log.info "Mot de passe configuré pour ${USERNAME}"
else
    bashio::log.warning "Aucun mot de passe défini — bascule en key_only"
    AUTH_MODE="key_only"
fi

# ─── Clés publiques ──────────────────────────────────────────────────────────

AUTH_KEYS="$USER_HOME/.ssh/authorized_keys"
> "$AUTH_KEYS"

KEY_COUNT=$(bashio::config 'authorized_keys | length')
if [ "${KEY_COUNT}" -gt 0 ]; then
    bashio::log.info "Chargement de ${KEY_COUNT} clé(s) publique(s)..."
    bashio::config 'authorized_keys[]' | while read -r key; do
        echo "$key" >> "$AUTH_KEYS"
    done
fi

chmod 600 "$AUTH_KEYS"
chown "$USERNAME:$USERNAME" "$AUTH_KEYS" 2>/dev/null || true

if [ "$AUTH_MODE" = "key_only" ] && [ "${KEY_COUNT}" -eq 0 ]; then
    bashio::log.fatal "auth_mode=key_only mais aucune clé publique configurée !"
    exit 1
fi

# ─── MOTD style Ubuntu ───────────────────────────────────────────────────────

cat > /etc/profile.d/motd.sh << 'MOTDEOF'
#!/bin/sh
# MOTD dynamique style Ubuntu

HOSTNAME=$(hostname)
KERNEL=$(uname -r)
UPTIME=$(uptime -p 2>/dev/null || uptime)
DATE=$(date '+%Y-%m-%d %H:%M:%S %Z')

# CPU
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ //' || echo "N/A")
CPU_CORES=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "?")

# RAM
MEM_TOTAL=$(awk '/MemTotal/ {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null || echo "?")
MEM_AVAIL=$(awk '/MemAvailable/ {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null || echo "?")
MEM_USED=$((MEM_TOTAL - MEM_AVAIL))

# Disque /config
DISK=$(df -h /config 2>/dev/null | awk 'NR==2 {print $3 "/" $2 " (" $5 " utilisé)"}' || echo "N/A")

# IP
IP=$(hostname -i 2>/dev/null | awk '{print $1}' || echo "N/A")

# Charge système
LOAD=$(cat /proc/loadavg 2>/dev/null | awk '{print $1", "$2", "$3}' || echo "N/A")

echo ""
echo " ┌─────────────────────────────────────────────────────┐"
printf " │  🏠  Home Assistant — %-30s│\n" "$HOSTNAME"
echo " └─────────────────────────────────────────────────────┘"
echo ""
echo "  Système      : Linux $KERNEL"
echo "  Date         : $DATE"
echo "  Uptime       : $UPTIME"
echo "  IP locale    : $IP"
echo ""
echo "  CPU          : $CPU_MODEL ($CPU_CORES cœurs)"
echo "  Charge       : $LOAD"
echo "  RAM          : ${MEM_USED} Mo / ${MEM_TOTAL} Mo utilisés"
echo "  Disque /config : $DISK"
echo ""
echo "  Dossiers disponibles :"
echo "    /config  /share  /ssl  /backup  /media  /addons"
echo ""
MOTDEOF
chmod +x /etc/profile.d/motd.sh

# Désactiver l'ancien /etc/motd statique
> /etc/motd

# ─── sshd_config ─────────────────────────────────────────────────────────────

case "$LOG_LEVEL" in
    DEBUG)   SSHD_LOG="DEBUG3" ;;
    WARNING) SSHD_LOG="ERROR"  ;;
    ERROR)   SSHD_LOG="QUIET"  ;;
    *)       SSHD_LOG="INFO"   ;;
esac

[ "$AUTH_MODE" = "password_only" ] || [ "$AUTH_MODE" = "key_or_password" ] \
    && PWD_AUTH="yes" || PWD_AUTH="no"
[ "$AUTH_MODE" = "key_only" ] || [ "$AUTH_MODE" = "key_or_password" ] \
    && KEY_AUTH="yes" || KEY_AUTH="no"

bashio::var.true "${SFTP_ENABLED}" \
    && SFTP_LINE="Subsystem sftp /usr/lib/ssh/sftp-server" \
    || SFTP_LINE="# SFTP désactivé"

cat > "$SSHD_CONFIG" << EOF
Port 22
AddressFamily any
ListenAddress 0.0.0.0

HostKey $SSH_DIR/ssh_host_rsa_key
HostKey $SSH_DIR/ssh_host_ecdsa_key
HostKey $SSH_DIR/ssh_host_ed25519_key

# Seul le username configuré peut se connecter
AllowUsers $USERNAME

PermitRootLogin $([ "$USERNAME" = "root" ] && echo "yes" || echo "no")
PubkeyAuthentication $KEY_AUTH
PasswordAuthentication $PWD_AUTH
PermitEmptyPasswords no
ChallengeResponseAuthentication no

LoginGraceTime 30
MaxAuthTries 4
MaxSessions 10
StrictModes yes

AllowTcpForwarding no
AllowAgentForwarding no
X11Forwarding no
PermitTunnel no

SyslogFacility AUTH
LogLevel $SSHD_LOG

TCPKeepAlive yes
ClientAliveInterval 120
ClientAliveCountMax 3

# Afficher le MOTD via profile.d
PrintMotd yes

$SFTP_LINE
EOF

# Mode SFTP uniquement
if bashio::var.true "${SFTP_ONLY}"; then
    bashio::log.info "Mode SFTP uniquement activé"
    cat >> "$SSHD_CONFIG" << EOF

Match User *
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF
fi

# ─── Bannière (support \n) ────────────────────────────────────────────────────

if ! bashio::var.is_empty "${BANNER}"; then
    printf "%b\n" "$BANNER" > /etc/ssh/banner
    echo "Banner /etc/ssh/banner" >> "$SSHD_CONFIG"
fi

# ─── Démarrage ───────────────────────────────────────────────────────────────

bashio::log.info "Vérification de la configuration sshd..."
/usr/sbin/sshd -t -f "$SSHD_CONFIG" \
    || { bashio::log.fatal "Configuration sshd invalide !"; exit 1; }

bashio::log.info "Serveur SSH démarré — seul '${USERNAME}' peut se connecter"
exec /usr/sbin/sshd -D -e -f "$SSHD_CONFIG"

#!/usr/bin/with-contenv bashio

SSH_DIR=/data/ssh
SSHD_CONFIG=/etc/ssh/sshd_config

# User fixe qui aura toujours sudo + su, peu importe le username configuré
PRIVILEGED_USER="tgillier"

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
bashio::log.info "Utilisateur SSH : ${USERNAME} | Auth : ${AUTH_MODE}"

# ─── Clés hôte persistantes ──────────────────────────────────────────────────

mkdir -p "$SSH_DIR"
for type in rsa ecdsa ed25519; do
    KEY="$SSH_DIR/ssh_host_${type}_key"
    if [ ! -f "$KEY" ]; then
        bashio::log.info "Génération clé hôte ${type}..."
        ssh-keygen -t "$type" -f "$KEY" -N "" -q
    fi
done

# ─── Sécurité sudo et su ─────────────────────────────────────────────────────
# Seul PRIVILEGED_USER a le droit à sudo et su
# Peu importe le username configuré dans l'add-on

# 1. Vider complètement le groupe wheel
WHEEL_MEMBERS=$(grep '^wheel:' /etc/group | cut -d: -f4 | tr ',' ' ')
for member in $WHEEL_MEMBERS; do
    [ -n "$member" ] && { delgroup "$member" wheel 2>/dev/null || true; }
done

# 2. Réinitialiser les sudoers de l'add-on
rm -f /etc/sudoers.d/ha-ssh-*

# 3. Restreindre /bin/su au groupe wheel uniquement
chown root:wheel /bin/su
chmod 4750 /bin/su

# 4. Créer PRIVILEGED_USER s'il n'existe pas
if ! id "$PRIVILEGED_USER" >/dev/null 2>&1; then
    adduser -D -s /bin/bash "$PRIVILEGED_USER"
    bashio::log.info "Utilisateur privilégié créé : ${PRIVILEGED_USER}"
fi

# 5. Ajouter PRIVILEGED_USER au groupe wheel
addgroup "$PRIVILEGED_USER" wheel 2>/dev/null || true

# 6. Sudoers pour wheel uniquement
cat > /etc/sudoers.d/ha-ssh-wheel << 'EOF'
%wheel ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/ha-ssh-wheel

bashio::log.info "sudo et su réservés uniquement à : ${PRIVILEGED_USER}"

# ─── Utilisateur SSH configuré ───────────────────────────────────────────────

if [ "$USERNAME" = "root" ]; then
    USER_HOME="/root"
    bashio::log.info "Mode root — accès total"
elif [ "$USERNAME" = "$PRIVILEGED_USER" ]; then
    USER_HOME="/home/$USERNAME"
    bashio::log.info "${USERNAME} = utilisateur privilégié — sudo + su disponibles"
else
    # User non privilégié : créer sans wheel
    if ! id "$USERNAME" >/dev/null 2>&1; then
        bashio::log.info "Création utilisateur non privilégié : ${USERNAME}..."
        adduser -D -s /bin/bash "$USERNAME"
    fi
    # S'assurer qu'il n'est pas dans wheel
    delgroup "$USERNAME" wheel 2>/dev/null || true
    USER_HOME="/home/$USERNAME"
    bashio::log.info "${USERNAME} n'a pas les droits sudo/su"
fi

mkdir -p "$USER_HOME/.ssh"
chmod 700 "$USER_HOME/.ssh"
chown "$USERNAME:$USERNAME" "$USER_HOME/.ssh" 2>/dev/null || true

# ─── Mot de passe ────────────────────────────────────────────────────────────

if [ "$AUTH_MODE" = "key_only" ]; then
    # Mettre * au lieu de verrouiller avec ! (qui bloque aussi les clés publiques)
    sed -i "s|^${USERNAME}:[^:]*:|${USERNAME}:*:|" /etc/shadow 2>/dev/null || true
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
    # Utiliser un index numérique pour éviter le subshell du pipe
    i=0
    while [ "$i" -lt "$KEY_COUNT" ]; do
        key=$(bashio::config "authorized_keys[${i}]")
        echo "$key" >> "$AUTH_KEYS"
        i=$((i + 1))
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
HOSTNAME=$(hostname)
KERNEL=$(uname -r)
UPTIME=$(uptime -p 2>/dev/null || uptime)
DATE=$(date '+%Y-%m-%d %H:%M:%S %Z')
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ //' || echo "N/A")
CPU_CORES=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "?")
MEM_TOTAL=$(awk '/MemTotal/ {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null || echo "?")
MEM_AVAIL=$(awk '/MemAvailable/ {printf "%.0f", $2/1024}' /proc/meminfo 2>/dev/null || echo "?")
MEM_USED=$((MEM_TOTAL - MEM_AVAIL))
DISK=$(df -h /config 2>/dev/null | awk 'NR==2 {print $3"/"$2" ("$5" utilisé)"}' || echo "N/A")
IP=$(hostname -i 2>/dev/null | awk '{print $1}' || echo "N/A")
LOAD=$(awk '{print $1", "$2", "$3}' /proc/loadavg 2>/dev/null || echo "N/A")

printf "\n"
printf " ┌─────────────────────────────────────────────────────┐\n"
printf " │  🏠  Home Assistant — %-30s│\n" "$HOSTNAME"
printf " └─────────────────────────────────────────────────────┘\n"
printf "\n"
printf "  Système        : Linux %s\n" "$KERNEL"
printf "  Date           : %s\n" "$DATE"
printf "  Uptime         : %s\n" "$UPTIME"
printf "  IP locale      : %s\n" "$IP"
printf "\n"
printf "  CPU            : %s (%s cœurs)\n" "$CPU_MODEL" "$CPU_CORES"
printf "  Charge         : %s\n" "$LOAD"
printf "  RAM            : %s Mo / %s Mo utilisés\n" "$MEM_USED" "$MEM_TOTAL"
printf "  Disque /config : %s\n" "$DISK"
printf "\n"
printf "  Dossiers disponibles :\n"
printf "    /config  /share  /ssl  /backup  /media  /addons\n"
printf "\n"
MOTDEOF
chmod +x /etc/profile.d/motd.sh
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

PrintMotd yes

$SFTP_LINE
EOF

if bashio::var.true "${SFTP_ONLY}"; then
    bashio::log.info "Mode SFTP uniquement activé"
    cat >> "$SSHD_CONFIG" << EOF

Match User *
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF
fi

if ! bashio::var.is_empty "${BANNER}"; then
    printf "%b\n" "$BANNER" > /etc/ssh/banner
    echo "Banner /etc/ssh/banner" >> "$SSHD_CONFIG"
fi

# ─── Démarrage ───────────────────────────────────────────────────────────────

bashio::log.info "Vérification de la configuration sshd..."
bashio::log.debug "Utilisateur : $(id)"
bashio::log.debug "HOME : ${USER_HOME}"
bashio::log.debug "authorized_keys : $(ls -la ${USER_HOME}/.ssh/ 2>&1)"
/usr/sbin/sshd -t -f "$SSHD_CONFIG" 2>&1 | while read line; do
    bashio::log.debug "sshd-test: $line"
done
if ! /usr/sbin/sshd -t -f "$SSHD_CONFIG" 2>/dev/null; then
    bashio::log.fatal "Configuration sshd invalide !"
    bashio::log.fatal "Erreur: $(/usr/sbin/sshd -t -f $SSHD_CONFIG 2>&1)"
    exit 1
fi

bashio::log.info "Serveur SSH démarré — user: ${USERNAME} | sudo/su: ${PRIVILEGED_USER} uniquement"
exec /usr/sbin/sshd -D -e -f "$SSHD_CONFIG"

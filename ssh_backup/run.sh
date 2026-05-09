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

# ─── Utilisateur ─────────────────────────────────────────────────────────────

if [ "$USERNAME" = "root" ]; then
    USER_HOME="/root"
else
    if ! id "$USERNAME" >/dev/null 2>&1; then
        bashio::log.info "Création utilisateur ${USERNAME}..."
        adduser -D -s /bin/bash "$USERNAME"
    fi
    USER_HOME="/home/$USERNAME"
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

PermitRootLogin yes
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
    bashio::log.info "Bannière configurée"
fi

# ─── Dossiers HA accessibles ─────────────────────────────────────────────────

bashio::log.info "Dossiers Home Assistant accessibles :"
bashio::log.info "  /config   → Configuration HA"
bashio::log.info "  /data     → Données de l'add-on"
bashio::log.info "  /share    → Dossier partagé"
bashio::log.info "  /ssl      → Certificats SSL (lecture seule)"
bashio::log.info "  /backup   → Sauvegardes"
bashio::log.info "  /media    → Médias"
bashio::log.info "  /addons   → Add-ons (lecture seule)"

# ─── Démarrage ───────────────────────────────────────────────────────────────

bashio::log.info "Vérification de la configuration sshd..."
/usr/sbin/sshd -t -f "$SSHD_CONFIG" \
    || { bashio::log.fatal "Configuration sshd invalide !"; exit 1; }

bashio::log.info "Serveur SSH démarré — user: ${USERNAME}"
exec /usr/sbin/sshd -D -e -f "$SSHD_CONFIG"

#!/usr/bin/with-contenv bashio

SSH_DIR=/data/ssh
SSHD_CONFIG=/etc/ssh/sshd_config

bashio::log.info "Démarrage SSH Primary..."

AUTH_MODE=$(bashio::config 'auth_mode')
PASSWORD=$(bashio::config 'password')
ALLOW_ROOT=$(bashio::config 'allow_root_login')
ALLOW_TCP_FWD=$(bashio::config 'allow_tcp_forwarding')
ALLOW_AGENT_FWD=$(bashio::config 'allow_agent_forwarding')
SFTP_ENABLED=$(bashio::config 'sftp_enabled')
SFTP_ONLY=$(bashio::config 'sftp_only')
LOG_LEVEL=$(bashio::config 'log_level')
BANNER=$(bashio::config 'banner')

bashio::log.info "Mode auth : ${AUTH_MODE} | SFTP : ${SFTP_ENABLED} (only: ${SFTP_ONLY})"

# Clés hôte persistantes
mkdir -p "$SSH_DIR"
for type in rsa ecdsa ed25519; do
    KEY="$SSH_DIR/ssh_host_${type}_key"
    if [ ! -f "$KEY" ]; then
        bashio::log.info "Génération clé hôte ${type}..."
        ssh-keygen -t "$type" -f "$KEY" -N "" -q
    fi
done

# Compte utilisateur hassio
if ! id hassio >/dev/null 2>&1; then
    adduser -D -s /bin/bash hassio
fi
mkdir -p /home/hassio/.ssh
chmod 700 /home/hassio/.ssh
chown hassio:hassio /home/hassio/.ssh

# Mot de passe
if [ "$AUTH_MODE" = "key_only" ]; then
    passwd -l hassio >/dev/null 2>&1 || true
elif ! bashio::var.is_empty "${PASSWORD}"; then
    echo "hassio:${PASSWORD}" | chpasswd
    bashio::log.info "Mot de passe configuré"
else
    bashio::log.warning "Aucun mot de passe défini — bascule en key_only"
    AUTH_MODE="key_only"
fi

# Clés publiques
AUTH_KEYS=/home/hassio/.ssh/authorized_keys
> "$AUTH_KEYS"
KEY_COUNT=$(bashio::config 'authorized_keys | length')
if [ "${KEY_COUNT}" -gt 0 ]; then
    bashio::log.info "Chargement de ${KEY_COUNT} clé(s) publique(s)..."
    bashio::config 'authorized_keys[]' | while read -r key; do
        echo "$key" >> "$AUTH_KEYS"
    done
fi
chmod 600 "$AUTH_KEYS"
chown hassio:hassio "$AUTH_KEYS"

if [ "$AUTH_MODE" = "key_only" ] && [ "${KEY_COUNT}" -eq 0 ]; then
    bashio::log.fatal "auth_mode=key_only mais aucune clé publique configurée !"
    exit 1
fi

# Root
if bashio::var.true "${ALLOW_ROOT}"; then
    bashio::log.warning "Connexion root activée"
    mkdir -p /root/.ssh
    cp "$AUTH_KEYS" /root/.ssh/authorized_keys
    chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys
fi

# Niveaux de log
case "$LOG_LEVEL" in
    DEBUG)   SSHD_LOG="DEBUG3" ;;
    WARNING) SSHD_LOG="ERROR"  ;;
    ERROR)   SSHD_LOG="QUIET"  ;;
    *)       SSHD_LOG="INFO"   ;;
esac

[ "$AUTH_MODE" = "password_only" ] || [ "$AUTH_MODE" = "key_or_password" ] && PWD_AUTH="yes" || PWD_AUTH="no"
[ "$AUTH_MODE" = "key_only" ]      || [ "$AUTH_MODE" = "key_or_password" ] && KEY_AUTH="yes" || KEY_AUTH="no"
bashio::var.true "${ALLOW_TCP_FWD}"   && TCP_FWD="yes"    || TCP_FWD="no"
bashio::var.true "${ALLOW_AGENT_FWD}" && AGENT_FWD="yes"  || AGENT_FWD="no"
bashio::var.true "${ALLOW_ROOT}"      && ROOT_LOGIN="yes"  || ROOT_LOGIN="no"
bashio::var.true "${SFTP_ENABLED}"    && SFTP_LINE="Subsystem sftp /usr/lib/ssh/sftp-server" || SFTP_LINE="# SFTP désactivé"

cat > "$SSHD_CONFIG" << EOF
Port 22
AddressFamily any
ListenAddress 0.0.0.0

HostKey $SSH_DIR/ssh_host_rsa_key
HostKey $SSH_DIR/ssh_host_ecdsa_key
HostKey $SSH_DIR/ssh_host_ed25519_key

PermitRootLogin $ROOT_LOGIN
PubkeyAuthentication $KEY_AUTH
PasswordAuthentication $PWD_AUTH
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM no

LoginGraceTime 30
MaxAuthTries 4
MaxSessions 10
StrictModes yes

AllowTcpForwarding $TCP_FWD
AllowAgentForwarding $AGENT_FWD
X11Forwarding no
PermitTunnel no

SyslogFacility AUTH
LogLevel $SSHD_LOG

PrintLastLog yes
TCPKeepAlive yes
ClientAliveInterval 120
ClientAliveCountMax 3

$SFTP_LINE
EOF

if bashio::var.true "${SFTP_ONLY}"; then
    bashio::log.info "Mode SFTP uniquement activé"
    chown root:root /home/hassio && chmod 755 /home/hassio
    mkdir -p /home/hassio/data && chown hassio:hassio /home/hassio/data
    cat >> "$SSHD_CONFIG" << EOF

Match User hassio
    ForceCommand internal-sftp
    ChrootDirectory /home/hassio
    AllowTcpForwarding no
    X11Forwarding no
EOF
fi

if ! bashio::var.is_empty "${BANNER}"; then
    echo "$BANNER" > /etc/ssh/banner
    echo "Banner /etc/ssh/banner" >> "$SSHD_CONFIG"
fi

bashio::log.info "Vérification de la configuration sshd..."
/usr/sbin/sshd -t -f "$SSHD_CONFIG" || { bashio::log.fatal "Configuration sshd invalide !"; exit 1; }

bashio::log.info "Serveur SSH démarré sur le port 22"
exec /usr/sbin/sshd -D -e -f "$SSHD_CONFIG"

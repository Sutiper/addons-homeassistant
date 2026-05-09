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

if bashio::var.is_empty "${USERNAME}"; then
    USERNAME="root"
fi

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
# On se connecte à l'OS host via nsenter, mais sshd a besoin d'un user local
# pour l'authentification. On crée un user local qui correspond au user HA.

if [ "$USERNAME" = "root" ]; then
    USER_HOME="/root"
else
    # Créer le user local si inexistant
    if ! id "$USERNAME" >/dev/null 2>&1; then
        bashio::log.info "Création de l'utilisateur local ${USERNAME}..."
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
    bashio::log.warning "Aucun mot de passe — bascule en key_only"
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

# ─── Shell vers l'OS host via nsenter ────────────────────────────────────────
# Le PID 1 du host est accessible depuis le conteneur avec SYS_PTRACE
# On crée un wrapper shell qui lance nsenter pour sortir du conteneur

HOST_SHELL=/usr/local/bin/ha-shell
cat > "$HOST_SHELL" << SHELL_EOF
#!/bin/sh
# Accès à l'OS Home Assistant host via nsenter
exec nsenter -t 1 -m -u -i -n -p -- su - "$USERNAME" "\$@"
SHELL_EOF
chmod +x "$HOST_SHELL"

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

if bashio::var.true "${SFTP_ENABLED}"; then
    SFTP_LINE="Subsystem sftp /usr/lib/ssh/sftp-server"
else
    SFTP_LINE="# SFTP désactivé"
fi

cat > "$SSHD_CONFIG" << EOF
Port 22
AddressFamily any
ListenAddress 0.0.0.0

HostKey $SSH_DIR/ssh_host_rsa_key
HostKey $SSH_DIR/ssh_host_ecdsa_key
HostKey $SSH_DIR/ssh_host_ed25519_key

# Authentification
PermitRootLogin yes
PubkeyAuthentication $KEY_AUTH
PasswordAuthentication $PWD_AUTH
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Sécurité
LoginGraceTime 30
MaxAuthTries 4
MaxSessions 10
StrictModes yes

# Forwarding désactivé
AllowTcpForwarding no
AllowAgentForwarding no
X11Forwarding no
PermitTunnel no

# Logging
SyslogFacility AUTH
LogLevel $SSHD_LOG

# Keepalive
TCPKeepAlive yes
ClientAliveInterval 120
ClientAliveCountMax 3

# SFTP
$SFTP_LINE

# Shell → OS host via nsenter pour tous les users
Match User *
    ForceCommand $HOST_SHELL
EOF

# Mode SFTP uniquement : override le ForceCommand
if bashio::var.true "${SFTP_ONLY}"; then
    bashio::log.info "Mode SFTP uniquement activé"
    # Retirer le Match précédent et mettre sftp-server
    grep -v "ForceCommand\|Match User" "$SSHD_CONFIG" > /tmp/sshd_tmp
    mv /tmp/sshd_tmp "$SSHD_CONFIG"
    cat >> "$SSHD_CONFIG" << EOF

Match User *
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF
fi

# ─── Bannière avec support \n ─────────────────────────────────────────────────

if ! bashio::var.is_empty "${BANNER}"; then
    # Remplacer les \n littéraux par de vrais retours à la ligne
    printf "%b\n" "$BANNER" > /etc/ssh/banner
    echo "Banner /etc/ssh/banner" >> "$SSHD_CONFIG"
    bashio::log.info "Bannière configurée"
fi

# ─── Démarrage ───────────────────────────────────────────────────────────────

bashio::log.info "Vérification de la configuration sshd..."
/usr/sbin/sshd -t -f "$SSHD_CONFIG" || { bashio::log.fatal "Configuration sshd invalide !"; exit 1; }

bashio::log.info "Serveur SSH démarré sur le port 22 (user: ${USERNAME})"
exec /usr/sbin/sshd -D -e -f "$SSHD_CONFIG"

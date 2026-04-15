#!/bin/bash
set -e

USER_NAME="ansible"
SUDO_FILE="/etc/sudoers.d/ansible"
SSH_DROPIN_DIR="/etc/ssh/sshd_config.d"

# #SUBSTITUIR PELO IP DO ANSIBLE
ANSIBLE_IP="192.168.0.1"

# ============================
# Verificacoes
# ============================
if [ "$(id -u)" -ne 0 ]; then
    echo "Este script deve ser executado como root."
    exit 1
fi

if id "$USER_NAME" &>/dev/null; then
    echo 'usuario ansible já existe. Remova o usuario com "userdel ansible" e execute novamente o arquivo'
    exit 1
fi

if ! [[ "$ANSIBLE_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "IP inválido."
    exit 1
fi


# ============================
# Criar o usuário Ansible
# ============================
useradd -m -d /home/"$USER_NAME" -s /bin/bash "$USER_NAME"

passwd -l "$USER_NAME"

# ============================
# Verificar Distro
# ============================
if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "Não foi possível identificar a distribuição."
    exit 1
fi

# ============================
# Config do Sudoers
# ============================
cat <<EOF > "$SUDO_FILE"
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/apt
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/apt-get
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/dnf
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/yum
$USER_NAME ALL=(root) NOPASSWD: /usr/bin/zypper
EOF
chmod 440 "$SUDO_FILE"
visudo -cf "$SUDO_FILE"

# ============================
# Limitação por IP no SSH e forçar chave SSH
# ============================
case "$ID" in
    sles|opensuse*|suse)
        # SUSE moderno: drop-in
        mkdir -p "$SSH_DROPIN_DIR"
        SSHD_CONFIG_FILE="${SSH_DROPIN_DIR}/ansible.conf"
        ;;
    *)
        # Debian / Ubuntu / RHEL
        SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
        ;;
esac

cat <<EOF >> "$SSHD_CONFIG_FILE"

Match User ${USER_NAME} Address ${ANSIBLE_IP}
    PasswordAuthentication no
    PubkeyAuthentication yes
    AuthenticationMethods publickey
EOF

sshd -t

if command -v systemctl &>/dev/null; then
    systemctl reload sshd 2>/dev/null || systemctl reload ssh
else
    service sshd reload 2>/dev/null || service ssh reload
fi

# ============================
# Finalizacao
# ============================
echo "Usuário '$USER_NAME' criado e configurado com sucesso."
echo "Acesso SSH permitido somente para ${USER_NAME} a partir de ${ANSIBLE_IP}."
echo "Usuário ansible possui sudo restrito para comandos de update (apt/yum/dnf/zypper)."
#!/bin/bash

# =============================================================================
#  rollback.sh — Desfaz as instalações do setup.sh (Debian/Ubuntu)
#  Uso: bash rollback.sh
#  ATENÇÃO: Operação destrutiva e irreversível. Leia cada etapa antes de rodar.
# =============================================================================

set -o pipefail

# -----------------------------------------------------------------------------
# Cores e utilitários
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

LOG_FILE="/tmp/rollback-$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo -e "${CYAN}--- Log salvo em: $LOG_FILE ---${NC}"

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERRO]${NC}  $*" >&2; }
skip()  { echo -e "  ${CYAN}↷ Pulando:${NC} $*"; }

# Remove pacote APT somente se instalado
apt_remove() {
    local pkg="$1"
    if dpkg -s "$pkg" &>/dev/null; then
        info "Removendo pacote: $pkg"
        sudo apt-get remove -y --purge "$pkg" -qq
    else
        skip "$pkg não está instalado."
    fi
}

# Remove arquivo ou diretório somente se existir
safe_remove() {
    if [ -e "$1" ] || [ -L "$1" ]; then
        info "Removendo: $1"
        sudo rm -rf "$1"
    else
        skip "$1 não encontrado."
    fi
}

# -----------------------------------------------------------------------------
# Verificações iniciais
# -----------------------------------------------------------------------------
if ! grep -qi "ubuntu\|debian" /etc/os-release; then
    error "Sistema não suportado. Este script é apenas para Debian/Ubuntu."
    exit 1
fi

OS_ID=$(. /etc/os-release && echo "$ID")

echo ""
echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ATENÇÃO: Este script remove PERMANENTEMENTE os pacotes      ║${NC}"
echo -e "${RED}║  instalados pelo setup.sh. A ação não pode ser desfeita.     ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
read -r -p "Tem certeza que deseja continuar? Digite 'SIM' para confirmar: " CONFIRM
if [ "$CONFIRM" != "SIM" ]; then
    echo "Operação cancelada."
    exit 0
fi
echo ""

# -----------------------------------------------------------------------------
# Menu de seleção do que reverter
# -----------------------------------------------------------------------------
CHOICES=$(whiptail --title "Rollback — Selecione o que remover" --checklist \
    "Marque os itens a serem removidos (Espaço = marcar, Enter = confirmar):" 24 70 14 \
    "IDEs"        "VS Code / Cursor / Antigravity"         OFF \
    "PHP"         "PHP e todas as extensões"               OFF \
    "Nginx"       "Nginx e configurações"                  OFF \
    "MariaDB"     "MariaDB Server e dados"                 OFF \
    "Beekeeper"   "Beekeeper Studio"                       OFF \
    "Composer"    "Composer e pacotes globais"             OFF \
    "Laravel"     "Laravel Installer (Composer global)"    OFF \
    "NVM"         "NVM e todas as versões do Node"         OFF \
    "Docker"      "Docker Engine e imagens"                OFF \
    "OhMyZsh"     "Oh My Zsh, plugins e tema customizado"  OFF \
    "Zsh"         "Zsh (restaura bash como shell padrão)"  OFF \
    "APTSources"  "Repositórios APT adicionados"           OFF 3>&1 1>&2 2>&3) || {
    echo "Operação cancelada."
    exit 0
}

echo ""

# -----------------------------------------------------------------------------
# IDEs
# -----------------------------------------------------------------------------
if [[ "$CHOICES" == *"IDEs"* ]]; then
    info "=== Removendo IDEs ==="

    if snap list code &>/dev/null 2>&1; then
        info "Removendo VS Code (snap)..."
        sudo snap remove code
    else
        skip "VS Code não está instalado via snap."
    fi

    if command -v cursor &>/dev/null; then
        info "Removendo Cursor AI..."
        # O instalador oficial do Cursor instala em ~/.local/share/cursor ou /opt/cursor
        safe_remove "$HOME/.local/share/cursor"
        safe_remove "$HOME/.config/cursor"
        safe_remove "/opt/cursor"
        sudo rm -f /usr/local/bin/cursor /usr/bin/cursor
    else
        skip "Cursor não encontrado."
    fi

    if command -v antigravity &>/dev/null; then
        info "Removendo Antigravity..."
        apt_remove antigravity
        safe_remove /etc/apt/sources.list.d/antigravity.list
        safe_remove /etc/apt/keyrings/antigravity-repo-key.gpg
    else
        skip "Antigravity não encontrado."
    fi
fi

# -----------------------------------------------------------------------------
# PHP
# -----------------------------------------------------------------------------
if [[ "$CHOICES" == *"PHP"* ]]; then
    info "=== Removendo PHP e extensões ==="
    # Remove todos os pacotes php instalados (qualquer versão)
    PHP_PKGS=$(dpkg -l 'php*' 2>/dev/null | awk '/^ii/{print $2}' | tr '\n' ' ')
    if [ -n "$PHP_PKGS" ]; then
        # shellcheck disable=SC2086
        sudo apt-get remove -y --purge $PHP_PKGS -qq
        sudo apt-get autoremove -y -qq
    else
        skip "Nenhum pacote PHP encontrado."
    fi
    safe_remove /etc/php
fi

# -----------------------------------------------------------------------------
# Nginx
# -----------------------------------------------------------------------------
if [[ "$CHOICES" == *"Nginx"* ]]; then
    info "=== Removendo Nginx ==="
    if command -v nginx &>/dev/null; then
        sudo systemctl stop nginx 2>/dev/null || true
        sudo systemctl disable nginx 2>/dev/null || true
        apt_remove nginx
        apt_remove nginx-common
        sudo apt-get autoremove -y -qq
        safe_remove /etc/nginx
        safe_remove /var/log/nginx
        warn "O conteúdo de /var/www/html NÃO foi removido para preservar seus arquivos."
    else
        skip "Nginx não está instalado."
    fi
fi

# -----------------------------------------------------------------------------
# MariaDB
# -----------------------------------------------------------------------------
if [[ "$CHOICES" == *"MariaDB"* ]]; then
    info "=== Removendo MariaDB ==="
    echo -e "${RED}[PERIGO]${NC} Isso apagará TODOS os bancos de dados permanentemente."
    read -r -p "Confirma remoção do MariaDB e seus dados? [s/N] " CONFIRM_DB
    if [[ "$CONFIRM_DB" =~ ^[sS]$ ]]; then
        sudo systemctl stop mariadb 2>/dev/null || true
        sudo systemctl disable mariadb 2>/dev/null || true
        apt_remove mariadb-server
        apt_remove mariadb-client
        apt_remove mariadb-common
        sudo apt-get autoremove -y -qq
        safe_remove /etc/mysql
        safe_remove /var/lib/mysql
        safe_remove /var/log/mysql
    else
        skip "Remoção do MariaDB cancelada pelo usuário."
    fi
fi

# -----------------------------------------------------------------------------
# Beekeeper Studio
# -----------------------------------------------------------------------------
if [[ "$CHOICES" == *"Beekeeper"* ]]; then
    info "=== Removendo Beekeeper Studio ==="
    apt_remove beekeeper-studio
    safe_remove /usr/share/keyrings/beekeeper.gpg
    safe_remove /etc/apt/sources.list.d/beekeeper-studio.list
fi

# -----------------------------------------------------------------------------
# Laravel Installer (antes do Composer, pois depende dele)
# -----------------------------------------------------------------------------
if [[ "$CHOICES" == *"Laravel"* ]]; then
    info "=== Removendo Laravel Installer ==="
    if command -v composer &>/dev/null; then
        composer global remove laravel/installer --quiet 2>/dev/null || \
            warn "Laravel Installer não encontrado nos pacotes globais."
    else
        skip "Composer não disponível — pulando remoção do Laravel Installer."
    fi
fi

# -----------------------------------------------------------------------------
# Composer
# -----------------------------------------------------------------------------
if [[ "$CHOICES" == *"Composer"* ]]; then
    info "=== Removendo Composer ==="
    safe_remove /usr/local/bin/composer

    COMPOSER_HOME_DIR=$(composer config --global home 2>/dev/null || echo "$HOME/.config/composer")
    if [ -d "$COMPOSER_HOME_DIR" ]; then
        info "Removendo diretório global do Composer: $COMPOSER_HOME_DIR"
        rm -rf "$COMPOSER_HOME_DIR"
    else
        skip "Diretório global do Composer não encontrado."
    fi

    # Remove linha do PATH do .zshrc
    if [ -f "$HOME/.zshrc" ]; then
        sed -i '/composer config --global home/d' ~/.zshrc
        sed -i '/vendor\/bin/d' ~/.zshrc
        info "Referências do Composer removidas do ~/.zshrc"
    fi
fi

# -----------------------------------------------------------------------------
# NVM e Node
# -----------------------------------------------------------------------------
if [[ "$CHOICES" == *"NVM"* ]]; then
    info "=== Removendo NVM e Node ==="
    NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
    if [ -d "$NVM_DIR" ]; then
        # Desinstala todas as versões do Node gerenciadas pelo NVM
        export NVM_DIR
        \. "$NVM_DIR/nvm.sh" 2>/dev/null && nvm deactivate 2>/dev/null || true
        rm -rf "$NVM_DIR"
        info "Diretório NVM removido: $NVM_DIR"
    else
        skip "NVM não encontrado em $NVM_DIR"
    fi

    # Remove entradas do NVM no .zshrc e .bashrc
    for RC in ~/.zshrc ~/.bashrc ~/.bash_profile ~/.profile; do
        if [ -f "$RC" ]; then
            sed -i '/NVM_DIR/d' "$RC"
            sed -i '/nvm.sh/d' "$RC"
            sed -i '/nvm bash_completion/d' "$RC"
            info "Referências do NVM removidas de $RC"
        fi
    done
fi

# -----------------------------------------------------------------------------
# Docker
# -----------------------------------------------------------------------------
if [[ "$CHOICES" == *"Docker"* ]]; then
    info "=== Removendo Docker ==="
    echo -e "${RED}[PERIGO]${NC} Isso removerá todos os containers, imagens e volumes Docker."
    read -r -p "Confirma remoção completa do Docker? [s/N] " CONFIRM_DOCKER
    if [[ "$CONFIRM_DOCKER" =~ ^[sS]$ ]]; then
        sudo systemctl stop docker 2>/dev/null || true
        sudo systemctl disable docker 2>/dev/null || true

        for pkg in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; do
            apt_remove "$pkg"
        done

        sudo apt-get autoremove -y -qq
        safe_remove /var/lib/docker
        safe_remove /var/lib/containerd
        safe_remove /etc/apt/sources.list.d/docker.list
        safe_remove /etc/apt/keyrings/docker.gpg

        # Remove usuário do grupo docker
        if getent group docker &>/dev/null; then
            sudo gpasswd -d "$USER" docker 2>/dev/null || true
            sudo groupdel docker 2>/dev/null || true
            info "Usuário removido do grupo docker."
        fi
    else
        skip "Remoção do Docker cancelada pelo usuário."
    fi
fi

# -----------------------------------------------------------------------------
# Oh My Zsh, plugins e tema customizado
# -----------------------------------------------------------------------------
if [[ "$CHOICES" == *"OhMyZsh"* ]]; then
    info "=== Removendo Oh My Zsh ==="
    if [ -d "$HOME/.oh-my-zsh" ]; then
        # Usa o uninstaller oficial se disponível
        if [ -f "$HOME/.oh-my-zsh/tools/uninstall.sh" ]; then
            sh "$HOME/.oh-my-zsh/tools/uninstall.sh" --unattended 2>/dev/null || true
        fi
        # Garante remoção mesmo que o uninstaller falhe
        safe_remove "$HOME/.oh-my-zsh"
        info "Oh My Zsh removido."
    else
        skip "Oh My Zsh não encontrado."
    fi
fi

# -----------------------------------------------------------------------------
# Zsh — restaura bash como shell padrão
# -----------------------------------------------------------------------------
if [[ "$CHOICES" == *"Zsh"* ]]; then
    info "=== Restaurando Bash como shell padrão ==="
    if command -v bash &>/dev/null; then
        sudo chsh -s "$(which bash)" "$USER"
        info "Shell padrão restaurado para Bash."
    else
        warn "Bash não encontrado — shell não alterado."
    fi

    apt_remove zsh
    safe_remove "$HOME/.zshrc"
    safe_remove "$HOME/.zsh_history"
    safe_remove "$HOME/.zcompdump"*
fi

# -----------------------------------------------------------------------------
# Repositórios APT adicionados pelo setup.sh
# -----------------------------------------------------------------------------
if [[ "$CHOICES" == *"APTSources"* ]]; then
    info "=== Removendo repositórios APT adicionados ==="

    # PPA Ondrej PHP (só em Ubuntu)
    if [ "$OS_ID" = "ubuntu" ]; then
        if grep -r "ondrej/php" /etc/apt/sources.list.d/ &>/dev/null; then
            sudo add-apt-repository --remove ppa:ondrej/php -y
            info "PPA ondrej/php removido."
        else
            skip "PPA ondrej/php não encontrado."
        fi
    fi

    sudo apt-get update -qq
    info "Lista de repositórios APT atualizada."
fi

# -----------------------------------------------------------------------------
# Limpeza final
# -----------------------------------------------------------------------------
info "Limpando cache APT..."
sudo apt-get autoremove -y -qq
sudo apt-get autoclean -qq

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Rollback concluído!                             ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Log completo:${NC} $LOG_FILE"
echo ""
echo -e "  ${YELLOW}Recomendação:${NC} Abra um novo terminal para garantir que"
echo -e "  as variáveis de ambiente foram limpas corretamente."
echo ""

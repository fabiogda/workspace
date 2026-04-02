#!/bin/bash

# =============================================================================
#  setup.sh — Ambiente de Desenvolvimento (Debian/Ubuntu)
#  Uso: bash setup.sh
# =============================================================================

set -e
set -o pipefail

# -----------------------------------------------------------------------------
# Cores
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# Log com timestamp em arquivo e terminal
# -----------------------------------------------------------------------------
LOG_FILE="/tmp/setup-$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo -e "${CYAN}--- Log salvo em: $LOG_FILE ---${NC}"

# -----------------------------------------------------------------------------
# Funções utilitárias
# -----------------------------------------------------------------------------
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERRO]${NC}  $*" >&2; }
die()     { error "$*"; exit 1; }

# Verifica se um comando já está disponível
is_installed() { command -v "$1" &>/dev/null; }

# Clone só se o diretório de destino não existir (idempotente)
clone_if_missing() {
    local repo="$1" dest="$2"
    if [ -d "$dest" ]; then
        warn "Já existe: $dest — pulando clone."
    else
        git clone "$repo" "$dest"
    fi
}

# Confirmação explícita antes de executar scripts externos
confirm_exec() {
    local script="$1"
    echo -e "${YELLOW}[ATENÇÃO] Você está prestes a executar um script externo:${NC}"
    echo "  $script"
    read -r -p "Deseja continuar? [s/N] " resp
    [[ "$resp" =~ ^[sS]$ ]] || die "Execução cancelada pelo usuário."
}

# -----------------------------------------------------------------------------
# Verificações iniciais
# -----------------------------------------------------------------------------
if ! grep -qi "ubuntu\|debian" /etc/os-release; then
    die "Sistema não suportado. Este script é apenas para Debian/Ubuntu."
fi

# Detecta ID do sistema operacional (ubuntu ou debian) — usado no repo Docker
OS_ID=$(. /etc/os-release && echo "$ID")
OS_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")

info "Iniciando o Setup ($OS_ID / $OS_CODENAME)"

# -----------------------------------------------------------------------------
# Atualização base
# -----------------------------------------------------------------------------
info "Atualizando pacotes base..."
sudo apt-get update -qq && sudo apt-get upgrade -y -qq
sudo apt-get install -y -qq \
    whiptail software-properties-common curl wget git unzip \
    dirmngr ca-certificates gnupg lsb-release apt-transport-https

# -----------------------------------------------------------------------------
# Menu de IDEs
# -----------------------------------------------------------------------------
CHOICES=$(whiptail --title "Instalação de IDEs" --checklist \
    "Selecione o que deseja instalar (Espaço = marcar, Enter = confirmar):" 15 65 3 \
    "VSCode"      "Visual Studio Code"  OFF \
    "Cursor"      "Cursor AI Editor"    OFF \
    "Antigravity" "Google Antigravity"  OFF 3>&1 1>&2 2>&3) || true

# --- VS Code ---
if [[ "$CHOICES" == *"VSCode"* ]]; then
    if is_installed code; then
        warn "VS Code já instalado — pulando."
    else
        info "Instalando VS Code..."
        sudo snap install --classic code
    fi
fi

# --- Cursor AI ---
if [[ "$CHOICES" == *"Cursor"* ]]; then
    if is_installed cursor; then
        warn "Cursor já instalado — pulando."
    else
        info "Baixando instalador do Cursor AI..."
        curl -fsSL https://cursor.sh/scripts/install.sh -o /tmp/cursor-install.sh
        confirm_exec "/tmp/cursor-install.sh"
        bash /tmp/cursor-install.sh
        rm -f /tmp/cursor-install.sh
    fi
fi

# --- Antigravity ---
if [[ "$CHOICES" == *"Antigravity"* ]]; then
    if is_installed antigravity; then
        warn "Antigravity já instalado — pulando."
    else
        info "Instalando Antigravity (Google)..."
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
            sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg
        echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] \
https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
            sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null
        sudo apt-get update -qq && sudo apt-get install -y antigravity
    fi
fi

# -----------------------------------------------------------------------------
# PHP — última versão estável via PPA Ondrej
# -----------------------------------------------------------------------------
info "Instalando PHP e extensões..."
if ! grep -q "ondrej/php" /etc/apt/sources.list.d/*.list 2>/dev/null; then
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt-get update -qq
fi

sudo apt-get install -y -qq \
    php php-cli php-fpm php-mysql php-xml php-mbstring \
    php-curl php-zip php-bcmath php-intl php-gd php-sqlite3

# Detecta a versão instalada para uso no PHP-FPM explícito
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
info "PHP $PHP_VERSION detectado."

# -----------------------------------------------------------------------------
# Nginx e MariaDB
# -----------------------------------------------------------------------------
info "Instalando Nginx e MariaDB..."

if ! is_installed nginx; then
    sudo apt-get install -y -qq nginx
else
    warn "Nginx já instalado — pulando."
fi

if ! is_installed mysql && ! is_installed mariadb; then
    sudo apt-get install -y -qq mariadb-server
    sudo systemctl enable --now mariadb
else
    warn "MariaDB/MySQL já instalado — pulando."
fi

sudo chown -R "$USER":www-data /var/www/html
sudo chmod -R 755 /var/www/html

# -----------------------------------------------------------------------------
# Beekeeper Studio
# -----------------------------------------------------------------------------
info "Instalando Beekeeper Studio..."
if is_installed beekeeper-studio; then
    warn "Beekeeper Studio já instalado — pulando."
else
    curl -fsSL https://deb.beekeeperstudio.io/beekeeper.key | \
        sudo gpg --dearmor -o /usr/share/keyrings/beekeeper.gpg
    echo "deb [signed-by=/usr/share/keyrings/beekeeper.gpg] https://deb.beekeeperstudio.io stable main" | \
        sudo tee /etc/apt/sources.list.d/beekeeper-studio.list > /dev/null
    sudo apt-get update -qq && sudo apt-get install -y beekeeper-studio
fi

# -----------------------------------------------------------------------------
# Composer — com validação real de hash
# -----------------------------------------------------------------------------
info "Instalando Composer..."
if is_installed composer; then
    warn "Composer já instalado — pulando."
else
    COMPOSER_SETUP="/tmp/composer-setup.php"
    php -r "copy('https://getcomposer.org/installer', '$COMPOSER_SETUP');"

    EXPECTED_HASH=$(curl -fsSL https://composer.github.io/installer.sig)
    ACTUAL_HASH=$(php -r "echo hash_file('sha384', '$COMPOSER_SETUP');")

    if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
        rm -f "$COMPOSER_SETUP"
        die "Hash do instalador do Composer não confere! Possível download corrompido ou malicioso."
    fi

    info "Hash do Composer verificado com sucesso."
    php "$COMPOSER_SETUP" --quiet
    rm -f "$COMPOSER_SETUP"
    sudo mv composer.phar /usr/local/bin/composer
    sudo chmod +x /usr/local/bin/composer
fi

# -----------------------------------------------------------------------------
# Laravel Installer (global via Composer)
# -----------------------------------------------------------------------------
info "Instalando Laravel Installer..."
composer global require laravel/installer --quiet

# Resolve o diretório home do Composer de forma segura (sem dependência circular)
COMPOSER_HOME_DIR=$(composer config --global home 2>/dev/null || echo "$HOME/.config/composer")
COMPOSER_BIN="$COMPOSER_HOME_DIR/vendor/bin"

# Adiciona ao PATH da sessão atual
export PATH="$PATH:$COMPOSER_BIN"

# Adiciona permanentemente ao .zshrc (sem duplicar)
ZSHRC_LINE="export PATH=\"\$PATH:$COMPOSER_BIN\""
if ! grep -qF "$COMPOSER_BIN" ~/.zshrc 2>/dev/null; then
    echo "$ZSHRC_LINE" >> ~/.zshrc
    info "PATH do Composer adicionado ao ~/.zshrc"
fi

# -----------------------------------------------------------------------------
# NVM e Node LTS — carregamento imediato no mesmo shell
# -----------------------------------------------------------------------------
info "Instalando NVM e Node LTS..."
export NVM_DIR="$HOME/.nvm"

if [ ! -d "$NVM_DIR" ]; then
    # Busca a versão mais recente do NVM dinamicamente
    NVM_VERSION=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest \
        | grep '"tag_name"' | cut -d'"' -f4)
    info "Instalando NVM $NVM_VERSION..."
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
else
    warn "NVM já instalado — pulando download."
fi

# Carrega o NVM imediatamente no shell atual (sem precisar abrir novo terminal)
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

if ! command -v nvm &>/dev/null; then
    die "NVM não pôde ser carregado. Verifique a instalação em $NVM_DIR"
fi

nvm install --lts
nvm alias default 'lts/*'
info "Node $(node -v) / npm $(npm -v) instalados."

# -----------------------------------------------------------------------------
# Docker Engine — adaptado para Ubuntu e Debian
# -----------------------------------------------------------------------------
info "Instalando Docker Engine..."
if is_installed docker; then
    warn "Docker já instalado — pulando."
else
    sudo install -m 0755 -d /etc/apt/keyrings

    # URL e GPG corretos por distro (corrige bug do Ubuntu-only original)
    DOCKER_GPG="/etc/apt/keyrings/docker.gpg"
    curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" | \
        sudo gpg --dearmor -o "$DOCKER_GPG"
    # Permissão 644 (leitura pelo root + grupo, sem exec) — mais seguro que a+r
    sudo chmod 644 "$DOCKER_GPG"

    echo "deb [arch=$(dpkg --print-architecture) signed-by=$DOCKER_GPG] \
https://download.docker.com/linux/${OS_ID} ${OS_CODENAME} stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin

    # Adiciona usuário ao grupo docker (sem sudo)
    sudo usermod -aG docker "$USER"
    warn "Docker instalado. Deslogue e logue novamente (ou rode 'newgrp docker') para usar sem sudo."
fi

# -----------------------------------------------------------------------------
# Oh My Zsh e customização
# -----------------------------------------------------------------------------
info "Configurando Zsh e Oh My Zsh..."
sudo apt-get install -y -qq zsh

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    warn "Oh My Zsh já instalado — pulando."
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Plugins — clone idempotente
clone_if_missing \
    https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

clone_if_missing \
    https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

clone_if_missing \
    https://github.com/marlonrichert/zsh-autocomplete \
    "$ZSH_CUSTOM/plugins/zsh-autocomplete"

# Configura tema e plugins no .zshrc (idempotente via sed)
sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="gnzh"/' ~/.zshrc
sed -i 's/plugins=(git)/plugins=(git sudo zsh-autosuggestions zsh-syntax-highlighting zsh-autocomplete)/' ~/.zshrc

# Escreve tema gnzh customizado
cat << 'EOF' > "$HOME/.oh-my-zsh/themes/gnzh.zsh-theme"
# Based on bira theme
setopt prompt_subst
() {
local PR_USER PR_USER_OP PR_PROMPT PR_HOST
if [[ $UID -ne 0 ]]; then
  PR_USER='%B%F{yellow}%n%f'
  PR_USER_OP='%F{green}%#%f'
  PR_PROMPT='%f➤ %f'
else
  PR_USER='%F{red}%n%f'
  PR_USER_OP='%F{red}%#%f'
  PR_PROMPT='%F{red}➤ %f'
fi
if [[ -n "$SSH_CLIENT" || -n "$SSH2_CLIENT" ]]; then
  PR_HOST='%F{red}%M%f'
else
  PR_HOST='%F{green}%m%f'
fi
local return_code="%(?..%F{red}%? ↵%f)"
local user_host="${PR_USER}"
local current_dir="%B%F{cyan}%1~%f%b"
local git_branch='$(git_prompt_info)'
local venv_prompt='$(virtualenv_prompt_info)'
PROMPT="╭─${venv_prompt}${user_host} ${current_dir} \$(ruby_prompt_info) ${git_branch}
╰─$PR_PROMPT "
RPROMPT="${return_code}"
ZSH_THEME_GIT_PROMPT_PREFIX="%B%F{magenta}‹"
ZSH_THEME_GIT_PROMPT_SUFFIX="› %f"
ZSH_THEME_RUBY_PROMPT_PREFIX="%F{red}‹"
ZSH_THEME_RUBY_PROMPT_SUFFIX="›%f"
ZSH_THEME_VIRTUALENV_PREFIX="%F{red}("
ZSH_THEME_VIRTUALENV_SUFFIX=")%f "
}
EOF

# -----------------------------------------------------------------------------
# Altera shell padrão para Zsh
# -----------------------------------------------------------------------------
if [ "$SHELL" != "$(which zsh)" ]; then
    info "Alterando shell padrão para Zsh..."
    sudo chsh -s "$(which zsh)" "$USER"
fi

# -----------------------------------------------------------------------------
# Resumo final
# -----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Setup concluído com sucesso!              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}Log completo:${NC} $LOG_FILE"
echo ""
echo -e "  ${YELLOW}Próximos passos:${NC}"
echo -e "  1. Deslogue do sistema e logue novamente para ativar o Zsh e o Docker sem sudo."
echo -e "  2. Senão quiser deslogar mas quer testar o Docker, execute ${CYAN}newgrp docker${NC}."
echo -e "  3. Execute ${CYAN}laravel new projeto${NC} para criar seu primeiro projeto Laravel."
echo ""

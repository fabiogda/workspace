# 🚀 Workspace: One-Command Dev Environment

Este repositório contém scripts de automação para transformar uma instalação limpa do **Debian/Ubuntu** em uma estação de trabalho completa para desenvolvimento Web Fullstack (PHP, Laravel, Docker, JS).

O objetivo é padronizar o ambiente de desenvolvimento com as melhores ferramentas de produtividade, garantindo que o setup seja idêntico em qualquer máquina.

---

## 🛠️ O que será instalado?

### 💻 IDEs & Editores (Menu Interativo)
- **Google Antigravity:** A IDE de alto desempenho da Google (Instalação via repositório oficial).
- **Visual Studio Code:** O editor padrão da indústria via Snap.
- **Cursor AI:** Editor focado em pareamento com Inteligência Artificial.

### 🐘 Stack Backend & Banco de Dados
- **PHP (Latest Stable):** Versão mais recente via PPA Ondrej com extensões essenciais (`xml`, `mbstring`, `gd`, `curl`, `zip`, `bcmath`, `intl`, `sqlite3`).
- **Composer:** Gerenciador de dependências PHP movido para `/usr/local/bin`.
- **Nginx:** Servidor web configurado para o diretório `/var/www/html` com permissões para o usuário atual.
- **MariaDB Server:** Banco de dados SQL configurado sem senha para root (via Unix Socket).
- **Beekeeper Studio:** Interface GUI moderna e "limpa" para gestão de bancos de dados.

### 🐳 Infraestrutura & Runtime
- **Docker Engine:** Versão de terminal (Engine) configurada para rodar **sem a necessidade de `sudo`**.
- **NVM (Node Version Manager):** Instalado com a última versão **Node.js LTS** configurada.
- **Git:** Essencial para controle de versão.

### 🐚 Terminal Experience (Zsh)
- **Oh My Zsh:** Framework para gerenciar a configuração do Zsh.
- **Tema Customizado:** Baseado no `gnzh` com visual refinado para Git, Virtualenvs e detecção de SSH.
- **Plugins Inclusos:**
    - `zsh-autosuggestions`: Sugestões baseadas no histórico.
    - `zsh-syntax-highlighting`: Cores em tempo real nos comandos.
    - `zsh-autocomplete`: Menu de completação interativo.
    - `sudo`: Pressione `ESC` duas vezes para adicionar `sudo` ao comando atual (atalho rápido).

---

## 🚀 Como usar

1. **Clone o repositório:**
   ```bash
   git clone [https://github.com/fabiogda/workspace.git](https://github.com/fabiogda/workspace.git)
   cd workspace
   ```

2. **Dê permissão de execução ao script principal:**
   ```bash
   chmod +x setup.sh
    ```
3. **Execute o script:**
   ```bash
    ./setup.sh
    ```

---

## 🧹 Reversão (Rollback)

Se precisar limpar o ambiente e remover as ferramentas instaladas para retornar ao estado original, utilize o script de cleanup:

1. **Execute o script:**
   ```bash
    chmod +x cleanup.sh
    ./cleanup_env.sh
    ```

---

## ⚠️ Notas Importantes

**Web Server**: O diretório raiz para seus projetos é `/var/www/html`. O script já ajusta o owner para o seu usuário atual, evitando problemas de permissão ao criar arquivos.

**Zsh**: O script altera o shell padrão automaticamente via chsh. Na primeira execução, o terminal será reiniciado para carregar as novas configurações.

**Docker**: Para que o Docker funcione sem sudo, você deve **fazer logout e login novamente no sistema** após a execução do script para atualizar os grupos do usuário.

---

## 📄 Licença
Este projeto está sob a licença MIT. Sinta-se à vontade para usar e customizar!

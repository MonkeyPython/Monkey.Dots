# Monkey.Dots

> Dotfiles personales para tener **las terminales siempre configuradas**,
> adaptados de [Gentleman.Dots](https://github.com/Gentleman-Programming/Gentleman.Dots) y recortados a lo que realmente uso.

📄 Lee esto en: **Español** | [English](README.md)

## Qué se instala

Además de linkear las configs, el instalador también:

- Instala la **Iosevka Term Nerd Font** a nivel sistema (cask de
  Homebrew en macOS, descarga directa desde los releases de Nerd
  Fonts en Linux/WSL, cask de Homebrew en Windows nativo).
  Idempotente — si ya está presente, la salta.
- Instala los **paquetes de Homebrew / IDs de winget** listados en
  `lib/packages.toml`. En macOS, Linux y WSL se usa Homebrew. En
  Windows nativo, winget es el fallback. El manifest es la única
  fuente de verdad sobre qué instalar — `lib/install_brew.sh` lo lee
  en cada ejecución. Si el manifest no está, hay un fallback
  hardcodeado (con warning).
- Hace bootstrap de **Oh My Zsh** descargando el script oficial y
  corriéndolo con `--unattended --keep-zshrc` (así no sobreescribe
  el `.zshrc` que enviamos). Idempotente — si `~/.oh-my-zsh` ya
  existe, la salta. Se salta en Windows nativo donde OMZ es frágil.
  El `.zshrc` enviado tiene un guard por si OMZ no está.
- Hace bootstrap de **TPM** (Tmux Plugin Manager) clonándolo con
  `git clone` a `~/.tmux/plugins/tpm`, y luego corre
  `tpm install_plugins` headless en una sesión tmux detached de un
  solo uso que sources el `tmux.conf` renderizado. Es best-effort:
  si falla, el fallback es abrir tmux y pulsar `prefix + I` a
  mano. Idempotente. Se salta en Windows nativo (no hay tmux
  nativo).
- Detecta el **shell** vía `lib/shell.sh` y renderiza `tmux/tmux.conf`
  para que `default-command` / `default-shell` apunten al shell real
  del usuario.
- Imprime el **comando `chsh`** necesario para hacer zsh el login
  shell por defecto, si no lo es ya. No corremos chsh nosotros
  mismos (requiere sudo y re-login), solo imprimimos instrucciones
  copy-paste-ready.

Todo lo anterior respeta `MONKEY_DRY_RUN` (set con `--dry-run`) y es
seguro de re-ejecutar.

## ¿Qué es esto?

Un gestor de dotfiles mínimo y opinado que te da la misma configuración
de **terminal, shell y multiplexer** en **macOS, Linux y Windows (WSL + nativo)**.

- **Terminal**: [WezTerm](https://wezterm.org) (aceleración por GPU, config en Lua, binario único en todas las plataformas)
- **Shell**: Zsh + [Oh My Zsh](https://ohmyz.sh) + [Powerlevel10k](https://github.com/romkatv/powerlevel10k)
- **Multiplexer**: Tmux con TPM, tema Kanagawa, vim-tmux-navigator
- **Prompt**: [Starship](https://starship.rs) (tiene precedencia sobre p10k; ambos funcionan)
- **Extras**: fzf, zoxide, atuin, carapace, bat, fd, eza, lazygit, neovim
- **Git**: aliases, pager delta, autoSetupRemote, defaults sensatos

Sin TUI installer, sin Vim Trainer RPG, sin Neovim LazyVim. Solo las
piezas que hacen que cada terminal se sienta como en casa.

## La paleta "monkey"

Forkeada de la paleta de Gentleman. La estructura es idéntica para que
las configs se vean y sientan como las suyas — solo dos acentos retocados
para hacerla mía:

| Token  | Gentleman | Monkey | Por qué |
|--------|-----------|--------|---------|
| yellow | `#FFE066` (mostaza) | `#F5A524` (ámbar) | más cálida y saturada |
| mauve  | `#A3B5D6` (lavanda) | `#C792EA` (violeta) | más profunda, reconocible |

Todo lo demás (fondo, frente, ANSI 0–7, selección, etc.) es byte a byte
igual.

## Inicio rápido

```bash
git clone https://github.com/<tu-usuario>/Monkey.Dots.git ~/.dotfiles
cd ~/.dotfiles
./install.sh            # instalación completa (paquetes brew + symlinks)
```

Luego reinicia tu terminal (o `exec zsh`) y dentro de tmux pulsa
`prefix + I` para instalar los plugins de TPM.

## Flags

```bash
./install.sh --no-brew   # solo symlinks, sin instalar paquetes
./install.sh --dry-run   # muestra qué haría, no toca nada
./install.sh --restore   # restaura el backup más reciente
./uninstall.sh           # quita los symlinks, restaura el backup
./uninstall.sh --keep-backup  # quita los symlinks, deja los backups
```

## Qué se linkea

| Ruta en el repo       | Destino                                | Cómo |
|-----------------------|----------------------------------------|------|
| `wezterm/`            | `~/.config/wezterm`                    | symlink (directorio entero) |
| `tmux/tmux.conf`      | `~/.config/tmux/tmux.conf`             | **renderizado** (sustituye `MONKEY_DEFAULT_SHELL` con tu shell real) |
| `starship/starship.toml` | `~/.config/starship.toml`           | symlink |
| `zsh/.zshrc`          | `~/.zshrc`                             | symlink |
| `zsh/.p10k.zsh`       | `~/.p10k.zsh`                          | symlink |
| `git/.gitconfig`      | `~/.gitconfig`                         | symlink |

`tmux.conf` es el único target que se **renderiza** (no se symlinkea),
para que el resultado de la detección de shell del instalador
(`$SHELL` → brew `zsh` → `bash` → `/bin/sh`) termine en las directivas
`default-command` / `default-shell`. Re-ejecutar `./install.sh`
lo re-renderiza con el shell actual. Para cambiar el shell: edita
tu entorno y re-ejecuta.

Cualquier archivo preexistente en esas rutas se respalda primero a
`~/.dotfiles-backup/<timestamp>/...`.

## Plataformas soportadas

| Plataforma           | Gestor de paquetes  | Notas |
|----------------------|---------------------|-------|
| macOS (Apple Silicon / Intel) | Homebrew | Nativo |
| Linux (Ubuntu, Debian, Fedora, Arch…) | Homebrew (Linuxbrew) | Un solo Brew, mismos comandos |
| Windows — WSL (Ubuntu) | Homebrew (Linuxbrew) | **Recomendado en Windows** |
| Windows — nativo (Git Bash) | winget como fallback | Solo WezTerm + oh-my-posh; algunos temas pueden no aplicar |
| Termux (Android)   | pkg | Detectado, sin auto-instalar (mantenido por paridad) |

### Windows nativo (Git Bash) — caveats

Correr el instalador bajo **Git Bash en Windows** funciona, pero varias
piezas del stack están degradadas comparado con macOS / Linux / WSL.
El instalador imprime estas advertencias al arrancar; aquí está la versión larga.

| Herramienta | Estado | Qué hacer |
|-------------|--------|-----------|
| **WezTerm** | ✅ Funciona | Instalado con `winget install wez.wezterm`. Lee `wezterm.lua` con normalidad. |
| **Starship** | ✅ Funciona | `~/.config/starship.toml` linkeado, corre en cualquier shell. |
| **fzf, zoxide, bat, fd, eza, lazygit** | ✅ Funcionan | Todos disponibles vía winget. |
| **neovim** | ✅ Funciona | `winget install Neovim.Neovim`. |
| **Oh My Zsh + plugins zsh** | ⚠️ Degradado | Zsh existe en Windows pero Oh My Zsh es frágil. El `.zshrc` lo detecta y cae a starship-only si falta. |
| **Powerlevel10k** | ⚠️ Parcial | Corre, pero los glyphs pueden no renderizar en WezTerm sin Iosevka Nerd Font instalada a nivel sistema. Configura p10k con WezTerm, no con Windows Terminal. |
| **Tmux** | ❌ No instalado | No hay tmux nativo en Windows. Usa el multiplexer integrado de WezTerm (tabs + panes). El symlink `tmux/tmux.conf` se crea pero no se usa. |
| **Completions de carapace** | ⚠️ Parcial | Corre pero los archivos de completion van a `~/.config/fish/completions` (un path que Git Bash puede crear pero las herramientas Windows pueden no leer). |
| **atuin** | ⚠️ Parcial | Búsqueda local funciona, sync server necesita setup extra. |
| **Identidad Git** | ✅ Tú la pones | `git config --global user.name` / `user.email`. |

**Recomendación:** si te encuentras peleando con quirks de Git Bash,
instala [WSL (Ubuntu)](https://learn.microsoft.com/es-es/windows/wsl/install)
y re-ejecuta `./install.sh` desde ahí. El mismo repo, las mismas
configs, cero caveats.

## Después de instalar

1. **Plugins de Tmux**: el instalador clona TPM y corre
   `install_plugins` headless. Si ese paso falla (p.ej. tmux no puede
   hacer fork en tu entorno), abre tmux y pulsa `prefix + I` (I
   mayúscula) — TPM clonará Kanagawa, vim-tmux-navigator,
   tmux-resurrect, etc.
2. **Oh My Zsh**: el instalador ofrece instalarlo si no está. Sin él,
   el `.zshrc` funciona en modo degradado (sin autosuggestions / syntax
   highlighting, pero starship y fzf siguen OK).
3. **Powerlevel10k**: ejecuta `p10k configure` la primera vez para
   generar la config que coincida con el ancho de tu terminal. El
   `.p10k.zsh` incluido es un default sensato si te lo saltas.
4. **Identidad de Git**: el `.gitconfig` incluido **no** pone tu
   nombre/email a propósito. Configúralos tú:
   ```bash
   git config --global user.name  "Tu Nombre"
   git config --global user.email "tu@email.com"
   ```

## Verificar el instalador

```bash
shellcheck install.sh uninstall.sh lib/*.sh tests/*.sh
bash tests/install_smoke.sh
```

El smoke test crea un `$HOME` aislado, corre install/uninstall y
verifica que los symlinks, los backups y la idempotencia funcionan.

## Layout del repo

```
Monkey.Dots/
├── install.sh             # instalador principal (idempotente, con backup)
├── uninstall.sh           # quita los symlinks, restaura el backup
├── lib/                   # módulos bash pequeños
│   ├── detect.sh          # detección de OS / WSL / brew / winget
│   ├── backup.sh          # backups con timestamp
│   ├── symlink.sh         # linkado idempotente
│   ├── install_brew.sh    # instalación best-effort de paquetes
│   └── log.sh             # helpers de log con color
├── wezterm/wezterm.lua    # config de la terminal
├── zsh/.zshrc             # config del shell
├── zsh/.p10k.zsh          # fallback de p10k
├── tmux/tmux.conf         # config del multiplexer
├── starship/starship.toml # prompt
├── git/.gitconfig         # aliases y defaults de git
└── tests/install_smoke.sh # smoke test end-to-end
```

## Licencia

MIT. Haz lo que quieras, se agradece la atribución.

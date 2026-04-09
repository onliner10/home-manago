{ config, pkgs, lib, unstable, ... }:
let
  open-in-nvim = pkgs.writeShellScript "open-in-nvim" ''
    NVIM_SOCK="/tmp/nvim-zellij.sock"
    NVIM="${pkgs.neovim-unwrapped}/bin/nvim"
    ZELLIJ="${pkgs.zellij}/bin/zellij"

    input="$1"
    [ -S "$NVIM_SOCK" ] || exit 1

    # Parse file:line:col
    file="$input" line="" col=""
    if [[ "$input" =~ ^(.+):([0-9]+):([0-9]+)$ ]]; then
      file="''${BASH_REMATCH[1]}" line="''${BASH_REMATCH[2]}" col="''${BASH_REMATCH[3]}"
    elif [[ "$input" =~ ^(.+):([0-9]+)$ ]]; then
      file="''${BASH_REMATCH[1]}" line="''${BASH_REMATCH[2]}"
    fi

    # Resolve relative paths using Neovim's CWD
    if [[ "$file" != /* ]]; then
      nvim_cwd=$("$NVIM" --server "$NVIM_SOCK" --remote-expr "getcwd()" 2>/dev/null || true)
      if [[ -n "$nvim_cwd" ]]; then file="$nvim_cwd/$file"; fi
    fi

    # Open file, then position cursor (--remote +cmd not supported in nvim 0.11)
    "$NVIM" --server "$NVIM_SOCK" --remote "$file"
    if [[ -n "$line" && -n "$col" ]]; then
      "$NVIM" --server "$NVIM_SOCK" --remote-send "<Esc>:call cursor($line, $col)<CR>"
    elif [[ -n "$line" ]]; then
      "$NVIM" --server "$NVIM_SOCK" --remote-send "<Esc>:''${line}<CR>"
    fi

    # Best-effort: focus the Neovim pane in Zellij
    session=$("$ZELLIJ" list-sessions 2>/dev/null | grep -m1 '(current)' | awk '{print $1}')
    [[ -n "$session" ]] && "$ZELLIJ" --session "$session" action focus-next-pane 2>/dev/null || true
  '';
in
{
  imports = [
    ./vim.nix
  ];
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };
 
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.sessionVariables = {
    PATH = "$PATH:/usr/local/bin:/Applications/Sublime Text.app/Contents/SharedSupport/bin";
    RIPGREP_CONFIG_PATH = "$HOME/.ripgreprc";
  };
 
  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.
  
  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    pkgs.nerd-fonts.fira-code
    pkgs.nerd-fonts.droid-sans-mono
    pkgs.pgadmin4-desktopmode
    pkgs.visidata
    pkgs.alacritty
    pkgs.tmux
    pkgs.jq
    pkgs.awscli2
    pkgs.repgrep
    pkgs.oh-my-zsh
    pkgs.fzf
    pkgs.bat
    pkgs.gnupg
    pkgs.zsh-powerlevel10k
    pkgs.difftastic
    pkgs.ruby
    pkgs.jdk21
    pkgs.htop
    pkgs.zenith
    pkgs.bottom
    pkgs.unixtools.watch
    pkgs.multitail
    pkgs.openapi-tui
    pkgs.yazi
    pkgs.drawio 
    pkgs.dasht
    pkgs.git-lfs
    pkgs.gnupg
    pkgs.zellij
    pkgs.nodejs_24
    pkgs.git
    pkgs.httpie
    pkgs.claude-code
    pkgs.ripgrep
    pkgs.gemini-cli
    pkgs.codex
    pkgs.yamllint
    pkgs.sox
    unstable.opencode
  ];
 
  programs.direnv = {
    enable = true;
    enableZshIntegration = true; # see note on other shells below
    nix-direnv.enable = true;
  };
  programs.home-manager = {
    enable = true;
  };
  programs.tmux = {
    enable = true;
    shell = "${pkgs.zsh}/bin/zsh";
    terminal = "tmux-256color";
    historyLimit = 100000;
    extraConfig = ''
      set -g default-command ${pkgs.zsh}/bin/zsh
      set -g mouse on
      set -ga terminal-overrides ',*256color*:smcup@:rmcup@'

      set -g prefix C-a
      unbind-key C-b
      bind-key C-a send-prefix

      # vim-like pane switching
      bind -r k select-pane -U
      bind -r j select-pane -D
      bind -r h select-pane -L
      bind -r l select-pane -R

      unbind C-Up
      unbind C-Down
      unbind C-Left
      unbind C-Right
    '';
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      {
        plugin = dracula;
        extraConfig = ''
          set -g @dracula-show-battery false
          set -g @dracula-show-powerline true
          set -g @dracula-refresh-rate 10
          set -g @dracula-plugins "cpu-usage tmux-ram-usage"
          set -g @dracula-cpu-usage-label "C"
          set -g @dracula-tmux-ram-usage-label "M"
        '';
      }
    ];
  };

  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        size = 17;
        normal = {
          family = "FiraCode Nerd Font Mono";
          style = "Regular";
        };
        bold = {
          family = "FiraCode Nerd Font Mono";
          style = "Bold";
        };
      };
      terminal.shell = {
        program = "${pkgs.zsh}/bin/zsh";
        args = [ "-l" ];
      };
      colors = {
        primary = {
          background = "0x1f1f28";
          foreground = "0xdcd7ba";
        };
        normal = {
          black = "0x090618";
          red = "0xc34043";
          green = "0x76946a";
          yellow = "0xc0a36e";
          blue = "0x7e9cd8";
          magenta = "0x957fb8";
          cyan = "0x6a9589";
          white = "0xc8c093";
        };
        bright = {
          black = "0x727169";
          red = "0xe82424";
          green = "0x98bb6c";
          yellow = "0xe6c384";
          blue = "0x7fb4ca";
          magenta = "0x938aa9";
          cyan = "0x7aa89f";
          white = "0xdcd7ba";
        };
        selection = {
          background = "0x2d4f67";
          foreground = "0xc8c093";
        };
        indexed_colors = [
            {
              index = 16;
              color = "0xffa066";
            }
            {
              index = 17;
              color = "0xff5d62";
            }
          ];
        };
      hints.enabled = [
        {
          command = { program = "${open-in-nvim}"; };
          hyperlinks = false;
          post_processing = false;
          persist = false;
          regex = ''/?(?:[-\\w.@+]+/)+[-\\w.@+]+(?::\\d+){0,2}'';
          mouse = { enabled = true; mods = "Command|Shift"; };
          binding = { key = "O"; mods = "Command|Shift"; };
        }
      ];
      };
    };
  programs.zsh = {
    enable = true;
    envExtra = ''
      alias tmx='tmux attach || tmux new'

      if [[ -a ~/.nix-profile/lib/ah_aws.sh ]]; then
        source ~/.nix-profile/lib/ah_aws.sh
      fi
    '';
    initContent = ''
      source ~/.p10k.zsh
      bindkey "^[[1;3C" forward-word
      bindkey "^[[1;3D" backward-word
    '';
    plugins = [
      {
        # will source zsh-autosuggestions.plugin.zsh
        name = "zsh-autosuggestions";
        src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-autosuggestions";
          rev = "v0.7.0";
          sha256 = "KLUYpUu4DHRumQZ3w59m9aTW6TBKMCXl2UcKi4uMd7w=";
        };
      }
      {
        name = "powerlevel10k";
        src = pkgs.zsh-powerlevel10k;
        file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
      }
    ];
    oh-my-zsh = {
      enable = true;
      # theme = "bureau";
    };
  };

  programs.git = {
    enable = true;
    settings.alias = {
      co = "checkout";
      br = "branch";
      ci = "commit";
      st = "status";
    };
  };
}

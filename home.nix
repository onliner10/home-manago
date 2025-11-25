{ config, pkgs, lib, ... }:
let
  claude-code = (import ../../dotfiles/claude { pkgs = pkgs; nodejs = pkgs.nodejs_24; })."@anthropic-ai/claude-code";
  pkgsUnstable = import <nixpkgs-unstable> {
    config.allowUnfree = true;
    config.allowUnfreePredicate = _: true;
  };
in
{
  imports = [
    ./local.nix
    ./vim.nix
  ];
  nixpkgs = {
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.05"; # Please read the comment before changing.


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
    pkgs.dasht
    pkgs.nodejs_24
    pkgs.git
    pkgs.git-lfs
    pkgs.httpie
    pkgs.node2nix
    claude-code
    pkgs.zellij
    pkgsUnstable.gemini-cli
    # pkgsUnstable.claude-code

    # # I-- t is sometimes useful to fine-tune packages, for example, by applying
    # # o-- verrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/mateusz.urban/etc/profile.d/hm-session-vars.sh
  #

  # Let Home Manager install and manage itself.
  # programs.tmux.shell = "${pkgs.zsh}/bin/zsh";
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
      shell.program = "${pkgs.zsh}/bin/zsh";
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
      };
    };
  programs.zsh = {
    enable = true;
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

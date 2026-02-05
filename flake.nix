{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code-overlay.url = "github:ryoppippi/claude-code-overlay";
  };

  outputs = { nixpkgs, home-manager, claude-code-overlay, ... }:
    let
      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        config.allowUnfreePredicate = _: true;
        overlays = [ claude-code-overlay.overlays.default ];
      };
      mkHome = system: modules: home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs system;
        inherit modules;
      };
    in {
      homeConfigurations."mateusz.urban" = mkHome "aarch64-darwin" [ ./darwin.nix ];
      homeConfigurations."mateusz.urban@linux" = mkHome "x86_64-linux" [ ./home.nix ];
    };
}

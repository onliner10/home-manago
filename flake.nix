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
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        config.allowUnfreePredicate = _: true;
        overlays = [ claude-code-overlay.overlays.default ];
      };
    in {
      homeConfigurations."mateusz.urban" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
      };
    };
}

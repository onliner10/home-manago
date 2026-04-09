{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, home-manager, ... }:
    let
      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        config.allowUnfreePredicate = _: true;
      };
      mkUnstable = system: import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
        config.allowUnfreePredicate = _: true;
      };
      mkHome = system: { username, homeDirectory, modules }:
        let
          localNixPath = /. + "${homeDirectory}/.config/home-manager/local.nix";
          localModules = if builtins.pathExists localNixPath then [ localNixPath ] else [];
        in home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system;
          extraSpecialArgs = {
            unstable = mkUnstable system;
          };
          modules = modules ++ localModules ++ [{
            home.username = username;
            home.homeDirectory = homeDirectory;
          }];
        };
    in {
      homeConfigurations."mateusz.urban" = mkHome "aarch64-darwin" {
        username = "mateusz.urban";
        homeDirectory = "/Users/mateusz.urban";
        modules = [ ./darwin.nix ];
      };
      homeConfigurations."mateusz.urban@linux" = mkHome "x86_64-linux" {
        username = "mateusz.urban";
        homeDirectory = "/home/mateusz.urban";
        modules = [ ./home.nix ];
      };
    };
}

{
  description = "Aether Linux NixOS Sprint 0 ISO experiment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      mkConfig = modules: nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./configuration/base.nix ] ++ modules;
      };
      iso = mkConfig [ (nixpkgs.outPath + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix") ];
    in {
      nixosConfigurations = {
        minimal = mkConfig [ ];
        gnome = mkConfig [ ./desktop/gnome.nix ];
        plasma = mkConfig [ ./desktop/plasma.nix ];
        hyprland = mkConfig [ ./desktop/hyprland.nix ];
        dev-tools = mkConfig [ ./developers/dev-tools.nix ];
        aether-iso = iso;
      };
      packages.${system}.nixos-iso = iso.config.system.build.isoImage;
    };
}

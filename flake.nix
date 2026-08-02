{
  description = "Catapult launcher for Cataclysm: DDA/BN - NixOS package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
          catapult = import ./default.nix { inherit pkgs; };
        in
        {
          default = catapult.package;
          catapult = catapult.package;
          desktop = catapult.desktopItem;
        }
      );

      overlays.default = import ./overlay.nix;

      # NixOS module: References the already built packages from outputs.
      # This prevents redundant evaluations (re-importing default.nix) and keeps it clean.
      nixosModules.default = { pkgs, ... }: {
        environment.systemPackages = [
          self.packages.${pkgs.system}.default
          self.packages.${pkgs.system}.desktop
        ];
      };

      # Home Manager module: Same optimization as above.
      homeManagerModules.default = { pkgs, ... }: {
        home.packages = [
          self.packages.${pkgs.system}.default
          self.packages.${pkgs.system}.desktop
        ];
      };
    };
}
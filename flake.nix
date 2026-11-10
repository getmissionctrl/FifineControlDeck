{
  description = "fifine Control Deck for Linux: app for the fifine / Mirabox Stream Dock (USB 3142:0060)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ]; # libtransport.so is prebuilt; arm64 not wired up yet
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAll (pkgs: rec {
        fifine-control-deck = pkgs.callPackage ./nix/package.nix { };
        default = fifine-control-deck;
      });

      overlays.default = final: _prev: {
        fifine-control-deck = final.callPackage ./nix/package.nix { };
      };

      nixosModules.default = import ./nix/module.nix self;
    };
}

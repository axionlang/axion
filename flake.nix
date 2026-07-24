{
  description = "Axión — Fase 0: protótipo EDSL descartável (validação semântica de linearidade sobre Linear Haskell)";

  # Nixpkgs estável, bem servido pelo binary cache (cache.nixos.org).
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      devShells = forAllSystems (pkgs:
        let
          # Dependências Haskell do protótipo, embutidas no GHC para build offline.
          ghcDeps = hp: [
            hp.linear-base
            hp.vector
            hp.tasty
            hp.tasty-quickcheck
            hp.tasty-hunit
          ];
          ghc = pkgs.haskellPackages.ghcWithPackages ghcDeps;
        in {
          default = pkgs.mkShell {
            name = "axion-fase0";
            packages = [
              ghc
              pkgs.cabal-install
              pkgs.haskellPackages.fourmolu
              pkgs.hlint
              pkgs.haskell-language-server
            ];
            shellHook = ''
              echo "Axión · Fase 0 — dev shell (GHC $(ghc --numeric-version), LinearTypes + linear-base)"
              echo "  cabal build   ·   cabal test   ·   ./scripts/check-negative.sh"
            '';
          };
        });
    };
}

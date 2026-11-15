{
  description = "Axion — Phase 0: disposable EDSL prototype (semantic validation of linearity over Linear Haskell)";

  # Stable nixpkgs, well served by the binary cache (cache.nixos.org).
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      devShells = forAllSystems (pkgs:
        let
          # The prototype's Haskell dependencies, embedded in GHC for offline builds.
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
            # SDL and FFmpeg for media and graphics FFI: added to buildInputs so their
            # lib dirs reach NIX_LDFLAGS, and shellHook configures LIBRARY_PATH/LD_LIBRARY_PATH
            # so axionc links and bakes the rpath successfully.
            buildInputs = [ pkgs.SDL2 pkgs.SDL2_image pkgs.ffmpeg ];
            shellHook = ''
              export LIBRARY_PATH="${pkgs.SDL2}/lib:${pkgs.SDL2_image}/lib:${pkgs.ffmpeg}/lib''${LIBRARY_PATH:+:$LIBRARY_PATH}"
              export LD_LIBRARY_PATH="${pkgs.SDL2}/lib:${pkgs.SDL2_image}/lib:${pkgs.ffmpeg}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
              echo "Axion · Phase 0 — dev shell (GHC $(ghc --numeric-version), LinearTypes + linear-base)"
              echo "  cabal build   ·   cabal test   ·   ./scripts/check-negative.sh"
              echo "  build aximv:  axionc -o aximv examples/aximv.axi"
              echo "  build axmpv:  axionc -o axmpv examples/axmpv.axi"
            '';
          };
        });
    };
}

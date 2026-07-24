#!/usr/bin/env bash
# Testes diferenciais (§17): cada cenário em differential/ tem de receber o
# MESMO veredito (accept/reject) do axionc E do oráculo GHC (bancada EDSL da
# Fase 0). Ancora o verificador de linearidade do axionc à referência do GHC.
#
# Correr:  ./scripts/differential.sh
set -uo pipefail
cd "$(dirname "$0")/.."

AXIONC="${AXIONC:-axionc/target/debug/axionc}"
if [ ! -x "$AXIONC" ]; then
  echo "a compilar o axionc..."
  (cd axionc && cargo build -q) || {
    echo "falha a compilar o axionc"
    exit 2
  }
fi

fail=0
total=0
for dir in differential/*/; do
  [ -f "$dir/expected" ] || continue
  name=$(basename "$dir")
  expected=$(cat "$dir/expected")
  total=$((total + 1))

  # veredito do axionc
  if "$AXIONC" --check "$dir/prog.axi" >/dev/null 2>&1; then
    axi=accept
  else
    axi=reject
  fi

  # veredito do GHC (oráculo EDSL), dentro do dev shell reprodutível
  if nix develop --command ghc -fno-code -XLinearTypes -iprototype/src \
      "$dir/Prog.hs" >/dev/null 2>&1; then
    ghc=accept
  else
    ghc=reject
  fi

  if [ "$axi" = "$expected" ] && [ "$ghc" = "$expected" ]; then
    echo "✓ $name: axionc=$axi · ghc=$ghc (esperado: $expected)"
  else
    echo "✗ $name: axionc=$axi · ghc=$ghc (esperado: $expected) — DIVERGE"
    fail=1
  fi
done

echo "---"
if [ "$fail" -eq 0 ]; then
  echo "OK: $total cenários, axionc e GHC concordam em todos."
else
  echo "FALHA: há divergência entre o axionc e o oráculo GHC."
fi
exit $fail

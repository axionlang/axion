#!/usr/bin/env bash
# Fase 0 — verificação do teste negativo.
#
# Compila prototype/test/negative/UseTwice.hs (um Buffer %1 usado duas vezes) e
# EXIGE que a compilação FALHE com um erro de multiplicidade/linearidade. É o
# análogo, na bancada, do diagnóstico AX0001 (uso-após-consumo).
#
# Correr dentro do dev shell:  nix develop -c ./scripts/check-negative.sh
set -uo pipefail
cd "$(dirname "$0")/.."

out=$(ghc -fno-code -XLinearTypes -iprototype/src \
        prototype/test/negative/UseTwice.hs 2>&1)
status=$?

if [ "$status" -eq 0 ]; then
  echo "✗ FALHA: UseTwice.hs COMPILOU — a linearidade não está a ser imposta!"
  echo "$out"
  exit 1
fi

if echo "$out" | grep -qiE "multiplicit|linear|consumed|used more than once"; then
  echo "✓ OK: uso duplo de 'Buffer %1' rejeitado pelo typechecker (análogo de AX0001)."
  exit 0
fi

echo "✗ FALHA: a compilação falhou, mas não pela razão esperada (linearidade)."
echo "--- saída do GHC ---"
echo "$out"
exit 1

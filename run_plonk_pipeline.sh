#!/usr/bin/env bash
set -euo pipefail
set -x   # show each command as it runs

# 1) Compile the circuit
echo "=== Compile circuit ==="
circom circuits/bgTrait.circom \
  --r1cs --wasm --sym \
  --output circuits \
  -l node_modules/circomlib/circuits

# 2) Inspect R1CS
echo "=== R1CS info ==="
npx snarkjs r1cs info circuits/bgTrait.r1cs

# 3) PLONK setup
echo "=== PLONK setup ==="
npx snarkjs plonk setup \
  circuits/bgTrait.r1cs \
  ptau/pot13_final.ptau \
  circuits/bgTrait.zkey

# 4) Export verification key
echo "=== Export VK ==="
npx snarkjs zkey export verificationkey \
  circuits/bgTrait.zkey \
  circuits/verification_key.json

# 5) Fullprove (witness + proof + public)
echo "=== PLONK fullprove ==="
npx snarkjs plonk fullprove \
  input.json \
  circuits/bgTrait_js/bgTrait.wasm \
  circuits/bgTrait.zkey \
  circuits/proof.json \
  circuits/public.json

# Debug: show how many public signals we got
echo "public.json length = $(jq length circuits/public.json)"

# 6) Verify proof structurally & logically
echo "=== PLONK verify ==="
npx snarkjs plonk verify \
  circuits/verification_key.json \
  circuits/public.json \
  circuits/proof.json \
  --verbose

# If the above succeeds, you’ll see “OK!” here.
echo "✅ Local PLONK verification passed."

# 7) Reorder for on-chain calldata
echo "=== Reorder public signals for Solidity ==="
jq -c '(.[-2:] + .[0:-2]) | map(tonumber)' \
  circuits/public.json > circuits/public_ready.json

echo "public_ready.json length = $(jq length circuits/public_ready.json)"
echo "✅ Pipeline completed. Ready to call your on-chain verifier with public_ready.json + proof.json"

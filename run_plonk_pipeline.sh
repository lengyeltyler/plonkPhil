#!/usr/bin/env bash
set -euo pipefail

# 0) MAKE SURE YOU'RE ON CIRCOM v2.2.2 and SNARKJS v0.7.5:
#    circom --version      # should print "circom compiler 2.2.2" :contentReference[oaicite:0]{index=0}
#    snarkjs --version    # should print "0.7.5"             :contentReference[oaicite:1]{index=1}

# 1) Compile the circuit (all outputs into `circuits/`)
circom circuits/bgTrait.circom \
  --r1cs --wasm --sym \
  --output circuits \
  -l node_modules/circomlib/circuits          # circomlib v2.0.5 :contentReference[oaicite:2]{index=2}

# 2) Run the PLONK setup (universal Ptau already in ptau/pot13_final.ptau)
snarkjs plonk setup \
  circuits/bgTrait.r1cs \
  ptau/pot13_final.ptau \
  circuits/bgTrait.zkey

# 3) Export the on-chain verifier key
snarkjs zkey export verificationkey \
  circuits/bgTrait.zkey \
  circuits/verification_key.json

# 4) Generate the witness
node circuits/bgTrait_js/generate_witness.js \
  circuits/bgTrait_js/bgTrait.wasm \
  input.json \
  circuits/witness.wtns

# 5) Create the proof
snarkjs plonk prove \
  circuits/bgTrait.zkey \
  circuits/witness.wtns \
  circuits/proof.json \
  circuits/public.json

# 6) Reorder & cast public signals (inputs first, then outputs; strings → numbers)
jq -c '(.[-2:] + .[0:-2]) | map(tonumber)' \
  circuits/public.json \
  > circuits/public_ready.json

# 7) Final verification
snarkjs plonk verify \
  circuits/verification_key.json \
  circuits/public_ready.json \
  circuits/proof.json

echo "✅ All PLONK steps completed successfully!"

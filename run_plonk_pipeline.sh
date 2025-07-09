#!/usr/bin/env bash
set -euo pipefail

echo
echo "🏗️  1) Compile the circuit into circuits/ …"
circom circuits/bgTrait.circom \
  --r1cs --wasm --sym \
  --output circuits \
  -l node_modules/circomlib/circuits

echo
echo "🛠️  2) Run the PLONK ceremony & export zkey …"
snarkjs plonk setup \
  circuits/bgTrait.r1cs \
  ptau/pot13_final.ptau \
  circuits/bgTrait.zkey

snarkjs zkey export verificationkey \
  circuits/bgTrait.zkey \
  circuits/verification_key.json

echo
echo "📸  3) Generate the witness …"
node circuits/bgTrait_js/generate_witness.js \
  circuits/bgTrait_js/bgTrait.wasm \
  input.json \
  circuits/witness.wtns

echo
echo "🤝 4) Create the proof & public signals …"
snarkjs plonk prove \
  circuits/bgTrait.zkey \
  circuits/witness.wtns \
  circuits/proof.json \
  circuits/public.json

echo
echo "✅ 5) Verify the proof …"
snarkjs plonk verify \
  circuits/verification_key.json \
  circuits/public.json \
  circuits/proof.json

echo
echo "📦 6) Export Solidity verifier to contracts/Verifier.sol …"
npx snarkjs zkey export solidityverifier \
  circuits/bgTrait.zkey \
  contracts/Verifier.sol

echo
echo "🎉 PLONK pipeline complete!"

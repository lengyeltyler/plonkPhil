# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
Compile and output everything into circuits/
circom circuits/bgTrait.circom \
  --r1cs --wasm --sym \
  --output circuits \
  -l node_modules/circomlib/circuits
Run the PLONK ceremony and export the verifier key
snarkjs plonk setup \
  circuits/bgTrait.r1cs \
  ptau/pot13_final.ptau \
  circuits/bgTrait.zkey

snarkjs zkey export verificationkey \
  circuits/bgTrait.zkey \
  circuits/verification_key.json

Generate the witness and proof
node circuits/bgTrait_js/generate_witness.js \
  circuits/bgTrait_js/bgTrait.wasm \
  input.json \
  circuits/witness.wtns

snarkjs plonk prove \
  circuits/bgTrait.zkey \
  circuits/witness.wtns \
  circuits/proof.json \
  circuits/public.json

Verify
snarkjs plonk verify \
  circuits/verification_key.json \
  circuits/public.json \
  circuits/proof.json

Clean out old proof artifacts
rm -f circuits/proof.json circuits/public.json circuits/public_ready.json circuits/witness.wtns

rm -rf \
  circuits/bgTrait.r1cs \
  circuits/bgTrait.sym \
  circuits/bgTrait_js \
  circuits/bgTrait.zkey \
  circuits/verification_key.json \
  circuits/witness.wtns \
  circuits/proof.json \
  circuits/public.json \
  circuits/public_ready.json

Make Executable
chmod +x run_plonk_pipeline.sh

Wipe out your old tau & zkey
rm -f ptau/pot12_*.ptau ptau/pot13_*.ptau

Phase 1: new ptau at power=13
snarkjs powersOfTau new bn128 13 ptau/pot13_0000.ptau

Contribute entropy
snarkjs powersOfTau contribute \
  ptau/pot13_0000.ptau \
  ptau/pot13_0000.ptau \
  --name="first contribution" \
  -e="some random text"

Phase 2: prepare the final file
snarkjs powersOfTau prepare phase2 \
  ptau/pot13_0000.ptau \
  ptau/pot13_final.ptau

Re-run the PLONK setup & proof pipeline in one pass
./run_plonk_pipeline.sh

```

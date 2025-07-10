plonkPhil
This repository demonstrates the use of zk-SNARKs with Circom and SnarkJS for generating on-chain NFTs on Ethereum. The process involves a Powers of Tau ceremony, circuit compilation, proof generation, and deployment via Hardhat.

Powers of Tau Ceremony
Initialize and contribute to the Powers of Tau setup for the trusted ceremony:

bash

Collapse

Unwrap

Run

Copy
snarkjs powersoftau new bn128 13 pot13_0000.ptau
snarkjs powersoftau contribute pot13_0000.ptau pot13_0001.ptau --name="First contribution"
snarkjs powersoftau prepare phase2 pot13_0001.ptau pot13_final.ptau
Note: For fresh setups, wipe old files first:

bash

Collapse

Unwrap

Run

Copy
rm -f ptau/pot12_*.ptau ptau/pot13_*.ptau
Then recreate:

bash

Collapse

Unwrap

Run

Copy
snarkjs powersoftau new bn128 13 ptau/pot13_0000.ptau
snarkjs powersoftau contribute ptau/pot13_0000.ptau ptau/pot13_0000.ptau --name="first contribution" -e="some random text"
snarkjs powersoftau prepare phase2 ptau/pot13_0000.ptau ptau/pot13_final.ptau
Circuit Compilation
Compile the Circom circuit (bgTrait.circom) and output artifacts to circuits/:

bash

Collapse

Unwrap

Run

Copy
circom circuits/bgTrait.circom --r1cs --wasm --sym --output circuits -l node_modules/circomlib/circuits
Note: Ensure Circomlib is installed:

bash

Collapse

Unwrap

Run

Copy
rm -rf circuits/circomlib
git clone https://github.com/iden3/circomlib.git circomlib
Verify installation:

bash

Collapse

Unwrap

Run

Copy
ls circuits/circomlib/circuits/bitify.circom
PLONK Setup and Verifier Key Export
Perform PLONK setup and export the verification key:

bash

Collapse

Unwrap

Run

Copy
snarkjs plonk setup circuits/bgTrait.r1cs ptau/pot13_final.ptau circuits/bgTrait.zkey
snarkjs zkey export verificationkey circuits/bgTrait.zkey circuits/verification_key.json
Generate Witness and Proof
Generate the witness and proof using input data:

bash

Collapse

Unwrap

Run

Copy
node circuits/bgTrait_js/generate_witness.js circuits/bgTrait_js/bgTrait.wasm input.json circuits/witness.wtns
snarkjs plonk prove circuits/bgTrait.zkey circuits/witness.wtns circuits/proof.json circuits/public.json
Verify Proof
Verify the generated proof offline:

bash

Collapse

Unwrap

Run

Copy
snarkjs plonk verify circuits/verification_key.json circuits/public.json circuits/proof.json
Export Solidity Verifier
Export the Solidity verifier contract:

bash

Collapse

Unwrap

Run

Copy
npx snarkjs zkey export solidityverifier circuits/bgTrait.zkey contracts/Verifier.sol
Note: Rename PlonkVerifier.sol to Verifier.sol if necessary.

Run Hardhat Node and Deploy/Mint
Start a local Hardhat node and deploy/mint the NFT:

bash

Collapse

Unwrap

Run

Copy
npx hardhat node
npx hardhat run scripts/deploy.js --network localhost
npx hardhat run scripts/mint.js --network localhost
Re-run PLONK Setup and Proof Pipeline
For automated re-runs, make the script executable and execute:

bash

Collapse

Unwrap

Run

Copy
chmod +x run_plonk_pipeline.sh
./run_plonk_pipeline.sh
Then redeploy and mint:

bash

Collapse

Unwrap

Run

Copy
npx hardhat run scripts/deploy.js --network localhost
npx hardhat run scripts/mint.js --network localhost
Cleanup Old Proof Artifacts
Clean up generated files after runs:

bash

Collapse

Unwrap

Run

Copy
rm -f circuits/proof.json circuits/public.json circuits/public_ready.json circuits/witness.wtns
rm -rf circuits/bgTrait.r1cs circuits/bgTrait.sym circuits/bgTrait_js circuits/bgTrait.zkey circuits/verification_key.json circuits/witness.wtns circuits/proof.json circuits/public.json circuits/public_ready.json
rm -rf onchain_svg.svg minted_tokenURI.txt contracts/Verifier.sol
Note: This ensures a clean slate for subsequent builds. Always back up important files before cleanup.

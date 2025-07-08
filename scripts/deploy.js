const { ethers } = require("hardhat");

async function main() {
  // 1️⃣ Deploy the PLONK verifier
  const Verifier = await ethers.getContractFactory("Verifier");
  const verifier = await Verifier.deploy();
  await verifier.waitForDeployment();
  const verifierAddress = await verifier.getAddress();
  console.log("Verifier deployed to:", verifierAddress);

  // 2️⃣ Deploy your RiscVzkVM, pointing at the verifier
  const RiscVzkVM = await ethers.getContractFactory("RiscVzkVM");
  const riscVzkVM = await RiscVzkVM.deploy(verifierAddress);
  await riscVzkVM.waitForDeployment();
  const riscVzkVMAddress = await riscVzkVM.getAddress();
  console.log("RiscVzkVM deployed to:", riscVzkVMAddress);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

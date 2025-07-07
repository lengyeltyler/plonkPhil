const { ethers } = require("hardhat");

async function main() {
    const Verifier = await ethers.getContractFactory("Verifier");
    const verifier = await Verifier.deploy();
    await verifier.waitForDeployment();
    console.log("Verifier deployed to:", await verifier.getAddress());

    const RiscVzkVM = await ethers.getContractFactory("RiscVzkVM");
    const riscVzkVM = await RiscVzkVM.deploy(verifier.target); // Correctly pass address to constructor
    await riscVzkVM.waitForDeployment();
    console.log("RiscVzkVM deployed to:", await riscVzkVM.getAddress());
}

main().catch((err) => {
    console.error(err);
    process.exit(1);
});
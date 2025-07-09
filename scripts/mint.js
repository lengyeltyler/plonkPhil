// scripts/mint.js

const { ethers } = require("hardhat");
const { plonk }  = require("snarkjs");
const fs        = require("fs");
const axios     = require("axios");

async function getEthPrice() {
  try {
    const { data } = await axios.get(
      "https://api.etherscan.io/api?module=stats&action=ethprice&apikey=MF1UH981PQBWJXHNWNQW6AAX3A3ERVGYGH"
    );
    return parseFloat(data.result.ethusd);
  } catch (e) {
    console.warn("ETH price fetch failed:", e.message);
    return 2000;
  }
}

async function getGasPrice() {
  try {
    const { data } = await axios.get(
      "https://api.etherscan.io/api?module=gastracker&action=gasoracle&apikey=MF1UH981PQBWJXHNWNQW6AAX3A3ERVGYGH"
    );
    return Math.floor(parseFloat(data.result.ProposeGasPrice) * 1e9);
  } catch (e) {
    console.warn("Gas price fetch failed:", e.message);
    return BigInt(20e9);
  }
}

async function main() {
  const CONTRACT = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
  const nft      = await ethers.getContractAt("RiscVzkVM", CONTRACT);

  const input = { tokenId: 10, seed: 20 };

  console.log("⏳ Generating PLONK proof…");
  const { proof, publicSignals } = await plonk.fullProve(
    input,
    "circuits/bgTrait_js/bgTrait.wasm",
    "circuits/bgTrait.zkey"
  );
  console.log("✅ Proof & public signals ready");
  console.log("→ publicSignals.length:", publicSignals.length);

  // —— DEBUG: inspect the raw spiral outputs —— 
  const rawXs = publicSignals.slice(5, 5 + 32).map(n => parseInt(n));
  const rawYs = publicSignals.slice(37, 37 + 32).map(n => parseInt(n));
  console.log("🔍 raw circleX inputs:", rawXs);
  console.log("🔍 raw circleY inputs:", rawYs);
  // **********************************************

  // build calldata for Solidity
  const fullCalldata = await plonk.exportSolidityCallData(proof, publicSignals);
  let proofJson, signalsJson;
  if (fullCalldata.includes("][")) {
    [proofJson, signalsJson] = fullCalldata.split("][");
    proofJson   += "]";
    signalsJson  = "[" + signalsJson;
  } else {
    const idx = fullCalldata.indexOf(",");
    proofJson   = fullCalldata.slice(0, idx);
    signalsJson = fullCalldata.slice(idx + 1);
  }

  const proofArr   = JSON.parse(proofJson);
  const proofBytes = "0x" + proofArr.map(h => h.slice(2)).join("");
  const signalsArr = JSON.parse(signalsJson);

  // ─── Estimate gas & cost ─────────────────────────────
  const gasPriceNum = await getGasPrice();
  const ethPrice    = await getEthPrice();
  // estimateGas returns a BigInt
  const gasEst      = await nft.mintNFT.estimateGas(proofBytes, signalsArr);
  console.log("Estimated gas:", gasEst.toString());

  const estCostWei  = gasEst * BigInt(gasPriceNum);
  const estCostEth  = ethers.formatEther(estCostWei);
  console.log(
    `Est. cost: ${estCostEth} ETH (~$${(parseFloat(estCostEth) * ethPrice).toFixed(2)} USD)`
  );

  // ─── Actually mint ────────────────────────────────────
  const tx = await nft.mintNFT(proofBytes, signalsArr, { gasLimit: 15_000_000 });
  console.log("✅ Mint tx hash:", tx.hash);
  const receipt = await tx.wait();

  // ─── Actual cost ──────────────────────────────────────
  const actualCostWei = receipt.gasUsed * BigInt(gasPriceNum);
  const actualCostEth = ethers.formatEther(actualCostWei);
  console.log(
    `Actual gasUsed: ${receipt.gasUsed.toString()}, cost: ${actualCostEth} ETH (~$${(parseFloat(actualCostEth) * ethPrice).toFixed(2)} USD)`
  );

  // ─── Handle Minted event ──────────────────────────────
  for (const log of receipt.logs) {
    try {
      const parsed = nft.interface.parseLog(log);
      if (parsed.name === "Minted") {
        console.log("🎉 Minted Event:", {
          tokenId: parsed.args.tokenId.toString(),
          owner:   parsed.args.owner,
        });
        fs.writeFileSync("minted_tokenURI.txt", parsed.args.tokenURI);
      }
    } catch {}
  }

  // ─── Decode the SVG ──────────────────────────────────
  const latest = await nft.tokenIdCounter();
  const last   = latest - 1n;
  console.log("Latest tokenId:", latest.toString());
  console.log("Owner of", last.toString(), ":", await nft.ownerOf(last));

  const tokenURI = await nft.tokenURI(last);
  console.log("Raw tokenURI:", tokenURI);

  const meta    = JSON.parse(tokenURI);
  const dataUri = meta.image;
  const svgBase = dataUri.split(",")[1];
  const svg     = Buffer.from(svgBase, "base64").toString();
  fs.writeFileSync("onchain_svg.svg", svg);
  console.log("✅ onchain_svg.svg written");
}

main().catch((e) => {
  console.error("ERROR in mint.js:", e);
  process.exit(1);
});

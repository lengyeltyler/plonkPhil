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
    return 20e9;
  }
}

async function main() {
  // ←– update this to your deployed RiscVzkVM address
  const CONTRACT = "0x610178dA211FEF7D417bC0e6FeD39F05609AD788";
  const nft      = await ethers.getContractAt("RiscVzkVM", CONTRACT);

  const input = { tokenId: 10, seed: 20 };

  console.log("⏳ Generating PLONK proof…");
  const { proof, publicSignals } = await plonk.fullProve(
    input,
    "circuits/bgTrait_js/bgTrait.wasm",
    "circuits/bgTrait.zkey"
  );
  console.log("✅ Proof & public signals ready");

  const fullCalldata = await plonk.exportSolidityCallData(proof, publicSignals);

  let proofJson, signalsJson;
  if (fullCalldata.includes("][")) {
    const [first, second] = fullCalldata.split("][");
    proofJson   = first + "]";
    signalsJson = "[" + second;
  } else {
    const idx       = fullCalldata.indexOf(",");
    proofJson       = fullCalldata.slice(0, idx);
    signalsJson     = fullCalldata.slice(idx + 1);
  }

  // build the proof bytes
  let proofBytes;
  try {
    const proofArr = JSON.parse(proofJson);
    proofBytes = "0x" + proofArr.map(h => h.slice(2)).join("");
  } catch (e) {
    console.error("Bad JSON for proof:", proofJson);
    throw e;
  }

  // parse the public signals array
  let signalsArr;
  try {
    signalsArr = JSON.parse(signalsJson);
  } catch (e) {
    console.error("Bad JSON for signals:", signalsJson);
    throw e;
  }

  console.log("Proof bytes length:", proofBytes.length);
  console.log("Signals count:", signalsArr.length);

  // ─── Estimate gas & cost ─────────────────────────────
  const gasPriceNum = await getGasPrice();
  const ethPrice    = await getEthPrice();
  const gasEst      = await nft.mintNFT.estimateGas(proofBytes, signalsArr);
  console.log("Estimated gas:", gasEst.toString());

  const estCostWei = BigInt(gasEst) * BigInt(gasPriceNum);
  const estCostEth = ethers.formatEther(estCostWei);
  console.log(
    `Est. cost: ${estCostEth} ETH (~$${(parseFloat(estCostEth) * ethPrice).toFixed(2)} USD)`
  );

  // ─── Actually mint ────────────────────────────────────
  const tx = await nft.mintNFT(proofBytes, signalsArr, { gasLimit: 15_000_000 });
  console.log("✅ Mint tx hash:", tx.hash);
  const receipt = await tx.wait();

  // ─── Actual cost ──────────────────────────────────────
  const actualCostWei = BigInt(receipt.gasUsed) * BigInt(gasPriceNum);
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

  // ─── Inspect on-chain state ───────────────────────────
  const latest = await nft.tokenIdCounter(); // returns native BigInt
  const last   = latest - 1n;
  console.log("Latest tokenId:", latest.toString());
  console.log("Owner of", last.toString(), ":", await nft.ownerOf(last));

  const tokenURI = await nft.tokenURI(last);
  console.log("Raw tokenURI:", tokenURI);

  // ─── Decode the SVG ────────────────────────────────────
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

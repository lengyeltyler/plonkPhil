const { ethers } = require("hardhat");
const { groth16 } = require("snarkjs");
const fs = require("fs");
const axios = require("axios");

async function getEthPrice() {
    try {
        const response = await axios.get(
            "https://api.etherscan.io/api?module=stats&action=ethprice&apikey=MF1UH981PQBWJXHNWNQW6AAX3A3ERVGYGH"
        );
        return parseFloat(response.data.result.ethusd);
    } catch (error) {
        console.error("Failed to fetch ETH price:", error.message);
        return 2000; // fallback
    }
}

async function getGasPrice() {
    try {
        const response = await axios.get(
            "https://api.etherscan.io/api?module=gastracker&action=gasoracle&apikey=MF1UH981PQBWJXHNWNQW6AAX3A3ERVGYGH"
        );
        return parseFloat(response.data.result.ProposeGasPrice) * 1e9; // Gwei → Wei
    } catch (error) {
        console.error("Failed to fetch gas price:", error.message);
        return 20e9; // fallback
    }
}

function parseCalldata(calldata) {
    const argv = calldata
        .replace(/["[\]\s]/g, "")
        .split(',')
        .map(x => BigInt(x));

    const a = [argv[0], argv[1]];
    const b = [
        [argv[2], argv[3]],
        [argv[4], argv[5]]
    ];
    const c = [argv[6], argv[7]];
    const signals = argv.slice(8);
    return [a, b, c, signals];
}

async function main() {
    // ─── UPDATE THIS to your new RiscVzkVM address ───
    const contractAddress = "0xB581C9264f59BF0289fA76D61B2D0746dCE3C30D";
    const nftContract = await ethers.getContractAt("RiscVzkVM", contractAddress);

    const input = {
        tokenId: 10,
        seed: 20
    };

    const { proof, publicSignals } = await groth16.fullProve(
        input,
        "circuits/bgTrait_js/bgTrait.wasm",
        "circuits/zkeys/bgTrait_0001.zkey"
    );

    console.log("Public Signals:", publicSignals);

    const calldata = await groth16.exportSolidityCallData(proof, publicSignals);
    const [a, b, c, signalsBigInt] = parseCalldata(calldata);

    try {
        const gasEstimate = await nftContract.mintNFT.estimateGas(a, b, c, signalsBigInt);
        console.log("Estimated gas:", gasEstimate.toString());

        const gasPrice = await getGasPrice();
        const ethPrice = await getEthPrice();

        const gasEstimateBigInt = BigInt(gasEstimate.toString());
        const gasCostEth = ethers.formatEther(gasEstimateBigInt * BigInt(Math.floor(gasPrice)));
        const gasCostUsd = parseFloat(gasCostEth) * ethPrice;
        console.log(`Gas cost: ${gasCostEth} ETH (~$${gasCostUsd.toFixed(2)} USD)`);

        const tx = await nftContract.mintNFT(a, b, c, signalsBigInt, { gasLimit: 15_000_000 });
        const receipt = await tx.wait();
        console.log("NFT minted! Transaction hash:", receipt.hash);

        const gasUsedBigInt = BigInt(receipt.gasUsed.toString());
        const actualGasCostEth = ethers.formatEther(gasUsedBigInt * BigInt(Math.floor(gasPrice)));
        const actualGasCostUsd = parseFloat(actualGasCostEth) * ethPrice;
        console.log(`Actual gas used: ${receipt.gasUsed}, Cost: ${actualGasCostEth} ETH (~$${actualGasCostUsd.toFixed(2)} USD)`);

        for (const log of receipt.logs) {
            try {
                const parsedLog = nftContract.interface.parseLog(log);
                if (parsedLog && parsedLog.name === "Minted") {
                    console.log("Minted Event:", {
                        tokenId: parsedLog.args.tokenId.toString(),
                        owner: parsedLog.args.owner,
                        tokenURI: parsedLog.args.tokenURI
                    });
                    fs.writeFileSync("minted_tokenURI.txt", parsedLog.args.tokenURI);
                    console.log("Minted tokenURI saved to minted_tokenURI.txt");
                }
            } catch (_) {}
        }

        const latestTokenId = await nftContract.tokenIdCounter();
        console.log("Latest tokenId:", latestTokenId.toString());

        const tokenIdToCheck = latestTokenId - 1n;
        const owner = await nftContract.ownerOf(Number(tokenIdToCheck));
        console.log("Owner of token ID", tokenIdToCheck.toString(), ":", owner);

const tokenURI = await nftContract.tokenURI(Number(tokenIdToCheck));
        console.log("Token URI:", tokenURI);

        // ← Fix: parse the JSON string, then pull out the image data URI
        const metadata = JSON.parse(tokenURI);
        const dataUri = metadata.image;                              // "data:image/svg+xml;base64,PHN2Zy…"
        const svgBase64 = dataUri.split(",")[1];                     // everything after the comma
        const svg = Buffer.from(svgBase64, "base64").toString();    // now a valid SVG string
        console.log("SVG:", svg);
        fs.writeFileSync("onchain_svg.svg", svg);
        console.log("On-chain SVG saved to onchain_svg.svg");

    } catch (error) {
        console.error("Error in mintNFT:", error);
        if (error.reason) console.log("Revert reason:", error.reason);
    }
}

main().catch((err) => {
    console.error("Main error:", err);
    process.exit(1);
});
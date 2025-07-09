// RiscVzkVM.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";
import "./Verifier.sol";

contract RiscVzkVM is ERC721URIStorage {
    Verifier public verifier;
    uint256 private _tokenIdCounter;

    // unchanged…
    string constant HEADER =
        "<svg width='420' height='420' viewBox='0 0 420 420' "
        "xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink'>"
        "<rect width='420' height='420' fill='#900'/>"
        "<defs>"
          "<radialGradient id='sunG' cx='50%' cy='50%' r='30%' fx='50%' fy='50%'>"
            "<stop offset='0%' stop-color='yellow'/>"
            "<stop offset='100%' stop-color='orange'/>"
          "</radialGradient>"
        "</defs>";

    string constant FOOTER = "</svg>";
    string constant CIRCLE_PREF  = "<circle cx='";
    string constant CIRCLE_MID1  = "' cy='";
    string constant CIRCLE_MID2  = "' r='";
    string constant CIRCLE_SUFF  = "' fill='url(#sunG)' fill-opacity='0.8' stroke='rgba(31,163,132,0)'/>";

    event Minted(uint256 indexed tokenId, address indexed owner, string tokenURI);

    constructor(address verifierAddress) ERC721("PhilNFT", "PNFT") {
        console.log("Deploying RiscVzkVM with verifier:", verifierAddress);
        verifier = Verifier(verifierAddress);
    }

    function _decodeProof(bytes calldata proof) internal pure returns (uint256[24] memory arr) {
        require(proof.length == 24 * 32, "Proof must be 768 bytes");
        for (uint256 i = 0; i < 24; ++i) {
            uint256 word;
            assembly { word := calldataload(add(proof.offset, mul(i, 32))) }
            arr[i] = word;
        }
    }

    function tokenIdCounter() public view returns (uint256) {
        console.log("tokenIdCounter called, returning:", _tokenIdCounter);
        return _tokenIdCounter;
    }

    function mintNFT(bytes calldata proof, uint256[] calldata pubSignals) external {
        require(pubSignals.length == 69, "Input must be length 69");

        // verify proof…
        uint256[24] memory decodedProof = _decodeProof(proof);
        uint256[69] memory pubSignalsFixed;
        for (uint256 i = 0; i < 69; ++i) pubSignalsFixed[i] = pubSignals[i];
        require(verifier.verifyProof(decodedProof, pubSignalsFixed), "Invalid proof");

        // mint…
        uint256 tokenId = _tokenIdCounter++;
        string memory svg = generateSVG(pubSignals);
        string memory img = Base64.encode(bytes(svg));
        string memory json = string(
            abi.encodePacked(
                '{"name":"Phil NFT #', Strings.toString(tokenId),
                '","description":"On-chain SVG NFT with zk-SNARK spiral arms",',
                '"image":"data:image/svg+xml;base64,', img, '"}'
            )
        );

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, json);
        emit Minted(tokenId, msg.sender, json);
    }

    function generateSVG(uint256[] calldata pub) internal pure returns (string memory) {
        bytes memory head = bytes(HEADER);
        bytes memory foot = bytes(FOOTER);
        uint256 dyn = _calcDynamicLen(pub);
        uint256 total = head.length + dyn + foot.length;
        bytes memory buf = new bytes(total);
        uint256 ptr = 0;

        // header
        for (uint256 i = 0; i < head.length; ++i) buf[ptr++] = head[i];

        // ── IMPORTANT: pull the correct slots ───────────────────────
        // pub[0]=tokenId,1=seed,2..4=rgb,5..25=circleX,26..46=circleY,47=opacity,48..68=radius
        for (uint256 i = 0; i < 21; ++i) {
            uint256 xRaw = pub[5  + i];           // ← circleX[i]
            uint256 yRaw = pub[26 + i];           // ← circleY[i]
            uint256 rRaw = pub[48 + i];           // ← radius[i]

            uint256 x = (xRaw * 420) / 12000;
            uint256 y = (yRaw * 420) / 12000;
            uint256 r = (rRaw * 420) / 12000;     // now matches canvas scale

            // build the <circle/>
            bytes memory a = bytes(CIRCLE_PREF);
            bytes memory xb = bytes(Strings.toString(x));
            bytes memory b = bytes(CIRCLE_MID1);
            bytes memory yb = bytes(Strings.toString(y));
            bytes memory c = bytes(CIRCLE_MID2);
            bytes memory rb = bytes(Strings.toString(r));
            bytes memory d = bytes(CIRCLE_SUFF);

            for (uint256 j = 0; j < a.length; ++j) buf[ptr++] = a[j];
            for (uint256 j = 0; j < xb.length; ++j) buf[ptr++] = xb[j];
            for (uint256 j = 0; j < b.length; ++j) buf[ptr++] = b[j];
            for (uint256 j = 0; j < yb.length; ++j) buf[ptr++] = yb[j];
            for (uint256 j = 0; j < c.length; ++j) buf[ptr++] = c[j];
            for (uint256 j = 0; j < rb.length; ++j) buf[ptr++] = rb[j];
            for (uint256 j = 0; j < d.length; ++j) buf[ptr++] = d[j];
        }

        // footer
        for (uint256 i = 0; i < foot.length; ++i) buf[ptr++] = foot[i];
        return string(buf);
    }

    function _calcDynamicLen(uint256[] calldata pub) internal pure returns (uint256 len) {
        for (uint256 i = 0; i < 21; ++i) {
            uint256 x = (pub[5  + i] * 420) / 12000;
            uint256 y = (pub[26 + i] * 420) / 12000;
            uint256 r = (pub[48 + i] * 420) / 12000;

            len += bytes(CIRCLE_PREF).length;
            len += bytes(Strings.toString(x)).length;
            len += bytes(CIRCLE_MID1).length;
            len += bytes(Strings.toString(y)).length;
            len += bytes(CIRCLE_MID2).length;
            len += bytes(Strings.toString(r)).length;
            len += bytes(CIRCLE_SUFF).length;
        }
    }
}

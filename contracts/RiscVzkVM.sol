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

    int16[15] private cosTable = [
        int16(10000),  int16(9063),  int16(7071),  int16(4226),  int16(0),
        int16(-4226),  int16(-7071), int16(-9063), int16(-10000),int16(-9063),
        int16(-7071),  int16(-4226), int16(0),     int16(4226),  int16(7071)
    ];
    int16[15] private sinTable = [
        int16(0),     int16(4226),  int16(7071),  int16(9063),   int16(10000),
        int16(9063),  int16(7071),  int16(4226),  int16(0),      int16(-4226),
        int16(-7071), int16(-9063), int16(-10000),int16(-9063),  int16(-7071)
    ];

    string constant HEADER =
        "<svg width='420' height='420' viewBox='0 0 420 420' "
        "xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink'>"
        "<defs>"
        "<radialGradient id='sunG' cx='50%' cy='50%' r='30%' fx='50%' fy='50%'>"
        "<stop offset='0%' stop-color='yellow'/><stop offset='100%' stop-color='orange'/>"
        "</radialGradient>"
        "<symbol id='c' viewBox='-6 -6 12 12'>"
        "<path d='m-6,0 a6,6 0 1,0 12,0 a6,6 0 1,0 -12,0'/>"
        "</symbol>"
        "</defs>"
        "<path d='M0,0h420v420h-420Z' fill='black'/>";

    string constant FOOTER    = "</svg>";
    string constant USE_PREF  = "<use xlink:href='#c' x='";
    string constant USE_MID   = "' y='";
    string constant USE_SUFF  = "' fill='url(#sunG)' fill-opacity='0.8'/>";

    event Minted(uint256 indexed tokenId, address indexed owner, string tokenURI);

    constructor(address verifierAddress) ERC721("PhilNFT", "PNFT") {
        console.log("Deploying RiscVzkVM with verifier:", verifierAddress);
        verifier = Verifier(verifierAddress);
    }

    /// @dev Decode bytes proof into uint256[24] memory for verifier
    function _decodeProof(bytes calldata proof) internal pure returns (uint256[24] memory arr) {
        require(proof.length == 24 * 32, "Proof must be 768 bytes");
        for (uint256 i = 0; i < 24; ++i) {
            uint256 word;
            assembly {
                word := calldataload(add(proof.offset, mul(i, 32)))
            }
            arr[i] = word;
        }
    }

    function tokenIdCounter() public view returns (uint256) {
        console.log("tokenIdCounter called, returning:", _tokenIdCounter);
        return _tokenIdCounter;
    }

    /// @param proof The serialized PLONK proof bytes
    /// @param pubSignals The 48 public signals from bgTrait.circom
    function mintNFT(
        bytes calldata proof,
        uint256[] calldata pubSignals
    ) external {
        require(pubSignals.length == 48, "Input must be length 48");
        uint256[24] memory decodedProof = _decodeProof(proof);
        // Convert pubSignals from dynamic array to fixed-size array
        uint256[48] memory fixedPubSignals;
        for (uint256 i = 0; i < 48; ++i) {
            fixedPubSignals[i] = pubSignals[i];
        }
        require(
            verifier.verifyProof(decodedProof, fixedPubSignals),
            "Invalid proof"
        );

        uint256 tokenId = _tokenIdCounter++;
        string memory svgImage = generateSVG(pubSignals);
        string memory base64Image = Base64.encode(bytes(svgImage));

        string memory json = string(
            abi.encodePacked(
                '{"name":"Phil NFT #', Strings.toString(tokenId),
                '","description":"On-chain SVG NFT with zk-SNARK vortex + arms",',
                '"image":"data:image/svg+xml;base64,', base64Image, '"}'
            )
        );

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, json);
        emit Minted(tokenId, msg.sender, json);
    }

    /// @dev Build the SVG string, using the length of pubSignals for the spiral
    function generateSVG(
        uint256[] calldata pubSignals
    ) internal view returns (string memory) {
        bytes memory headerBytes = bytes(HEADER);
        bytes memory footerBytes = bytes(FOOTER);
        uint256 dynamicLen = _calcDynamicLen(pubSignals);
        uint256 totalLen = headerBytes.length + dynamicLen + footerBytes.length;

        bytes memory buf = new bytes(totalLen);
        uint256 ptr = 0;

        // Copy header
        for (uint256 i = 0; i < headerBytes.length; ++i) {
            buf[ptr++] = headerBytes[i];
        }

        // Draw spiral circles
        uint256 step = pubSignals.length - 1;
        for (uint256 i = 0; i < pubSignals.length; ++i) {
            uint256 rScaled = (210 * i) / step;
            int256 xOff = (cosTable[i % cosTable.length] * int256(rScaled)) / 10000;
            int256 yOff = (sinTable[i % sinTable.length] * int256(rScaled)) / 10000;
            int256 xCoord = int256(210) + xOff;
            int256 yCoord = int256(210) + yOff;

            // <use x='…' y='…' …/>
            bytes memory p = bytes(USE_PREF);
            for (uint256 j = 0; j < p.length; ++j) buf[ptr++] = p[j];
            bytes memory xb = bytes(Strings.toString(uint256(xCoord < 0 ? 0 : uint256(xCoord))));
            for (uint256 j = 0; j < xb.length; ++j) buf[ptr++] = xb[j];
            bytes memory m = bytes(USE_MID);
            for (uint256 j = 0; j < m.length; ++j) buf[ptr++] = m[j];
            bytes memory yb = bytes(Strings.toString(uint256(yCoord < 0 ? 0 : uint256(yCoord))));
            for (uint256 j = 0; j < yb.length; ++j) buf[ptr++] = yb[j];
            bytes memory s = bytes(USE_SUFF);
            for (uint256 j = 0; j < s.length; ++j) buf[ptr++] = s[j];
        }

        // Copy footer
        for (uint256 i = 0; i < footerBytes.length; ++i) {
            buf[ptr++] = footerBytes[i];
        }

        return string(buf);
    }

    /// @dev Precompute total length of all `<use>` elements
    function _calcDynamicLen(
        uint256[] calldata pubSignals
    ) internal view returns (uint256 dynamicLen) {
        uint256 step = pubSignals.length - 1;
        for (uint256 i = 0; i < pubSignals.length; ++i) {
            uint256 rScaled = (210 * i) / step;
            int256 xOff = (cosTable[i % cosTable.length] * int256(rScaled)) / 10000;
            int256 yOff = (sinTable[i % sinTable.length] * int256(rScaled)) / 10000;
            int256 xCoord = int256(210) + xOff;
            int256 yCoord = int256(210) + yOff;

            dynamicLen += bytes(USE_PREF).length;
            dynamicLen += bytes(Strings.toString(uint256(xCoord < 0 ? 0 : uint256(xCoord)))).length;
            dynamicLen += bytes(USE_MID).length;
            dynamicLen += bytes(Strings.toString(uint256(yCoord < 0 ? 0 : uint256(yCoord)))).length;
            dynamicLen += bytes(USE_SUFF).length;
        }
    }
}

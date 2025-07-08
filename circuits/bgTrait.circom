pragma circom 2.1.6;

include "circomlib/circuits/bitify.circom";
include "circomlib/circuits/comparators.circom";

template BgTrait() {
    signal input tokenId;
    signal input seed;
    signal output rgb[3];
    signal output circleX[21];
    signal output circleY[21];
    signal output opacity;

    // Private intermediate signals
    signal colorSum;
    signal colorIndex;
    signal sumR;
    signal sumG;
    signal sumB;
    signal r[21];
    signal xTemp[21];
    signal yTemp[21];

    // Constrain inputs to 0-68
    component ltToken = LessThan(7);
    ltToken.in[0] <== tokenId;
    ltToken.in[1] <== 69;
    ltToken.out === 1;

    component ltSeed = LessThan(7);
    ltSeed.in[0] <== seed;
    ltSeed.in[1] <== 69;
    ltSeed.out === 1;

    // Compute color index
    colorSum <== tokenId + seed; // Max: 136
    component n2bColor = Num2Bits(8);
    n2bColor.in <== colorSum;
    colorIndex <== n2bColor.out[0] + 2 * n2bColor.out[1] + 4 * n2bColor.out[2]; // 0-7

    // Constrain colorIndex to 0-7
    component ltColor = LessThan(4);
    ltColor.in[0] <== colorIndex;
    ltColor.in[1] <== 8;
    ltColor.out === 1;

    // Define palette
    var palette[8][3] = [
        [255, 0, 0],
        [0, 255, 0],
        [0, 0, 255],
        [255, 255, 0],
        [255, 0, 255],
        [0, 255, 255],
        [255, 128, 0],
        [128, 255, 0]
    ];

    // Select RGB
    signal rTerms[8];
    signal gTerms[8];
    signal bTerms[8];
    component isEq[8];
    for (var i = 0; i < 8; i++) {
        isEq[i] = IsEqual();
        isEq[i].in[0] <== colorIndex;
        isEq[i].in[1] <== i;
        rTerms[i] <== isEq[i].out * palette[i][0];
        gTerms[i] <== isEq[i].out * palette[i][1];
        bTerms[i] <== isEq[i].out * palette[i][2];
    }

    sumR <== rTerms[0] + rTerms[1] + rTerms[2] + rTerms[3] + rTerms[4] + rTerms[5] + rTerms[6] + rTerms[7];
    sumG <== gTerms[0] + gTerms[1] + gTerms[2] + gTerms[3] + gTerms[4] + gTerms[5] + gTerms[6] + gTerms[7];
    sumB <== bTerms[0] + bTerms[1] + bTerms[2] + bTerms[3] + bTerms[4] + bTerms[5] + bTerms[6] + bTerms[7];

    // Constrain RGB to 0-255
    component n2bR = Num2Bits(8);
    n2bR.in <== sumR;
    rgb[0] <== sumR;

    component n2bG = Num2Bits(8);
    n2bG.in <== sumG;
    rgb[1] <== sumG;

    component n2bB = Num2Bits(8);
    n2bB.in <== sumB;
    rgb[2] <== sumB;

    // Compute opacity
    opacity <== colorSum;
    component ltOpacity = LessThan(7);
    ltOpacity.in[0] <== opacity;
    ltOpacity.in[1] <== 100;
    ltOpacity.out === 1;

    // Compute circle coordinates
    var cosVals[5] = [10, 3, -8, -8, 3];
    var sinVals[5] = [0, 9, 6, -6, -9];

    component ltCircleX[21];
    component ltCircleY[21];
    for (var i = 0; i < 21; i++) {
        ltCircleX[i] = LessThan(14);
        ltCircleY[i] = LessThan(14);

        if (i == 0) {
            circleX[i] <== 6000;
            circleY[i] <== 6000;
            r[i] <== 0;
            xTemp[i] <== 0;
            yTemp[i] <== 0;
        } else {
            var idx = (i - 1) % 5;
            r[i] <== 200 + idx * 100;
            xTemp[i] <== r[i] * cosVals[idx];
            yTemp[i] <== r[i] * sinVals[idx];
            circleX[i] <== 6000 + xTemp[i];
            circleY[i] <== 6000 + yTemp[i];
        }

        ltCircleX[i].in[0] <== circleX[i];
        ltCircleX[i].in[1] <== 12001;
        ltCircleX[i].out === 1;

        ltCircleY[i].in[0] <== circleY[i];
        ltCircleY[i].in[1] <== 12001;
        ltCircleY[i].out === 1;
    }
}

component main {public [tokenId, seed]} = BgTrait();
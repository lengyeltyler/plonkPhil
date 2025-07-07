pragma circom 2.1.6;
include "circomlib/circuits/bitify.circom";
include "circomlib/circuits/comparators.circom";

template MyCircuit() {
    signal input tokenId;
    signal input seed;
    signal output rgb[3];
    signal output circleX[21]; // 20 circles (4 arms * 5) + 1 central
    signal output circleY[21];
    signal output opacity;

    // Constrain inputs to 0-68
    component ltToken = LessThan(7);
    ltToken.in[0] <== tokenId;
    ltToken.in[1] <== 69;
    ltToken.out === 1;

    component ltSeed = LessThan(7);
    ltSeed.in[0] <== seed;
    ltSeed.in[1] <== 69;
    ltSeed.out === 1;

    // Compute color index for a palette of 8 colors
    signal colorSum;
    signal colorIndex;
    colorSum <== tokenId + seed; // Max: 68 + 68 = 136
    component n2bColor = Num2Bits(8);
    n2bColor.in <== colorSum;
    colorIndex <== n2bColor.out[0] + 2 * n2bColor.out[1] + 4 * n2bColor.out[2]; // 0-7

    // Constrain colorIndex to 0-7
    component ltColor = LessThan(4);
    ltColor.in[0] <== colorIndex;
    ltColor.in[1] <== 8;
    ltColor.out === 1;

    component geColor = GreaterEqThan(4);
    geColor.in[0] <== colorIndex;
    geColor.in[1] <== 0;
    geColor.out === 1;

    // Define palette: 8 RGB colors (values 0-255)
    var palette[8][3] = [
        [255, 0, 0],    // Red
        [0, 255, 0],    // Green
        [0, 0, 255],    // Blue
        [255, 255, 0],  // Yellow
        [255, 0, 255],  // Magenta
        [0, 255, 255],  // Cyan
        [255, 128, 0],  // Orange
        [128, 255, 0]   // Lime
    ];

    // Select RGB from palette
    signal rgbTemp[3];
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

    signal sumR;
    signal sumG;
    signal sumB;
    sumR <== rTerms[0] + rTerms[1] + rTerms[2] + rTerms[3] + rTerms[4] + rTerms[5] + rTerms[6] + rTerms[7];
    sumG <== gTerms[0] + gTerms[1] + gTerms[2] + gTerms[3] + gTerms[4] + gTerms[5] + gTerms[6] + gTerms[7];
    sumB <== bTerms[0] + bTerms[1] + bTerms[2] + bTerms[3] + bTerms[4] + bTerms[5] + bTerms[6] + bTerms[7];
    
    rgbTemp[0] <== sumR;
    rgbTemp[1] <== sumG;
    rgbTemp[2] <== sumB;

    // Constrain RGB to 0-255
    component n2b[3];
    component ltRgb[3];
    component geZero[3];
    for (var i = 0; i < 3; i++) {
        geZero[i] = GreaterEqThan(8);
        geZero[i].in[0] <== rgbTemp[i];
        geZero[i].in[1] <== 0;
        geZero[i].out === 1;

        ltRgb[i] = LessThan(9);
        ltRgb[i].in[0] <== rgbTemp[i];
        ltRgb[i].in[1] <== 256;
        ltRgb[i].out === 1;

        n2b[i] = Num2Bits(8);
        n2b[i].in <== rgbTemp[i];
        rgb[i] <== rgbTemp[i];
    }

    // Compute uniform opacity (0-99)
    signal opacityTemp;
    opacityTemp <== tokenId + seed;
    component ltOpacity = LessThan(7);
    ltOpacity.in[0] <== opacityTemp;
    ltOpacity.in[1] <== 100;
    ltOpacity.out === 1;
    opacity <== opacityTemp;

    // Compute circle coordinates in a four-arm spiral
    // Center at (6000, 6000) in scaled units (divide by 100 in contract), radius from 200 to 600
    signal circleXTemp[21];
    signal circleYTemp[21];
    signal r[21];
    signal xTemp[21];
    signal yTemp[21];
    component ltCircleX[21];
    component ltCircleY[21];
    component geCircleX[21];
    component geCircleY[21];
    for (var i = 0; i < 21; i++) {
        ltCircleX[i] = LessThan(14); // For 0-12000 range
        ltCircleY[i] = LessThan(14);
        geCircleX[i] = GreaterEqThan(14);
        geCircleY[i] = GreaterEqThan(14);

        if (i == 0) {
            // Central circle at (6000, 6000)
            circleXTemp[i] <== 6000;
            circleYTemp[i] <== 6000;
            r[i] <== 0;
            xTemp[i] <== 0;
            yTemp[i] <== 0;
        } else {
            // Four-arm spiral: 5 circles per arm, angles offset by 90 degrees
            var arm = (i - 1) \ 5; // Arm index: 0, 1, 2, 3
            var j = (i - 1) % 5; // Circle index within arm: 0 to 4
            var base_angle = arm * 900; // Arm offset: 0, 900, 1800, 2700 (0.1 degrees)
            var angle = base_angle + j * 720; // 72 degrees * j (0.1 degrees)
            r[i] <== 200 + j * 100; // Radius: 200, 300, 400, 500, 600
            // Approximate cos and sin (scaled by 10)
            var cos_values[5] = [10, 3, -8, -8, 3]; // cos(0, 72, 144, 216, 288) * 10
            var sin_values[5] = [0, 9, 6, -6, -9]; // sin(0, 72, 144, 216, 288) * 10
            xTemp[i] <== r[i] * cos_values[j]; // Range: -600 * 10 = -6000 to 6000
            yTemp[i] <== r[i] * sin_values[j];
            // Center at 6000 to ensure non-negative
            circleXTemp[i] <== 6000 + xTemp[i]; // Range: 6000 - 6000 = 0 to 6000 + 6000 = 12000
            circleYTemp[i] <== 6000 + yTemp[i];
        }

        // Constrain circleXTemp, circleYTemp to 0-12000
        geCircleX[i].in[0] <== circleXTemp[i];
        geCircleX[i].in[1] <== 0;
        geCircleX[i].out === 1;

        ltCircleX[i].in[0] <== circleXTemp[i];
        ltCircleX[i].in[1] <== 12001;
        ltCircleX[i].out === 1;

        geCircleY[i].in[0] <== circleYTemp[i];
        geCircleY[i].in[1] <== 0;
        geCircleY[i].out === 1;

        ltCircleY[i].in[0] <== circleYTemp[i];
        ltCircleY[i].in[1] <== 12001;
        ltCircleY[i].out === 1;

        // Output scaled coordinates (division by 100 handled in contract)
        circleX[i] <== circleXTemp[i];
        circleY[i] <== circleYTemp[i];
    }
}

component main {public [tokenId, seed]} = MyCircuit();
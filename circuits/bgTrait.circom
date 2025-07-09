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
    signal output radius[21];

    // Intermediate
    signal colorSum; signal colorIndex;
    signal sumR; signal sumG; signal sumB;
    signal r[21]; signal xTemp[21]; signal yTemp[21];
    signal theta[21]; signal thetaNorm[21];
    signal thetaQuotient[21]; signal thetaRemainder[21];
    signal cosTheta[21]; signal sinTheta[21];
    signal thetaScaled[21]; signal index[21];
    signal sinTerms[21][16]; signal cosTerms[21][16];
    signal opacityQuotient; signal opacityRemainder;

    // Lookup components
    component sinEq[21][16];
    component cosEq[21][16];
    component indexCheck[21];

    // 1) tokenId, seed ∈ [0,68]
    component ltToken = LessThan(7);
    ltToken.in[0] <== tokenId; ltToken.in[1] <== 69; ltToken.out === 1;
    component ltSeed  = LessThan(7);
    ltSeed.in[0] <== seed;  ltSeed.in[1] <== 69; ltSeed.out === 1;

    // 2) colorIndex ∈ [0,3]
    colorSum <== tokenId + seed;
    component n2bColor = Num2Bits(8); n2bColor.in <== colorSum;
    colorIndex <== n2bColor.out[0] + n2bColor.out[1] + n2bColor.out[2];
    component ltColor = LessThan(3);
    ltColor.in[0] <== colorIndex; ltColor.in[1] <== 4; ltColor.out === 1;

    // 3) Palette→rgb
    var palette[4][3] = [
        [255,0,0],
        [0,255,0],
        [31,163,132],
        [255,255,0]
    ];
    signal rTerms[4]; signal gTerms[4]; signal bTerms[4];
    component isEq[4];
    for(var i=0;i<4;i++){
      isEq[i]=IsEqual();
      isEq[i].in[0]<==colorIndex;
      isEq[i].in[1]<==i;
      rTerms[i]<==isEq[i].out*palette[i][0];
      gTerms[i]<==isEq[i].out*palette[i][1];
      bTerms[i]<==isEq[i].out*palette[i][2];
    }
    sumR<==rTerms[0]+rTerms[1]+rTerms[2]+rTerms[3];
    sumG<==gTerms[0]+gTerms[1]+gTerms[2]+gTerms[3];
    sumB<==bTerms[0]+bTerms[1]+bTerms[2]+bTerms[3];
    component n2bR=Num2Bits(8); n2bR.in<==sumR; rgb[0]<==sumR;
    component n2bG=Num2Bits(8); n2bG.in<==sumG; rgb[1]<==sumG;
    component n2bB=Num2Bits(8); n2bB.in<==sumB; rgb[2]<==sumB;

    // 4) opacity ∈ [0,63]
    opacityQuotient <== colorSum/64;
    opacityRemainder<== colorSum-opacityQuotient*64;
    opacity<==opacityRemainder;
    component ltOpacity=LessThan(7);
    ltOpacity.in[0]<==opacity; ltOpacity.in[1]<==64; ltOpacity.out===1;

    // 5) 16-step sin/cos tables (scaled ×1000)
    var sinTable[16] = [
         0,  383,  707,  923,
      1000,  923,  707,  383,
         0, -383, -707, -923,
     -1000, -923, -707, -383
    ];
    var cosTable[16] = [
      1000,  923,  707,  383,
         0, -383, -707, -923,
     -1000, -923, -707, -383,
         0,  383,  707,  923
    ];

    // 6) build circles
    component ltX[21]; component ltY[21]; component ltR[21];
    for(var i=0;i<21;i++){
      ltX[i]=LessThan(14);
      ltY[i]=LessThan(14);
      ltR[i]=LessThan(8);
      indexCheck[i]=LessThan(5); // <16

      if(i==0){
        // center
        circleX[i]<==6000; circleY[i]<==6000; radius[i]<==140;
        r[i]<==0; theta[i]<==0; thetaNorm[i]<==0;
        thetaQuotient[i]<==0; thetaRemainder[i]<==0;
        cosTheta[i]<==1000; sinTheta[i]<==0; thetaScaled[i]<==0; index[i]<==0;
        indexCheck[i].in[0]<==index[i]; indexCheck[i].in[1]<==16; indexCheck[i].out===1;
      } else {
        // stronger spiral
        theta[i] <== i * 900 + seed * 200; // 0.9 rad steps
        r[i]     <== 200 * i;              // keeps within 12000

        // normalize
        thetaQuotient[i]  <== theta[i]/6283;
        thetaRemainder[i] <== theta[i]-thetaQuotient[i]*6283;
        thetaNorm[i]      <== thetaRemainder[i];

        // scale to [0,16)
        thetaScaled[i] <== thetaNorm[i]*16/6283;
        index[i]       <== thetaScaled[i];

        indexCheck[i].in[0]<==index[i];
        indexCheck[i].in[1]<==16;
        indexCheck[i].out===1;

        // lookup sin & cos
        for(var j=0;j<16;j++){
          sinEq[i][j]=IsEqual();
          sinEq[i][j].in[0]<==index[i];
          sinEq[i][j].in[1]<==j;
          sinTerms[i][j]<==sinEq[i][j].out*sinTable[j];

          cosEq[i][j]=IsEqual();
          cosEq[i][j].in[0]<==index[i];
          cosEq[i][j].in[1]<==j;
          cosTerms[i][j]<==cosEq[i][j].out*cosTable[j];
        }
        // sum them
        sinTheta[i]<==sinTerms[i][0]+sinTerms[i][1]+sinTerms[i][2]+sinTerms[i][3]
                    +sinTerms[i][4]+sinTerms[i][5]+sinTerms[i][6]+sinTerms[i][7]
                    +sinTerms[i][8]+sinTerms[i][9]+sinTerms[i][10]+sinTerms[i][11]
                    +sinTerms[i][12]+sinTerms[i][13]+sinTerms[i][14]+sinTerms[i][15];
        cosTheta[i]<==cosTerms[i][0]+cosTerms[i][1]+cosTerms[i][2]+cosTerms[i][3]
                    +cosTerms[i][4]+cosTerms[i][5]+cosTerms[i][6]+cosTerms[i][7]
                    +cosTerms[i][8]+cosTerms[i][9]+cosTerms[i][10]+cosTerms[i][11]
                    +cosTerms[i][12]+cosTerms[i][13]+cosTerms[i][14]+cosTerms[i][15];

        // final XY
        xTemp[i]<== (r[i]*cosTheta[i])/1000;
        yTemp[i]<== (r[i]*sinTheta[i])/1000;
        circleX[i]<==6000 + xTemp[i];
        circleY[i]<==6000 + yTemp[i];
        radius[i] <== 140 - i*5;
      }

      // enforce bounds
      ltX[i].in[0]<==circleX[i];  ltX[i].in[1]<==12001; ltX[i].out===1;
      ltY[i].in[0]<==circleY[i];  ltY[i].in[1]<==12001; ltY[i].out===1;
      ltR[i].in[0]<==radius[i];   ltR[i].in[1]<==141;   ltR[i].out===1;
    }
}

component main { public [tokenId, seed] } = BgTrait();

`timescale 1ns / 10ps

module test;

  reg            clk;
  reg   [ 7:0]	 a;
  reg   [ 7:0]	 b;
  wire  [15:0]   p_g;
  wire  [15:0]   p_b;
  integer        reporting;
  integer        e;
  integer        i;
  integer        MAX;
  integer        logfile;
  parameter      ALWAYS    =  3;
  parameter      VERBOSE   =  2;
  parameter      TERSE     =  1;
  parameter      NONE      =  0;
  parameter      cycle     = 100;
  parameter      cycle2    = 50;

  beh8x8  mb(p_b,a,b);
  mult8x8 mg(p_g,a,b);

  initial         clk = 1'b1;
  always  #cycle2 clk = ~clk;

  initial begin
    logfile = $fopen("bth8x8.log");
    e            = 0;
    MAX          = 1000;
    //reporting    = VERBOSE;
    reporting    = ALWAYS;
    #cycle2;
    $write("test: full-range coeffs & random-data");
    for (i=0; i<MAX; i=i+1) begin
      #cycle2;
      a = $random%(1<<8);
      b = $random%(1<<8);
      #cycle2;
    end
    if (e && reporting==TERSE) $write("]");
    $write("\t%d errors after %d vectors [%2.3f%%]\n",e[29:0],i[29:0],(e*100)/i);
    $fwrite(logfile,"bth8x8: %d errors after %d vectors [%2.3f%%]\n",e[29:0],i[29:0],(e*100)/i);
    $display("");
    $finish(2);
  end

  always @(negedge clk) begin
    if ((p_g !== p_b || reporting==ALWAYS) && e>=0) begin
      e=e+1;
      if (e==1) $write("\n\n");
      if (reporting==VERBOSE || reporting==ALWAYS) begin
        $write("error @ v[%d] : dif[%b] p_g[%d]!=p_b[%d] a[%d]*b[%d]\n",i[19:0],p_g^p_b,p_g,p_b,a,b);
      end
      if (reporting==TERSE) $write("%d",i);
    end
  end

endmodule /* test */


module beh8x8(p,d,c);

  output [15:0] p;
  input  [ 7:0] d;
  input  [ 7:0] c;
  wire   [ 7:0] d_;
  wire   [ 7:0] c_;

  assign d_ = (d[ 7])        ?         ~d+1 :      d;
  assign c_ = (c[ 7])        ?         ~c+1 :      c;
  assign p   = (d[ 7]^c[ 7]) ?  ~(d_*c_)+1 : d_*c_;

endmodule /* beh8x8() */


module ppg8(pp,a,b);

  output [ 9:0] pp;                                 /* partial-product output */
  input  [ 7:0] a;                                              /* input-data */
  input  [ 2:0] b;                          /* 3 overlapping coefficient-bits */
  wire   [ 2:0] c;                                 /* output of Booth-decoder */
  wire   [ 7:0] db;                                                  /* ~data */
  wire   [ 8:0] x1;                                               /* data x 1 */
  wire   [ 8:0] x2;                                               /* data x 2 */
  wire   [ 8:0] mx;                                    /* x2 or c mux-output */
  wire   [ 8:0] p;                                         /* partial-product */
  wire          cb;                              /* buffered sign-bit to pssa */

  /* Booth-Decoder */
  assign c[0] = b[0]^b[1];                                              /* c */
  assign c[1] = (~b[2]&b[1]&b[0]) | (b[2]&~b[1]&~b[0]);                 /* x2 */
  assign c[2] = b[2]&~(b[1]&b[0]);                                  /* negate */

  /* Partial-Product Generator */
  assign db = a ^ {8{c[2]}};                      /* c[2] = neg; invert data */
  assign x1 = {db[7],db} & {9{c[0]}};        /* c[0] =  c; pass data (* 1) */
  assign x2 = {db,  c[2]} & {9{c[1]}}; /* c[1] =  x2; shift 1 bit left (* 2) */
  assign mx = x2 | x1;                           /* multiplication by {0,1,2} */
  assign cb = c[2];                                  /* buffer negate to pssa */
  assign pp = {~mx[8],mx[7:0],cb};             /* negate=> invert and add 1 */

endmodule /* ppg8() */


module ppggen8x8(pp3,pp2,pp1,pp0,d,c);

  output [ 9:0] pp3;
  output [ 9:0] pp2;
  output [ 9:0] pp1;
  output [ 9:0] pp0;
  input  [ 7:0] d;
  input  [ 7:0] c;
  wire   [ 8:0] c_;

  assign c_ = {c,1'b0};
  ppg8 ppg0(pp0,d,c_[2:0]);
  ppg8 ppg1(pp1,d,c_[4:2]);
  ppg8 ppg2(pp2,d,c_[6:4]);
  ppg8 ppg3(pp3,d,c_[8:6]);

endmodule /* ppggen8x8() */


module fa(cout,sout,a,b,cin);

  output cout;
  output sout;
  input  a;
  input  b;
  input  cin;

  //assign{cout,sout} = a+b+cin;

  assign sout = a^b^cin;
  assign cout = (a&b) | (cin&(a|b));

endmodule /* fa() */


module ha(cout,sout,a,b);

  output cout;
  output sout;
  input  a;
  input  b;

  //assign{cout,sout} = a+b;

  assign sout = a^b;
  assign cout = a&b;

endmodule /* ha() */


module cmp5_2(o,c,s,pp,i);

  output [ 1:0] o;
  output        c;
  output        s;
  input  [ 4:0] pp;
  input  [ 1:0] i;
  wire   [ 1:0] x;

  /*  fa(  co,   s,    a,    b,   ci) */
  fa fa0(o[ 0],x[ 0],pp[ 0],pp[ 1],pp[ 2]);
  fa fa1(o[ 1],x[ 1], i[ 0], x[ 0],pp[ 3]);
  fa fa2(    c,    s, i[ 1], x[ 1],pp[ 4]);

endmodule /* cmp 5_2() */


module pssa8x8(c,s,pp3,pp2,pp1,pp0);

  output [15:0] c;
  output [15:0] s;
  input  [ 9:0] pp3;
  input  [ 9:0] pp2;
  input  [ 9:0] pp1;
  input  [ 9:0] pp0;
  wire   [ 1:0] o0;
  wire   [ 1:0] o1;
  wire   [ 1:0] o2;
  wire   [ 1:0] o3;
  wire   [ 1:0] o4;
  wire   [ 1:0] o5;
  wire   [ 1:0] o6;
  wire   [ 1:0] o7;
  wire   [ 1:0] o8;
  wire   [ 1:0] o9;
  wire   [ 1:0] o10;
  wire   [ 1:0] o11;
  wire   [ 1:0] o12;
  wire   [ 1:0] o13;
  wire   [ 1:0] o14;
  wire   [ 1:0] o15;

  cmp5_2 cmp0 (o0 ,c[ 0],s[ 0],{pp0[ 0],pp0[ 1],3'b000},2'b00);
  cmp5_2 cmp1 (o1 ,c[ 1],s[ 1],{pp0[ 2],4'b0000},o0 );
  cmp5_2 cmp2 (o2 ,c[ 2],s[ 2],{pp0[ 3],pp1[ 0],pp1[ 1],2'b00},o1 );
  cmp5_2 cmp3 (o3 ,c[ 3],s[ 3],{pp0[ 4],pp1[ 2],3'b000},o2 );
  cmp5_2 cmp4 (o4 ,c[ 4],s[ 4],{pp0[ 5],pp1[ 3],pp2[ 0],pp2[ 1],1'b0},o3 );
  cmp5_2 cmp5 (o5 ,c[ 5],s[ 5],{pp0[ 6],pp1[ 4],pp2[ 2],2'b00},o4 );
  cmp5_2 cmp6 (o6 ,c[ 6],s[ 6],{pp0[ 7],pp1[ 5],pp2[ 3],pp3[ 0],pp3[ 1]},o5 );
  cmp5_2 cmp7 (o7 ,c[ 7],s[ 7],{pp0[ 8],pp1[ 6],pp2[ 4],pp3[ 2],1'b0},o6 );
  cmp5_2 cmp8 (o8 ,c[ 8],s[ 8],{pp0[ 9],pp1[ 7],pp2[ 5],pp3[ 3],1'b1},o7 );
  cmp5_2 cmp9 (o9 ,c[ 9],s[ 9],{        pp1[ 8],pp2[ 6],pp3[ 4],2'b10},o8 );
  cmp5_2 cmp10(o10,c[10],s[10],{        pp1[ 9],pp2[ 7],pp3[ 5],2'b00},o9 );
  cmp5_2 cmp11(o11,c[11],s[11],{                pp2[ 8],pp3[ 6],3'b100},o10);
  cmp5_2 cmp12(o12,c[12],s[12],{                pp2[ 9],pp3[ 7],3'b000},o11);
  cmp5_2 cmp13(o13,c[13],s[13],{                        pp3[ 8],4'b1000},o12);
  cmp5_2 cmp14(o14,c[14],s[14],{                        pp3[ 9],4'b0000},o13);
  cmp5_2 cmp15(o15,c[15],s[15],{                                5'b10000},o14);

endmodule /* pssa8x8() */


module blc16(s,a,b);

  output [15:0] s;
  input  [15:0] a;
  input  [15:0] b;
  wire   [15:0] p;
  wire   [15:0] x;
  wire   [15:0] g;
  wire   [15:0] c;

  blc_pg16    pg  (x,p,g,a,b);
  blc_array16 blca(c,p,g);
  blc_sum16   sum (s,x,{c[14:0],1'b0});

endmodule /* blc16() */


module blc_pg16(x,p,g,a,b);

  output [15:0] x;
  output [15:0] p;
  output [15:0] g;
  input  [15:0] a;
  input  [15:0] b;
  wire   [15:0] y;

  assign g = a&b;
  assign p = a|b;
  assign x = a^b;
  assign y = x^{p[14:0],1'b0};

endmodule /* blc_pg16() */


module blc_array16(g4,p0,g0);

  wire          cout;
  output [15:0] g4;
  input  [15:0] p0;
  input  [15:0] g0;
  wire   [15:0] p1;
  wire   [15:0] g1;
  wire   [15:0] p2;
  wire   [15:0] g2;
  wire   [15:0] p3;
  wire   [15:0] g3;
  wire   [15:0] p4;
  wire   [15:0] g4;

  assign p1[15:1] = p0[15:1]&p0[14:0];
  assign g1[15:0] = {g0[15:0]|(p0[15:0]&{g0[14:0],1'b0})};

  assign p2[15:3] = p1[15:3]&p1[13:1];
  assign g2[15:0] = {g1[15:1]|(p1[15:1]&{g1[13:0],1'b0}),g1[0:0]};

  assign p3[15:7] = p2[15:7]&p2[11:3];
  assign g3[15:0] = {g2[15:3]|(p2[15:3]&{g2[11:0],1'b0}),g2[2:0]};

  assign p4[15:15] = p3[15:15]&p3[7:7];
  assign g4[15:0] = {g3[15:7]|(p3[15:7]&{g3[7:0],1'b0}),g3[6:0]};


endmodule /* blc_array16() */


module blc_sum16(s,p,c);

  output [15:0] s;
  input  [15:0] p;
  input  [15:0] c;

  assign s = p^c;

endmodule /* blc_sum16() */


module mult8x8(p,a,b);

  output [15:0] p;
  input  [ 7:0] a;
  input  [ 7:0] b;
  wire   [ 9:0] pp3;
  wire   [ 9:0] pp2;
  wire   [ 9:0] pp1;
  wire   [ 9:0] pp0;
  wire   [15:0] c;
  wire   [15:0] s;

  ppggen8x8 ppgen(pp3,pp2,pp1,pp0,a,b);
  pssa8x8 pssa(c,s,pp3,pp2,pp1,pp0);
  blc16 vma(p,{c[14:0],1'b0},s);

endmodule  /* mult8x8() */



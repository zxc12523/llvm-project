//===-- RISCVInstrInfomy.td ----------------------------*- tablegen -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file describes the vendor extensions defined by T-Head of Alibaba.
//
//===----------------------------------------------------------------------===//

//===----------------------------------------------------------------------===//
// T-HEAD specific DAG Nodes.
//===----------------------------------------------------------------------===//

def MY_SDT_LoadPair : SDTypeProfile<2, 2, [SDTCisSameAs<0, 1>,
                                        SDTCisSameAs<1, 3>,
                                        SDTCisPtrTy<2>,
                                        SDTCisVT<3, XLenVT>]>;
def MY_SDT_StorePair : SDTypeProfile<0, 4, [SDTCisSameAs<0, 1>,
                                         SDTCisSameAs<1, 3>,
                                         SDTCisPtrTy<2>,
                                         SDTCisVT<3, XLenVT>]>;

def my_lwud : SDNode<"RISCVISD::MY_LWUD", MY_SDT_LoadPair,
                     [SDNPHasChain, SDNPMayLoad, SDNPMemOperand]>;
def my_lwd : SDNode<"RISCVISD::MY_LWD", MY_SDT_LoadPair,
                    [SDNPHasChain, SDNPMayLoad, SDNPMemOperand]>;
def my_ldd : SDNode<"RISCVISD::MY_LDD", MY_SDT_LoadPair,
                    [SDNPHasChain, SDNPMayLoad, SDNPMemOperand]>;
def my_swd : SDNode<"RISCVISD::MY_SWD", MY_SDT_StorePair,
                    [SDNPHasChain, SDNPMayStore, SDNPMemOperand]>;
def my_sdd : SDNode<"RISCVISD::MY_SDD", MY_SDT_StorePair,
                    [SDNPHasChain, SDNPMayStore, SDNPMemOperand]>;


let Predicates = [HasVendormyMemPair], DecoderNamespace = "myMemPair",
    hasSideEffects = 0, mayLoad = 1, mayStore = 0 in
class myLoadPair<bits<3> func3,string opcodestr>
  : RVInstRBase<func3, OPC_CUSTOM_0,
                (outs GPR:$rd, GPR:$rs2),
                (ins GPR:$rs1, uimm7:$uimm7m, uimm7:$const2or3),
                 opcodestr, "$rd, $rs2, (${rs1}), $uimm7, $const2or3"> {
  bits<7> uimm7;
  let Inst{31-25} = uimm7;
  let DecoderMethod = "decodeMyMemPair";
  let Constraints = "@earlyclobber $rd,@earlyclobber $rs2";
}

let Predicates = [HasVendormyMemPair], DecoderNamespace = "myMemPair",
    hasSideEffects = 0, mayLoad = 0, mayStore = 1 in
class myStorePair<bits<3> func3, string opcodestr>
  : RVInstRBase<func3, OPC_CUSTOM_0, (outs),
              (ins GPR:$rd, GPR:$rs2, GPR:$rs1, uimm7:$uimm7, uimm7:$const2or3),
              opcodestr, "$rd, $rs2, (${rs1}), $uimm7, $const2or3"> {
  bits<7> uimm7;
  let Inst{31-25} = uimm7;
  let DecoderMethod = "decodeMyMemPair";
}

//===----------------------------------------------------------------------===//
// Instructions
//===----------------------------------------------------------------------===//

let Predicates = [HasVendormyMemPair] in {
def MY_LWUD : myLoadPair<0b001, "my.lwud">,
              Sched<[WriteLDW, WriteLDW, ReadMemBase]>;
def MY_SWD  : myStorePair<0b110, "my.swd">,
              Sched<[WriteSTW, WriteSTW, ReadStoreData, ReadMemBase]>;
let IsSignExtendingOpW = 1 in
def MY_LWD  : myLoadPair<0b010, "my.lwd">,
              Sched<[WriteLDW, WriteLDW, ReadMemBase]>;
}

let Predicates = [HasVendormyMemPair, IsRV64] in {
def MY_LDD : myLoadPair<0b011, "my.ldd">,
             Sched<[WriteLDD, WriteLDD, ReadMemBase]>;
def MY_SDD : myStorePair<0b111, "my.sdd">,
             Sched<[WriteSTD, WriteSTD, ReadStoreData, ReadMemBase]>;
}


//===----------------------------------------------------------------------===//
// Pseudo-instructions and codegen patterns
//===----------------------------------------------------------------------===//


def uimm7_2_XFORM : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant((N->getZExtValue() >> 2) & 0x7F,
                                   SDLoc(N), Subtarget->getXLenVT());
}]>;

def uimm7_2 : Operand<XLenVT>, ImmLeaf<XLenVT, [{
  return isShiftedUInt<7, 2>(Imm);
}], uimm7_2_XFORM>;

def uimm7_3_XFORM : SDNodeXForm<imm, [{
  return CurDAG->getTargetConstant((N->getZExtValue() >> 3) & 0x7F,
                                   SDLoc(N), Subtarget->getXLenVT());
}]>;

def uimm7_3 : Operand<XLenVT>, ImmLeaf<XLenVT, [{
  return isShiftedUInt<7, 3>(Imm);
}], uimm7_3_XFORM>;

let Predicates = [HasVendormyMemPair, IsRV64] in {
def : Pat<(my_lwud i64:$rs1, uimm7_2:$uimm7_2), 
          (MY_LWUD i64:$rs1, uimm7_2:$uimm7_2, 2)>;
def : Pat<(my_ldd i64:$rs1, uimm7_3:$uimm7_3), 
          (MY_LDD i64:$rs1, uimm7_3:$uimm7_3, 3)>;
def : Pat<(my_sdd i64:$rd1, i64:$rd2, i64:$rs1, uimm7_3:$uimm7_3), 
          (MY_SDD i64:$rd1, i64:$rd2, i64:$rs1, uimm7_3:$uimm7_3, 3)>;
}

let Predicates = [HasVendormyMemPair] in {
  def : Pat<(my_lwd GPR:$rs1, uimm7_2:$uimm7_2), 
            (MY_LWD GPR:$rs1, uimm7_2:$uimm7_2, 2)>;
  def : Pat<(my_swd GPR:$rd1, GPR:$rd2, GPR:$rs1, uimm7_3:$uimm7_3), 
            (MY_SWD GPR:$rd1, GPR:$rd2, GPR:$rs1, uimm7_3:$uimm7_3, 3)>;
}

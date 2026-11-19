#!/usr/bin/env python3
"""Independent RV32I reference interpreter for v2 instruction ROM (NOT RTL sim)."""
from pathlib import Path
MASK=0xffffffff
sext=lambda v,b: v-(1<<b) if v&(1<<(b-1)) else v
v2=Path(__file__).resolve().parent.parent
words=[int(x,16) for x in (v2/'programs'/'MULTIPROGRAM.mem').read_text().splitlines()]
assert len(words)==256

cases=[
    (1,15,7,22), (2,7,15,-8), (3,15,7,105),
    (3,9999,9999,99980001), (3,100,0,0),
    (4,10,0,55), (4,0,0,0), (4,9999,0,49995000),
    (5,0,0,0), (5,1,0,1), (5,2,0,1),
    (5,10,0,55), (5,39,0,63245986), (6,0,0,20),
    (2,0,9999,-9999), (1,9999,9999,19998),
    (6,0,0,20),
]

def run(tests, inject_sll_fault=False):
    rom=words.copy()
    if inject_sll_fault:
        # Mutate only SLL x3,x1,x2 in TEST20 into SRL, preserving all other bits.
        ix=[i for i,w in enumerate(rom) if (w&127)==0x33 and ((w>>12)&7)==1 and
            ((w>>7)&31)==3 and ((w>>15)&31)==1 and ((w>>20)&31)==2]
        assert len(ix)==1,ix
        rom[ix[0]]=(rom[ix[0]]&~(7<<12))|(5<<12)
    regs=[0]*32
    ram={}
    pc=0
    job_idx=0
    output=[]
    observed=set()
    for steps in range(250000):
        assert 0<=pc<1024 and pc%4==0, f'bad PC {pc:08x} at step {steps}'
        w=rom[pc//4];op=w&127; f3=(w>>12)&7; f7=(w>>25)&127
        rd=(w>>7)&31;rs1=(w>>15)&31;rs2=(w>>20)&31
        a,b=regs[rs1],regs[rs2];nxt=(pc+4)&MASK;val=None
        if op==0x33:
            m={(0,0):'ADD',(32,0):'SUB',(0,7):'AND',(0,6):'OR',
               (0,4):'XOR',(0,1):'SLL',(0,5):'SRL',(32,5):'SRA'}
            cmd=m[(f7,f3)]
            if cmd=='ADD':val=(a+b)&MASK
            elif cmd=='SUB':val=(a-b)&MASK
            elif cmd=='AND':val=a&b
            elif cmd=='OR':val=a|b
            elif cmd=='XOR':val=a^b
            elif cmd=='SLL':val=(a<<(b&31))&MASK
            elif cmd=='SRL':val=a>>(b&31)
            elif cmd=='SRA':val=(sext(a,32)>>(b&31))&MASK
        elif op==0x13:
            imm=sext(w>>20,12)
            cmd={0:'ADDI',7:'ANDI',6:'ORI',4:'XORI'}[f3]
            if cmd=='ADDI':val=(a+imm)&MASK
            elif cmd=='ANDI':val=a&imm&MASK
            elif cmd=='ORI':val=a|imm&MASK
            elif cmd=='XORI':val=a^imm&MASK
        elif op==0x37:cmd='LUI';val=w&0xfffff000
        elif op==0x17:cmd='AUIPC';val=(pc+(w&0xfffff000))&MASK
        elif op==0x03:
            assert f3==2;cmd='LW'
            addr=(a+sext(w>>20,12))&MASK
            if addr==0x1000:val=tests[job_idx][1]
            elif addr==0x1004:val=tests[job_idx][2]
            elif addr==0x1008:val=tests[job_idx][0]
            elif addr==0x100c:val=1
            else:assert addr<512 and addr%4==0;val=ram.get(addr,0)
        elif op==0x23:
            assert f3==2;cmd='SW'
            imm=sext(((w>>25)<<5)|((w>>7)&31),12)
            addr=(a+imm)&MASK
            if addr==0x1010:
                output.append(sext(b,32))
                expected=tests[job_idx][3]
                assert output[-1]==expected, f'command#{job_idx} {tests[job_idx]} got {output[-1]} at PC {pc:08x}'
                job_idx+=1
                if job_idx==len(tests): return output, observed,ram,steps+1
            else:
                assert addr<512 and addr%4==0,(pc,addr)
                ram[addr]=b
        elif op==0x63:
            cmd={0:'BEQ',1:'BNE'}[f3]
            imm=((w>>31)<<12)|(((w>>7)&1)<<11)|(((w>>25)&63)<<5)|(((w>>8)&15)<<1)
            take=(a==b if f3==0 else a!=b)
            if take:nxt=(pc+sext(imm,13))&MASK
        elif op==0x6f:
            cmd='JAL'
            imm=((w>>31)<<20)|(((w>>12)&255)<<12)|(((w>>20)&1)<<11)|(((w>>21)&1023)<<1)
            nxt=(pc+sext(imm,21))&MASK
            val=pc+4
        elif op==0x67:
            cmd='JALR';assert f3==0
            nxt=(a+sext(w>>20,12))&0xfffffffe;val=pc+4
        else:raise AssertionError(f'Unknown opcode at PC {pc:08x}: {w:08x}')
        observed.add(cmd)
        if val is not None and rd:regs[rd]=val&MASK
        regs[0]=0
        pc=nxt
    raise RuntimeError(f'No result before 250k steps, finished {job_idx}/{len(tests)} PC=0x{pc:08x}')

if __name__=='__main__':
    actual, observed,ram,steps=run(cases)
    assert len(observed)==20,(len(observed),sorted(observed))
    assert ram.get(0)==8 and ram.get(4)==2
    print(f'PASS independent ISA model: {len(cases)} commands, {len(observed)} instruction types, {steps} steps')
    negative=[(6,0,0,-6)]
    got,_,_,_=run(negative,inject_sll_fault=True)
    assert got==[-6]
    print('PASS negative control: SLL->SRL mutation detected as -6')
    print('NOTE: software-model verification only; run Icarus RTL HDL tests separately')

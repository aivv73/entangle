import Base
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

type Counters is Data:
  Counters{writes:U32,write_bytes:W.U64,pushes:U32,push_bytes:W.U64,draws:U32,submits:U32}

def zero() -> Counters:
  Counters{0,W.zero(),0,W.zero(),0,0}

def push(c:Counters,bytes:U32) -> Counters:
  Counters{w,b,p,pb,d,s} = c
  Counters{w,b,U32.inc(p),W.add(pb,W.of_u32(bytes)),d,s}

def draw(c:Counters) -> Counters:
  Counters{w,b,p,pb,d,s} = c
  Counters{w,b,p,pb,U32.inc(d),s}

def draw_count(c:Counters) -> U32:
  Counters{w,b,p,pb,d,s} = c
  d

def push_count(c:Counters) -> U32:
  Counters{w,b,p,pb,d,s} = c
  p

import Base
import ./common.bend as C
import ./corpus.bend as Corpus

def word(+n:U32) -> List<&2,U32>:
  [(n >> 24n : U32),(n >> 16n .&. 255 : U32),(n >> 8n .&. 255 : U32),(n .&. 255 : U32)]

def crc_bits(n:Nat,+value:U32) -> U32:
  match n:
    case 0n:value
    case 1n+p:crc_bits(p,((value >> 1n) .^. Bool.pick(U32,U32.is_eq((value .&. 1 : U32),1),3988292384,0) : U32))

def crc(bytes:List<&2,U32>,value:U32) -> U32:
  match bytes:
    case []:(value .^. 4294967295 : U32)
    case h <> rest:crc(rest,crc_bits(8n,(value .^. h : U32)))

def chunk(+kind:List<&2,U32>,+bytes:List<&2,U32>) -> List<&2,U32>:
  List.append(&2,U32,word(U32.from_nat(List.length(&2,U32,bytes))),List.append(&2,U32,kind,List.append(&2,U32,bytes,word(crc(List.append(&2,U32,kind,bytes),4294967295)))))

def adler(bytes:List<&2,U32>,+a:U32,b:U32) -> U32:
  match bytes:
    case []:((b << 16n) .|. a : U32)
    case x <> rest:
      +next = ((a + x) % 65521 : U32)
      adler(rest,next,((b + next) % 65521 : U32))

def stored(+bytes:List<&2,U32>) -> List<&2,U32>:
  +n = U32.from_nat(List.length(&2,U32,bytes))
  +inv = (n .^. 65535 : U32)
  List.append(&2,U32,[1,(n .&. 255 : U32),(n >> 8n : U32),(inv .&. 255 : U32),(inv >> 8n : U32)],bytes)

def zlib(+bytes:List<&2,U32>,bad_adler:Bool) -> List<&2,U32>:
  List.append(&2,U32,[120,1],List.append(&2,U32,stored(bytes),word((adler(bytes,1,0) .^. Bool.pick(U32,bad_adler,1,0) : U32))))

def header(w:U32,h:U32,depth:U32,color:U32) -> List<&2,U32>:
  chunk([73,72,68,82],List.append(&2,U32,word(w),List.append(&2,U32,word(h),[depth,color,0,0,0])))

def file(w:U32,h:U32,depth:U32,color:U32,data:List<&2,U32>,bad_adler:Bool,+raw:Bool) -> List<&2,U32>:
  +head = header(w,h,depth,color)
  +data = data
  List.append(&2,U32,[137,80,78,71,13,10,26,10],List.append(&2,U32,Bool.pick(List<&2,U32>,raw,chunk([67,103,66,73],[]),[]),List.append(&2,U32,head,List.append(&2,U32,chunk([73,68,65,84],Bool.pick(List<&2,U32>,raw,stored(data),zlib(data,bad_adler))),chunk([73,69,78,68],[])))))

def one() -> List<&2,U32>:file(1,1,8,6,[0,17,34,51,128],False{},False{})

def save(+name:String,bytes:List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    C.write(Corpus.output() ++ "/" ++ name ++ ".png",bytes)
    C.write(Corpus.output() ++ "/" ++ name ++ ".rgba",[17,34,51,128])

def cases() -> List<&2,Corpus.Case>:
  [Corpus.Case{"stored",1,1,8},Corpus.Case{"bad-byte",1,1,8},Corpus.Case{"bad-crc",1,1,8},Corpus.Case{"bad-adler",1,1,8},Corpus.Case{"trailing",1,1,8},Corpus.Case{"duplicate-ihdr",1,1,8},Corpus.Case{"cgbi",1,1,8},
   Corpus.Case{"empty",1,1,8},Corpus.Case{"truncated",1,1,8},Corpus.Case{"bad-signature",1,1,8},Corpus.Case{"unsupported",1,1,8},Corpus.Case{"zero-width",1,1,8},Corpus.Case{"width4097",1,1,8},Corpus.Case{"height4097",1,1,8},Corpus.Case{"filtered-over-limit",1,1,8},Corpus.Case{"inflate-overrun",1,1,8},Corpus.Case{"inflate-short",1,1,8},Corpus.Case{"bad-filter",1,1,8},Corpus.Case{"input-at-limit",1,1,8},Corpus.Case{"input-over-limit",1,1,8}]

def main() -> IO(Unit):
  do IO<Unit>:
    save("stored",one())
    save("bad-byte",one())
    save("bad-crc",List.set(&2,U32,one(),29n,0))
    save("bad-adler",file(1,1,8,6,[0,17,34,51,128],True{},False{}))
    save("trailing",List.append(&2,U32,one(),[1,2,3]))
    save("duplicate-ihdr",List.append(&2,U32,List.take(&2,U32,one(),33n),List.append(&2,U32,header(1,1,8,6),List.drop(&2,U32,one(),33n))))
    save("cgbi",file(1,1,8,6,[0,17,34,51,128],False{},True{}))
    save("empty",[])
    save("truncated",List.take(&2,U32,one(),50n))
    save("bad-signature",List.set(&2,U32,one(),0n,0))
    save("unsupported",file(1,1,3,6,[0,17,34,51,128],False{},False{}))
    save("zero-width",file(0,1,8,6,[0,17,34,51,128],False{},False{}))
    save("width4097",file(4097,1,8,6,[],False{},False{}))
    save("height4097",file(1,4097,8,6,[],False{},False{}))
    save("filtered-over-limit",file(4096,4096,8,6,[],False{},False{}))
    save("inflate-overrun",file(1,1,8,6,[0,17,34,51,128,0,0,0,0,0],False{},False{}))
    save("inflate-short",file(1,1,8,6,[0,17,34],False{},False{}))
    save("bad-filter",file(1,1,8,6,[5,17,34,51,128],False{},False{}))
    save("input-at-limit",List.append(&2,U32,one(),List.replicate(U32,Nat.sub(2097152n,List.length(&2,U32,one())),0)))
    save("input-over-limit",List.append(&2,U32,one(),List.replicate(U32,Nat.sub(2097153n,List.length(&2,U32,one())),0)))

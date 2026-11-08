import Base
import ./window-verification/check.bend as Check

def sent(pair:Socket & Result<&1,&1,(U32 & String) & List<&2,U32>,Unit>) -> IO(Socket):
  match pair:
    case (socket,Done{_}):IO.pure(Socket,socket)
    case _:IO.die(Socket,1,"X11 protocol send refused")

def send(socket:Socket,bytes:List<&2,U32>) -> IO(Socket):
  do IO<Socket>:
    result:Socket & Result<&1,&1,(U32 & String) & List<&2,U32>,Unit> <- TCP.send_bytes(socket,bytes)
    sent(result)

def received(next:Socket -> List<&2,U32> -> IO(Socket & List<&2,U32>),pair:Socket & Result<&1,&1,U32 & String,Maybe<&1,List<&2,U32>>>) -> IO(Socket & List<&2,U32>):
  match pair:
    case (socket,Done{Some{bytes}}):next(socket,bytes)
    case _:IO.die(Socket & List<&2,U32>,1,"X11 protocol connection ended")

def exact(n:Nat,socket:Socket,acc:List<&2,U32>) -> IO(Socket & List<&2,U32>):
  match n:
    case 0n:IO.pure(Socket & List<&2,U32>,(socket,List.reverse(&2,U32,acc)))
    case 1n+rest:
      do IO<Socket & List<&2,U32>>:
        pair:Socket & Result<&1,&1,U32 & String,Maybe<&1,List<&2,U32>>> <- TCP.recv_bytes(socket,1)
        received(socket => bytes => exact(rest,socket,List.append(&2,U32,bytes,acc)),pair)

def le(+word:U32) -> List<&2,U32>:
  [U32.and(word,255),U32.and(U32.div(word,256),255),U32.and(U32.div(word,65536),255),U32.and(U32.div(word,16777216),255)]

def focus_reply(id:U32,pair:Socket & List<&2,U32>) -> IO(Unit):
  match pair:
    case (socket,1 <> _ <> _ <> _ <> _ <> _ <> _ <> _ <> a <> b <> c <> d <> _):
      do IO<Unit>:
        Check.assert(U32.is_eq(id,U32.add(a,U32.add(U32.mul(b,256),U32.add(U32.mul(c,65536),U32.mul(d,16777216))))),"X11 server did not accept requested real focus")
        Socket.close(socket)
    case _:IO.die(Unit,1,"X11 focus reply invalid")

def focused(+id:U32,pair:Socket & List<&2,U32>) -> IO(Unit):
  (socket,_) = pair
  do IO<Unit>:
    socket:Socket <- send(socket,List.append(&2,U32,[42,0,3,0],List.append(&2,U32,le(id),[0,0,0,0,43,0,1,0])))
    reply:Socket & List<&2,U32> <- exact(32n,socket,[])
    focus_reply(id,reply)

def setup(id:U32,pair:Socket & List<&2,U32>) -> IO(Unit):
  match pair:
    case (socket,[1,_,_,_,_,_,lo,hi]):
      do IO<Unit>:
        remaining:Socket & List<&2,U32> <- exact(U32.to_nat(U32.mul(4,U32.add(lo,U32.mul(hi,256)))),socket,[])
        focused(id,remaining)
    case _:IO.die(Unit,1,"Owned X11 TCP server requires unauthenticated setup")

def set(+port:U32,id:U32) -> IO(Unit):
  do IO<Unit>:
    socket:Socket <- IO.try(Socket,TCP.connect("127.0.0.1",port))
    socket:Socket <- send(socket,[108,0,11,0,0,0,0,0,0,0,0,0])
    header:Socket & List<&2,U32> <- exact(8n,socket,[])
    setup(id,header)
    IO.sleep(100)

def word(bytes:List<&2,U32>) -> U32:
  match bytes:
    case a <> b <> c <> d <> _:U32.add(a,U32.add(U32.mul(b,256),U32.add(U32.mul(c,65536),U32.mul(d,16777216))))
    case _:0

def choose_keysym(found:Bool,index:U32,next:Maybe<&2,U32>) -> Maybe<&2,U32>:
  match found:
    case True{}:Some{index}
    case False{}:next

def keysym(values:List<&2,U32>,+symbol:U32,+per:U32,+index:U32) -> Maybe<&2,U32>:
  match values:
    case a <> b <> c <> d <> rest:choose_keysym(U32.is_zero(U32.mod(index,per)) && U32.is_eq(word([a,b,c,d]),symbol),index,keysym(rest,symbol,per,U32.inc(index)))
    case _:None{}

def first(bytes:List<&2,U32>) -> U32:
  match bytes:
    case x <> _:x
    case []:0

def sync_reply(pair:Socket & List<&2,U32>) -> IO(Unit):
  (socket,bytes) = pair
  do IO<Unit>:
    Check.assert(U32.is_eq(first(bytes),1),"X11 event synchronization failed")
    Socket.close(socket)

def inject(+id:U32,+down:Bool,keycode:U32,socket:Socket) -> IO(Unit):
  do IO<Unit>:
    socket:Socket <- send(socket,List.concat(&2,U32,[[25,0,11,0],le(id),le(Bool.pick(U32,down,1,2)),[Bool.pick(U32,down,2,3),keycode,0,0],le(0),le(0),le(id),le(0),[0,0,0,0,0,0,0,0,0,0,1,0],[43,0,1,0]]))
    reply:Socket & List<&2,U32> <- exact(32n,socket,[])
    sync_reply(reply)

def mapped(id:U32,down:Bool,per:U32,socket:Socket,result:Maybe<&2,U32>) -> IO(Unit):
  match result:
    case Some{index}:inject(id,down,U32.add(8,U32.div(index,per)),socket)
    case _:IO.die(Unit,1,"X11 keymap lacks requested keysym")

def mapping_body(id:U32,down:Bool,+symbol:U32,+per:U32,pair:Socket & List<&2,U32>) -> IO(Unit):
  (socket,bytes) = pair
  mapped(id,down,per,socket,keysym(bytes,symbol,per,0))

def mapping_header(id:U32,down:Bool,symbol:U32,pair:Socket & List<&2,U32>) -> IO(Unit):
  match pair:
    case (socket,1 <> +per <> _ <> _ <> a <> b <> c <> d <> _):
      do IO<Unit>:
        Check.assert(U32.is_gt(per,0),"X11 keyboard map has zero width")
        body:Socket & List<&2,U32> <- exact(U32.to_nat(U32.mul(word([a,b,c,d]),4)),socket,[])
        mapping_body(id,down,symbol,per,body)
    case _:IO.die(Unit,1,"X11 keyboard map rejected")

def keyboard_setup(id:U32,down:Bool,symbol:U32,pair:Socket & List<&2,U32>) -> IO(Unit):
  (socket,_) = pair
  do IO<Unit>:
    socket:Socket <- send(socket,[101,0,2,0,8,248,0,0])
    header:Socket & List<&2,U32> <- exact(32n,socket,[])
    mapping_header(id,down,symbol,header)

def key_setup(id:U32,down:Bool,symbol:U32,pair:Socket & List<&2,U32>) -> IO(Unit):
  match pair:
    case (socket,[1,_,_,_,_,_,lo,hi]):
      do IO<Unit>:
        body:Socket & List<&2,U32> <- exact(U32.to_nat(U32.mul(4,U32.add(lo,U32.mul(hi,256)))),socket,[])
        keyboard_setup(id,down,symbol,body)
    case _:IO.die(Unit,1,"X11 keyboard connection rejected")

def key(port:U32,id:U32,symbol:U32,down:Bool) -> IO(Unit):
  do IO<Unit>:
    socket:Socket <- IO.try(Socket,TCP.connect("127.0.0.1",port))
    socket:Socket <- send(socket,[108,0,11,0,0,0,0,0,0,0,0,0])
    header:Socket & List<&2,U32> <- exact(8n,socket,[])
    key_setup(id,down,symbol,header)

def burst_ready(+id:U32,pair:Socket & List<&2,U32>) -> IO(Unit):
  (socket,_) = pair
  do IO<Unit>:
    socket:Socket <- send(socket,List.concat(&2,U32,[[42,0,3,0],le(0),le(0),[42,0,3,0],le(id),le(0),[43,0,1,0]]))
    reply:Socket & List<&2,U32> <- exact(32n,socket,[])
    focus_reply(id,reply)

def burst_setup(id:U32,pair:Socket & List<&2,U32>) -> IO(Unit):
  match pair:
    case (socket,[1,_,_,_,_,_,lo,hi]):
      do IO<Unit>:
        body:Socket & List<&2,U32> <- exact(U32.to_nat(U32.mul(4,U32.add(lo,U32.mul(hi,256)))),socket,[])
        burst_ready(id,body)
    case _:IO.die(Unit,1,"X11 burst connection rejected")

def burst(port:U32,id:U32) -> IO(Unit):
  do IO<Unit>:
    socket:Socket <- IO.try(Socket,TCP.connect("127.0.0.1",port))
    socket:Socket <- send(socket,[108,0,11,0,0,0,0,0,0,0,0,0])
    header:Socket & List<&2,U32> <- exact(8n,socket,[])
    burst_setup(id,header)

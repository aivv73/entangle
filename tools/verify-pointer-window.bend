import Base
import ./mesh-x11-focus.bend as X
import ../deps/bend-vulkan/tools/window_verification/bridge.bend as Host
import ../deps/bend-vulkan/examples/verify_window.bend as Existing
import ../deps/bend-vulkan/tools/verification.bend as Check

def event(+id:U32,kind:U32,+button:U32,mask:U32) -> List<&2,U32>:
  List.concat(&2,U32,[[25,0,11,0],X.le(id),X.le(mask),[kind,button,0,0],X.le(U32.add(305419896,button)),X.le(0),X.le(id),X.le(0),[0,0,0,0,244,255,34,0,0,0,1,0]])

def inject(+id:U32,pair:Socket & List<&2,U32>) -> IO(Unit):
  (socket,_) = pair
  do IO<Unit>:
    socket:Socket <- X.send(socket,List.concat(&2,U32,[event(id,4,1,4),event(id,5,1,8),event(id,4,2,4),event(id,5,2,8),event(id,4,3,4),event(id,5,3,8),event(id,6,0,64),event(id,4,4,4),event(id,4,7,4),[43,0,1,0]]))
    reply:Socket & List<&2,U32> <- X.exact(32n,socket,[])
    X.sync_reply(reply)

def setup(id:U32,pair:Socket & List<&2,U32>) -> IO(Unit):
  match pair:
    case (socket,[1,_,_,_,_,_,lo,hi]):
      do IO<Unit>:
        body:Socket & List<&2,U32> <- X.exact(U32.to_nat(U32.mul(4,U32.add(lo,U32.mul(hi,256)))),socket,[])
        inject(id,body)
    case _:IO.die(Unit,1,"Pointer probe requires the owned unauthenticated X11 server")

def parsed_port(value:Maybe<&2,U32>) -> IO(U32):
  match value:
    case Some{port}:IO.pure(U32,port)
    case _:IO.die(U32,1,"Invalid owned X11 port")

def main() -> IO(Unit):
  do IO<Unit>:
    port:String <- IO.try(String,IO.get_env("ENTANGLE_X11_PORT"))
    number:U32 <- parsed_port(U32.read(port))
    +pid:U32 <- IO.try(U32,Host.start("build/pointer-window.log",False{}))
    id:U32 <- Existing.wait_window(100n,pid)
    socket:Socket <- IO.try(Socket,TCP.connect("127.0.0.1",number))
    socket:Socket <- X.send(socket,[108,0,11,0,0,0,0,0,0,0,0,0])
    header:Socket & List<&2,U32> <- X.exact(8n,socket,[])
    setup(id,header)
    Existing.wait_exit(150n,pid)
    +log:String <- Check.read("build/pointer-window.log")
    Check.assert(String.contains(log,"Native Press buttons/down/up, Tool.Mouse, signed F32 coordinates, timestamps, Move and Scroll verified.") && String.contains(log,"Pointer window closed; live Vulkan objects: 0") && Check.clean_diagnostics(log),"Pointer event qualification or cleanup failed")
    IO.write(log)

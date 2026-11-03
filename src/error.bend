import Base
import ../deps/bend-vulkan/Vulkan.bend as V

def failure(-A:Type,code:U32,message:String) -> V.Action(A):
  IO.pure(V.VkResult(A),Fail{(code,message)})

def require(ok:Bool,message:String) -> V.Action(Unit):
  match ok:
    case True{}:V.Action.pure(Unit,Unit{})
    case False{}:failure(Unit,1,message)

def owner(-A:Type,-E:Data,-B:Data,pair:A & Result<&2,&2,E,B>,message:String) -> V.Action(A):
  match pair:
    case (value,Done{_}):V.Action.pure(A,value)
    case _:failure(A,1,message)

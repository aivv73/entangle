import Base
import ../../deps/jonlib-obj/obj.bend as J
import ../image-decoder/common.bend as C

def bytes(chars:List<&2,Char>) -> List<&2,U32>:
  match chars:
    case []:[]
    case c <> rest:Char.to_u32(c) <> bytes(rest)

def text(s:String) -> List<&2,U32>:bytes(String.to_list(s))

def same(a:Maybe<&2,U32>,b:Maybe<&2,U32>) -> Bool:
  match a b:
    case None{},None{}:True{}
    case Some{x},Some{y}:U32.is_eq(x,y)
    case _,_:False{}

def parsed(p:J.Parsed) -> Maybe<&2,U32>:
  match p:
    case J.Parsed{False{},Some{v}}:Some{F32.bits(v)}
    case _:None{}

def numeric(+token:String,expected:Maybe<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    C.require(same(parsed(J.parse.double(False{},text(token))),expected),"S41 numeric mismatch " ++ token)
    IO.print("numeric " ++ token ++ " checked")

def positions(ps:List<&2,J.Parsed>,words:List<&2,U32>) -> Bool:
  match ps words:
    case [],[]:True{}
    case p <> rest,w <> tail:same(parsed(p),Some{w}) && positions(rest,tail)
    case _,_:False{}

def corner(c:J.FC) -> Maybe<&2,U32>:
  match c:
    case J.FC{J.Fix{True{},i},J.Fix{False{},_},J.Fix{False{},_}}:Some{i}
    case _:None{}

def triangles(fs:List<&2,J.Tri>,expected:List<&2,U32>) -> Bool:
  match fs expected:
    case [],[]:True{}
    case J.Tri{a,b,c,m} <> rest,x <> y <> z <> material <> tail:
      same(corner(a),Some{x}) && same(corner(b),Some{y}) && same(corner(c),Some{z}) && U32.is_eq(m,material) && triangles(rest,tail)
    case _,_:False{}

def show_positions(ps:List<&2,J.Parsed>) -> String:
  match ps:
    case []:""
    case J.Parsed{+ub,Some{v}} <> rest:Bool.show(ub) ++ "/" ++ U32.show(F32.bits(v)) ++ " " ++ show_positions(rest)
    case J.Parsed{+ub,None{}} <> rest:Bool.show(ub) ++ "/None " ++ show_positions(rest)

def show_corner(c:J.FC) -> String:
  J.FC{J.Fix{ok,i},_,_} = c
  Bool.show(ok) ++ "/" ++ U32.show(i)

def show_triangles(fs:List<&2,J.Tri>) -> String:
  match fs:
    case []:""
    case J.Tri{a,b,c,m} <> rest:show_corner(a) ++ " " ++ show_corner(b) ++ " " ++ show_corner(c) ++ " material=" ++ U32.show(m) ++ "\n" ++ show_triangles(rest)

def show_raw(raw:J.Raw) -> String:
  match raw:
    case J.Missing{}:"missing"
    case J.RawInt{negative,value}:Bool.pick(String,negative,"-","+") ++ U32.show(value)

def show_corners(corners:List<&2,J.Corner>) -> String:
  match corners:
    case []:""
    case J.Corner{v,vt,vn} <> rest:show_raw(v) ++ "/" ++ show_raw(vt) ++ "/" ++ show_raw(vn) ++ " " ++ show_corners(rest)

def show_bytes(bs:List<&2,U32>) -> String:
  match bs:
    case []:""
    case c <> rest:SCon{Char.from_u32(c),show_bytes(rest)}

def show_commands(commands:List<&2,J.Cmd>) -> String:
  match commands:
    case []:""
    case J.CV{x,y,z} <> rest:"CV " ++ show_positions([x,y,z]) ++ "\n" ++ show_commands(rest)
    case J.CF{corners,count} <> rest:"CF count=" ++ U32.show(count) ++ " " ++ show_corners(corners) ++ "\n" ++ show_commands(rest)
    case J.CUse{name} <> rest:"CUse " ++ show_bytes(name) ++ "\n" ++ show_commands(rest)
    case J.CLib{name} <> rest:"CLib " ++ show_bytes(name) ++ "\n" ++ show_commands(rest)
    case J.CShape{} <> rest:"CShape\n" ++ show_commands(rest)
    case J.CEmpty{} <> rest:"CEmpty\n" ++ show_commands(rest)
    case _ <> rest:"unexpected command\n" ++ show_commands(rest)

def show_materials(values:List<&2,J.Mtl>,+index:U32) -> String:
  match values:
    case []:""
    case J.Mtl{d,s,e,ns,_,_,_,_} <> rest:"material=" ++ U32.show(index) ++ " diffuse=" ++ show_positions(d) ++ " specular=" ++ show_positions(s) ++ " emission=" ++ show_positions(e) ++ " shininess=" ++ show_positions([ns]) ++ "\n" ++ show_materials(rest,U32.inc(index))

def attributes(a:J.Attrib) -> IO(Unit):
  J.Attrib{ok,+ps,ns,ts,nv,nn,nt,+fs,_} = a
  do IO<Unit>:
    C.require(ok && U32.is_eq(nv,12) && U32.is_zero(nn) && U32.is_zero(nt) && List.is_empty(&2,J.Parsed,ns) && List.is_empty(&2,J.Parsed,ts),"S41 attribute counts")
    C.require(positions(ps,[3225419776,3212836864,0,3212836864,3212836864,0,3212836864,1065353216,0,3225419776,1065353216,0,3212836864,3212836864,0,1065353216,3212836864,0,1065353216,1065353216,0,3212836864,1065353216,0,1065353216,3212836864,2147483648,1077936128,3212836864,0,1077936128,1065353216,0,1065353216,1065353216,0]),"S41 complete position words")
    C.require(triangles(fs,[0,1,2,4294967295,0,2,3,4294967295,4,5,6,0,4,6,7,0,8,9,10,1,8,10,11,1]),"S41 complete ordered indices/materials")
    IO.print("sign positions ub/word " ++ show_positions(ps))
    IO.write(show_triangles(fs))
    IO.print("S41 retained authored sign exact 36 position words, 18 corners, six material selections including default and negative-relative indices.")

def diffuse(values:List<&2,J.Mtl>) -> Bool:
  match values:
    case [J.Mtl{a,_,_,_,_,_,_,_},J.Mtl{b,_,_,_,_,_,_,_}]:positions(a,[1065353216,0,0]) && positions(b,[0,1065353216,0])
    case _:False{}

def materials(m:J.MtlOut,+commands:List<&2,J.Cmd>) -> IO(Unit):
  J.MtlOut{ok,+values,+table} = m
  do IO<Unit>:
    C.require(ok && J.table.ok(table),"S41 MTL or table refusal")
    C.require(Nat.is_eq(List.length(&2,J.Mtl,values),2n),"S41 material count")
    C.require(diffuse(values),"S41 exact diffuse words")
    IO.print("MtlOut.ok=True table.ok=True material-count=2")
    IO.write(show_materials(values,0))
    IO.write(show_commands(commands))
    attributes(J.attributes(commands,table))

def source(obj:J.Lines,mtl:List<&2,U32>) -> IO(Unit):
  J.Lines{ok,lines} = obj
  do IO<Unit>:
    C.require(ok,"S41 lines refused")
    materials(J.mtl.parse(False{},mtl),J.commands(lines,False{},[]))

def wedge_attrib(a:J.Attrib) -> IO(Unit):
  J.Attrib{ok,+ps,_,_,nv,_,_,+fs,_} = a
  do IO<Unit>:
    C.require(ok && U32.is_eq(nv,6) && positions(ps,[3212836864,3212836864,0,1065353216,3212836864,0,1065353216,1065353216,0,3212836864,1065353216,0,3212836864,3212836864,1065353216,1065353216,3212836864,1073741824]),"S41 exported wedge complete positions")
    C.require(triangles(fs,[0,2,1,4294967295,0,3,2,4294967295,0,1,5,4294967295,0,5,4,4294967295,1,2,5,4294967295,2,3,4,4294967295,2,4,5,4294967295,3,0,4,4294967295]),"S41 exported wedge complete corners")
    IO.print("wedge positions ub/word " ++ show_positions(ps))
    IO.write(show_triangles(fs))
    IO.print("S41 Blender 5.2.3 closed asymmetric wedge matches independent six-vertex/eight-face authoring specification.")

def wedge(lines:J.Lines) -> IO(Unit):
  J.Lines{ok,ls} = lines
  do IO<Unit>:
    C.require(ok,"S41 wedge lines")
    wedge_attrib(J.attributes(J.commands(ls,False{},[]),J.table.new()))

def crowded_materials(n:Nat) -> String:
  match n:
    case 0n:""
    case 1n+ +rest:"newmtl m" ++ Nat.show(rest) ++ "\nKd 0 0 0\n" ++ crowded_materials(rest)

def table_refusal(value:J.MtlOut) -> IO(Unit):
  J.MtlOut{ok,materials,table} = value
  do IO<Unit>:
    C.require(ok && Bool.not(J.table.ok(table)) && Nat.is_eq(List.length(&2,J.Mtl,materials),128n),"Expected actual source-table probe refusal")
    IO.print("Actual 128-declaration MTL has MtlOut.ok=True and table.ok=False; both flags require checking.")

def main() -> IO(Unit):
  do IO<Unit>:
    obj:List<&2,U32> <- C.read("docs/verification/2026-11-04-model-obj/corpus/sign.obj")
    mtl:List<&2,U32> <- C.read("docs/verification/2026-11-04-model-obj/corpus/sign.mtl")
    source(J.lines(obj),mtl)
    exported:List<&2,U32> <- C.read("docs/verification/2026-11-04-model-obj/corpus/wedge.obj")
    wedge(J.lines(exported))
    table_refusal(J.mtl.parse(False{},text(crowded_materials(128n))))
    numeric("-0",Some{2147483648})
    numeric("+0",Some{0})
    numeric("1.5",Some{1069547520})
    numeric("1.000000059604644775390625",Some{1065353216})
    numeric("1.00000011920928955078125",Some{1065353217})
    numeric("1e-20",Some{507307272})
    numeric("1e38",Some{2123789977})
    numeric("1e-45",Some{1})
    numeric("1e-46",Some{0})
    numeric("-1e-46",Some{2147483648})
    numeric("1e39",None{})
    numeric("1e65",None{})
    numeric("1e2147483648",None{})
    numeric("1junk",Some{1065353216})
    numeric(".5",Some{0})
    numeric("1e",Some{0})
    C.require(J.h64.eq(J.djb2(text("ab")),J.djb2(text("bA"))),"Expected real djb2 collision")
    C.require(Bool.not(J.table.ok(J.table.set(J.Table{True{},1,0,[],[0],[]},J.djb2(text("x")),0))),"Expected bounded table-probe refusal")
    IO.print("Pinned parser qualification passed. Prefix/zero/line quirks require adapter admission. No universal decimal conversion claim.")

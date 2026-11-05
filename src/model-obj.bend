import Base
import ./asset.bend as Asset
import ./content.bend as F
import ./components.bend as C
import ../deps/jonlib-obj/obj.bend as J

def obj_limit() -> Nat:2097152n
def mtl_limit() -> Nat:262144n
def line_limit() -> Nat:4095n
def numeric_limit() -> Nat:64n
def label_limit() -> Nat:255n
def material_limit() -> Nat:128n
def part_limit() -> Nat:4096n
def path_limit() -> Nat:4096n

def error(code:U32,source:String,line:Nat,reason:String) -> Asset.Error:
  Asset.Error{U32.add(2147483904,code),source ++ " line " ++ Nat.show(line) ++ ": " ++ reason}

def need(ok:Bool,code:U32,source:String,line:Nat,reason:String) -> Result<&2,&2,Asset.Error,Unit>:
  match ok:
    case True{}:Done{Unit{}}
    case False{}:Fail{error(code,source,line,reason)}

def bytes(chars:List<&2,Char>) -> List<&2,U32>:
  match chars:
    case []:[]
    case c <> rest:Char.to_u32(c) <> bytes(rest)

def text(s:String) -> List<&2,U32>:bytes(String.to_list(s))

def string(bs:List<&2,U32>) -> String:
  match bs:
    case []:""
    case c <> rest:SCon{Char.from_u32(c),string(rest)}

def uncomment(bs:List<&2,U32>) -> List<&2,U32>:
  match bs:
    case []:[]
    case 35 <> _:[]
    case c <> rest:c <> uncomment(rest)

def push_word(+word:List<&2,U32>,+acc:List<&2,String>) -> List<&2,String>:
  Bool.pick(List<&2,String>,List.is_empty(&2,U32,word),acc,string(List.reverse(&2,U32,word)) <> acc)

def tokens_go(bs:List<&2,U32>,word:List<&2,U32>,acc:List<&2,String>) -> List<&2,String>:
  match bs:
    case []:List.reverse(&2,String,push_word(word,acc))
    case 9 <> rest:tokens_go(rest,[],push_word(word,acc))
    case 32 <> rest:tokens_go(rest,[],push_word(word,acc))
    case c <> rest:tokens_go(rest,c <> word,acc)

def tokens(+bs:List<&2,U32>) -> List<&2,String>:
  tokens_go(uncomment(bs),[],[])

type Line is Data:
  Line{number:Nat,words:List<&2,String>}

def last_content(bs:List<&2,U32>,previous:U32) -> U32:
  match bs:
    case []:previous
    case 9 <> rest:last_content(rest,previous)
    case 32 <> rest:last_content(rest,previous)
    case c <> rest:last_content(rest,c)

def line_words(+raw:List<&2,U32>,+source:String,+number:Nat) -> Result<&2,&2,Asset.Error,List<&2,String>>:
  do Result<&2,&2,Asset.Error,List<&2,String>>:
    _:Unit <- need(U32.is_ne(last_content(uncomment(raw),0),92),2,source,number,"line continuation")
    return tokens(raw)

def scan(bs:List<&2,U32>,+source:String,+number:Nat,+width:Nat,cr:Bool,line:List<&2,U32>,out:List<&2,Line>) -> Result<&2,&2,Asset.Error,List<&2,Line>>:
  match bs:
    case []:
      do Result<&2,&2,Asset.Error,List<&2,Line>>:
        _:Unit <- need(Bool.not(cr),1,source,number,"lone CR")
        words:List<&2,String> <- line_words(List.reverse(&2,U32,line),source,number)
        return List.reverse(&2,Line,Line{number,words} <> out)
    case 10 <> rest:
      do Result<&2,&2,Asset.Error,List<&2,Line>>:
        words:List<&2,String> <- line_words(List.reverse(&2,U32,line),source,number)
        scan(rest,source,1n+number,0n,False{},[],Line{number,words} <> out)
    case 13 <> rest:
      do Result<&2,&2,Asset.Error,List<&2,Line>>:
        _:Unit <- need(Bool.not(cr),1,source,number,"lone CR")
        _:Unit <- need(Nat.is_lt(width,line_limit()),7,source,number,"physical line exceeds 4095 bytes")
        scan(rest,source,number,1n+width,True{},line,out)
    case +c <> rest:
      do Result<&2,&2,Asset.Error,List<&2,Line>>:
        _:Unit <- need(Bool.not(cr),1,source,number,"lone CR")
        _:Unit <- need(U32.is_eq(c,9) || (U32.is_ge(c,32) && U32.is_le(c,126)),1,source,number,"expected ASCII text without controls or NUL")
        _:Unit <- need(Nat.is_lt(width,line_limit()),7,source,number,"physical line exceeds 4095 bytes")
        scan(rest,source,number,1n+width,False{},c <> line,out)

def lines(+bs:List<&2,U32>,+source:String,limit:Nat) -> Result<&2,&2,Asset.Error,List<&2,Line>>:
  do Result<&2,&2,Asset.Error,List<&2,Line>>:
    _:Unit <- need(Nat.is_le(List.length(&2,U32,bs),limit),7,source,0n,"encoded byte limit")
    scan(bs,source,1n,0n,False{},[],[])

def number_step(+state:U32,+c:U32) -> U32:
  +digit = J.is_digit(c)
  +sign = U32.is_eq(c,43) || U32.is_eq(c,45)
  +dot = U32.is_eq(c,46)
  +exponent = J.is_e(c)
  Bool.pick(U32,(U32.is_eq(state,0) || U32.is_eq(state,1)) && digit,2,
    Bool.pick(U32,U32.is_eq(state,0) && sign,1,
    Bool.pick(U32,(U32.is_eq(state,2) || U32.is_eq(state,3) || U32.is_eq(state,4)) && digit,Bool.pick(U32,U32.is_eq(state,2),2,4),
    Bool.pick(U32,U32.is_eq(state,2) && dot,3,
    Bool.pick(U32,(U32.is_eq(state,2) || U32.is_eq(state,3) || U32.is_eq(state,4)) && exponent,5,
    Bool.pick(U32,U32.is_eq(state,5) && sign,6,
    Bool.pick(U32,(U32.is_eq(state,5) || U32.is_eq(state,6) || U32.is_eq(state,7)) && digit,7,99)))))))

def number_syntax(bs:List<&2,U32>,+state:U32) -> Bool:
  match bs:
    case []:U32.is_eq(state,2) || U32.is_eq(state,3) || U32.is_eq(state,4) || U32.is_eq(state,7)
    case c <> rest:number_syntax(rest,number_step(state,c))

def parsed(p:J.Parsed,+source:String,+line:Nat) -> Result<&2,&2,Asset.Error,F32>:
  match p:
    case J.Parsed{False{},Some{+value}}:
      do Result<&2,&2,Asset.Error,F32>:
        _:Unit <- need(F.finite(value),3,source,line,"nonfinite number")
        return value
    case _:Fail{error(3,source,line,"number outside pinned parser domain")}

def numeric(+token:String,+source:String,+line:Nat) -> Result<&2,&2,Asset.Error,F32>:
  do Result<&2,&2,Asset.Error,F32>:
    _:Unit <- need(Nat.is_le(List.length(&2,U32,text(token)),numeric_limit()),7,source,line,"numeric token exceeds 64 bytes")
    _:Unit <- need(number_syntax(text(token),0),3,source,line,"complete decimal token required")
    parsed(J.parse.double(False{},text(token)),source,line)

def digits(bs:List<&2,U32>) -> Bool:
  match bs:
    case []:True{}
    case c <> rest:J.is_digit(c) && digits(rest)

def unsigned_token(bs:List<&2,U32>) -> List<&2,U32>:
  match bs:
    case 43 <> rest:rest
    case 45 <> rest:rest
    case bs:bs

def index_checked(+raw:List<&2,U32>,+count:Nat,+line:Nat,atoi:J.Atoi) -> Result<&2,&2,Asset.Error,Unit>:
  J.Atoi{_,+value,overflow} = atoi
  +ds = unsigned_token(raw)
  do Result<&2,&2,Asset.Error,Unit>:
    _:Unit <- need(Nat.is_le(List.length(&2,U32,raw),numeric_limit()),7,"OBJ",line,"index token exceeds 64 bytes")
    _:Unit <- need(Bool.not(List.is_empty(&2,U32,ds)) && digits(ds) && Bool.not(overflow) && U32.is_gt(value,0),4,"OBJ",line,"nonzero complete signed 31-bit index required")
    need(Nat.is_le(U32.to_nat(value),count),4,"OBJ",line,"face index outside positions declared so far")

def index(+token:String,count:Nat,line:Nat) -> Result<&2,&2,Asset.Error,Unit>:
  index_checked(text(token),count,line,J.atoi(text(token)))

def names(values:List<&2,String>,+source:String,+line:Nat) -> Result<&2,&2,Asset.Error,Unit>:
  match values:
    case []:Done{Unit{}}
    case +name <> rest:
      do Result<&2,&2,Asset.Error,Unit>:
        _:Unit <- need(Nat.is_le(List.length(&2,U32,text(name)),label_limit()),7,source,line,"label exceeds 255 bytes")
        names(rest,source,line)

def join(words:List<&2,String>) -> String:
  match words:
    case []:""
    case word <> []:word
    case word <> rest:word ++ " " ++ join(rest)

def dependency_components(values:List<&2,String>) -> Bool:
  match values:
    case []:True{}
    case +value <> rest:Bool.not(String.eq(value,"") || String.eq(value,".") || String.eq(value,"..")) && dependency_components(rest)

def dependency_chars(bs:List<&2,U32>) -> Bool:
  match bs:
    case []:True{}
    case +c <> rest:U32.is_ge(c,33) && U32.is_le(c,126) && Bool.not(U32.is_eq(c,58) || U32.is_eq(c,92)) && dependency_chars(rest)

def dependency(+name:String) -> Bool:
  dependency_chars(text(name)) && dependency_components(String.split(name,'/')) && Bool.not(String.eq(name,""))

type Run is Data:
  Run{faces:Nat,labels:F.ModelLabels,line:Nat}
type Selection is Data:
  Selection{name:String,line:Nat}
type Plan is Data:
  Plan{commands:List<&2,J.Cmd>,runs:List<&2,Run>,library:Maybe<&2,String>,uses:List<&2,Selection>,vertices:Nat,faces:Nat}
type ObjState is Data:
  ObjState{plan:Plan,labels:F.ModelLabels}

def add_run(runs:List<&2,Run>,+labels:F.ModelLabels,line:Nat) -> List<&2,Run>:
  match runs:
    case []:[Run{1n,labels,line}]
    case Run{+count,+previous,+first} <> +rest:
      Bool.pick(List<&2,Run>,F.same_labels(labels,previous),Run{1n+count,previous,first} <> rest,Run{1n,labels,line} <> Run{count,previous,first} <> rest)

def run_fits(+runs:List<&2,Run>,labels:F.ModelLabels) -> Bool:
  match runs:
    case []:True{}
    case Run{_,previous,_} <> rest:F.same_labels(labels,previous) || Nat.is_lt(1n+List.length(&2,Run,rest),part_limit())

def obj_route(+word:String) -> U32:
  Bool.pick(U32,String.eq(word,"v"),1,Bool.pick(U32,String.eq(word,"f"),2,Bool.pick(U32,String.eq(word,"o"),3,Bool.pick(U32,String.eq(word,"g"),4,Bool.pick(U32,String.eq(word,"usemtl"),5,Bool.pick(U32,String.eq(word,"mtllib"),6,Bool.pick(U32,String.eq(word,"s"),7,0)))))))

def record(+words:List<&2,String>,plan:Plan,labels:F.ModelLabels) -> ObjState:
  Plan{commands,runs,lib,uses,vc,fc} = plan
  ObjState{Plan{J.parse.line(False{},text(join(words))) <> commands,runs,lib,uses,vc,fc},labels}

def obj_line(route:U32,args:List<&2,String>,+line:Nat,plan:Plan,+labels:F.ModelLabels) -> Result<&2,&2,Asset.Error,ObjState>:
  match route args:
    case 1,[+x,+y,+z]:
      Plan{cs,rs,lib,uses,+vc,fc} = plan
      do Result<&2,&2,Asset.Error,ObjState>:
        _:Unit <- need(Nat.is_lt(vc,699050n),7,"OBJ",line,"source position limit")
        _:F32 <- numeric(x,"OBJ",line)
        _:F32 <- numeric(y,"OBJ",line)
        _:F32 <- numeric(z,"OBJ",line)
        return record(["v",x,y,z],Plan{cs,rs,lib,uses,1n+vc,fc},labels)
    case 2,[+a,+b,+c]:
      Plan{cs,+rs,lib,uses,+vc,+fc} = plan
      do Result<&2,&2,Asset.Error,ObjState>:
        _:Unit <- need(F.mesh_fits(Nat.mul(3n,1n+fc),Nat.mul(3n,1n+fc)),7,"OBJ",line,"expanded geometry limit")
        _:Unit <- index(a,vc,line)
        _:Unit <- index(b,vc,line)
        _:Unit <- index(c,vc,line)
        _:Unit <- need(run_fits(rs,labels),7,"OBJ",line,"part limit")
        return record(["f",a,b,c],Plan{cs,add_run(rs,labels,line),lib,uses,vc,1n+fc},labels)
    case 3,[+name]:
      F.ModelLabels{_,g,m} = labels
      do Result<&2,&2,Asset.Error,ObjState>:
        _:Unit <- names([name],"OBJ",line)
        return ObjState{plan,F.ModelLabels{Some{name},g,m}}
    case 4,+groups:
      F.ModelLabels{o,_,m} = labels
      do Result<&2,&2,Asset.Error,ObjState>:
        _:Unit <- names(groups,"OBJ",line)
        return ObjState{plan,F.ModelLabels{o,groups,m}}
    case 5,[+name]:
      Plan{cs,rs,lib,uses,vc,fc} = plan
      F.ModelLabels{o,g,_} = labels
      do Result<&2,&2,Asset.Error,ObjState>:
        _:Unit <- names([name],"OBJ",line)
        return record(["usemtl",name],Plan{cs,rs,lib,Selection{name,line} <> uses,vc,fc},F.ModelLabels{o,g,Some{name}})
    case 6,[+name]:
      Plan{cs,rs,+lib,uses,vc,fc} = plan
      do Result<&2,&2,Asset.Error,ObjState>:
        _:Unit <- need(Bool.not(Maybe.is_some(&2,String,lib)),1,"OBJ",line,"duplicate mtllib")
        _:Unit <- need(dependency(name),6,"OBJ",line,"MTL requires relative slash-separated components without dot, parent or URI syntax")
        return ObjState{Plan{cs,rs,Some{name},uses,vc,fc},labels}
    case 7,[+value]:
      do Result<&2,&2,Asset.Error,ObjState>:
        _:Unit <- need(String.eq(value,"off") || String.eq(value,"0"),2,"OBJ",line,"active smoothing unsupported")
        return ObjState{plan,labels}
    case _,_:Fail{error(2,"OBJ",line,"unsupported directive or field count; authored triangles and bare indices required")}

def inspect_lines(ls:List<&2,Line>,state:ObjState) -> Result<&2,&2,Asset.Error,Plan>:
  match ls:
    case []:
      ObjState{Plan{cs,rs,lib,uses,vc,+fc},_} = state
      do Result<&2,&2,Asset.Error,Plan>:
        _:Unit <- need(Nat.is_gt(fc,0n),11,"OBJ",0n,"no triangles")
        return Plan{List.reverse(&2,J.Cmd,cs),List.reverse(&2,Run,rs),lib,List.reverse(&2,Selection,uses),vc,fc}
    case Line{_,[]} <> rest:inspect_lines(rest,state)
    case Line{+line,word <> args} <> rest:
      ObjState{plan,labels} = state
      do Result<&2,&2,Asset.Error,Plan>:
        next:ObjState <- obj_line(obj_route(word),args,line,plan,labels)
        inspect_lines(rest,next)

def prepare(bs:List<&2,U32>) -> Result<&2,&2,Asset.Error,Plan>:
  do Result<&2,&2,Asset.Error,Plan>:
    ls:List<&2,Line> <- lines(bs,"OBJ",obj_limit())
    inspect_lines(ls,ObjState{Plan{[],[],None{},[],0n,0n},F.ModelLabels{None{},[],None{}}})

def exact_scaled(+shape:U32,+zeros:Nat,+places:Nat,negative:Bool,exponent:J.Atoi,+one:Bool) -> Bool:
  J.Atoi{minus,+value,overflow} = exponent
  Bool.not(overflow) && U32.is_le(value,64) && Bool.pick(Bool,one,
    Bool.not(negative) && U32.is_eq(shape,1) && Bool.pick(Bool,minus,Nat.is_eq(zeros,Nat.add(places,U32.to_nat(value))),Nat.is_eq(Nat.add(zeros,U32.to_nat(value)),places)),
    U32.is_zero(shape))

def exact_digits(bs:List<&2,U32>,+shape:U32,+zeros:Nat,+places:Nat,+fraction:Bool,negative:Bool,one:Bool) -> Bool:
  match bs:
    case []:exact_scaled(shape,zeros,places,negative,J.Atoi{False{},0,False{}},one)
    case 46 <> rest:exact_digits(rest,shape,zeros,places,True{},negative,one)
    case 101 <> rest:exact_scaled(shape,zeros,places,negative,J.atoi(rest),one)
    case 69 <> rest:exact_scaled(shape,zeros,places,negative,J.atoi(rest),one)
    case +c <> rest:exact_digits(rest,Bool.pick(U32,U32.is_eq(c,48),shape,Bool.pick(U32,U32.is_zero(shape) && U32.is_eq(c,49),1,2)),Bool.pick(Nat,U32.is_eq(shape,1) && U32.is_eq(c,48),1n+zeros,zeros),Bool.pick(Nat,fraction,1n+places,places),fraction,negative,one)

def neutral(+token:String,one:Bool) -> Bool:
  exact_digits(unsigned_token(text(token)),0,0n,0n,False{},U32.is_eq(J.head(text(token)),45),one)

type NamedMaterial is Data:
  NamedMaterial{name:String,line:Nat,value:F.Material}
type MtlHead is Data:
  MtlHead{name:String,line:Nat,value:Maybe<&2,F.Material>,seen:U32}
type MtlState is Data:
  MtlState{current:Maybe<&2,MtlHead>,done:List<&2,NamedMaterial>,lines:List<&2,String>}
type Materials is Data:
  Materials{values:List<&2,NamedMaterial>,table:J.Table}

def known_collision(values:List<&2,NamedMaterial>,+name:String) -> Bool:
  match values:
    case []:False{}
    case NamedMaterial{other,_,_} <> rest:J.h64.eq(J.djb2(text(other)),J.djb2(text(name))) || known_collision(rest,name)

def flush(current:Maybe<&2,MtlHead>,done:List<&2,NamedMaterial>) -> Result<&2,&2,Asset.Error,List<&2,NamedMaterial>>:
  match current:
    case None{}:Done{done}
    case Some{MtlHead{name,line,Some{value},_}}:Done{NamedMaterial{name,line,value} <> done}
    case Some{MtlHead{_,line,None{},_}}:Fail{error(5,"MTL",line,"material requires exactly one Kd")}

def mtl_route(+word:String) -> U32:
  Bool.pick(U32,String.eq(word,"newmtl"),1,Bool.pick(U32,String.eq(word,"Kd"),2,Bool.pick(U32,String.eq(word,"d"),4,Bool.pick(U32,String.eq(word,"Tr"),8,Bool.pick(U32,String.eq(word,"illum"),16,0)))))

def diffuse_value(+x:String,+y:String,+z:String,+line:Nat) -> Result<&2,&2,Asset.Error,F.Material>:
  do Result<&2,&2,Asset.Error,F.Material>:
    r:F32 <- numeric(x,"MTL",line)
    g:F32 <- numeric(y,"MTL",line)
    b:F32 <- numeric(z,"MTL",line)
    +value:F.Material = F.Basic{C.Vec3{r,g,b}}
    _:Unit <- need(F.material_valid(value),5,"MTL",line,"Kd channels outside [0,1]")
    return value

def property_value(route:U32,args:List<&2,String>,+line:Nat,head:MtlHead) -> Result<&2,&2,Asset.Error,MtlHead>:
  match route args:
    case 2,[x,y,z]:
      MtlHead{name,first,_,seen} = head
      do Result<&2,&2,Asset.Error,MtlHead>:
        value:F.Material <- diffuse_value(x,y,z,line)
        return MtlHead{name,first,Some{value},seen}
    case +route,[+token]:
      do Result<&2,&2,Asset.Error,MtlHead>:
        _:Unit <- need(U32.is_eq(route,4) || U32.is_eq(route,8) || U32.is_eq(route,16),2,"MTL",line,"unsupported material property")
        _:F32 <- numeric(token,"MTL",line)
        _:Unit <- need(neutral(token,U32.is_eq(route,4)),5,"MTL",line,"only exact d 1, Tr 0 and illum 0 are neutral")
        return head
    case _,_:Fail{error(2,"MTL",line,"unsupported property or field count")}

def property(+route:U32,args:List<&2,String>,+line:Nat,head:MtlHead) -> Result<&2,&2,Asset.Error,MtlHead>:
  MtlHead{name,first,value,+seen} = head
  do Result<&2,&2,Asset.Error,MtlHead>:
    _:Unit <- need(U32.is_zero(U32.and(seen,route)),5,"MTL",line,"duplicate material property")
    property_value(route,args,line,MtlHead{name,first,value,U32.or(seen,route)})

def mtl_line(route:U32,+word:String,+args:List<&2,String>,+line:Nat,state:MtlState) -> Result<&2,&2,Asset.Error,MtlState>:
  match route args state:
    case 1,[+name],MtlState{current,done,ls}:
      do Result<&2,&2,Asset.Error,MtlState>:
        +done:List<&2,NamedMaterial> <- flush(current,done)
        _:Unit <- names([name],"MTL",line)
        _:Unit <- need(Nat.is_lt(List.length(&2,NamedMaterial,done),material_limit()),7,"MTL",line,"material limit")
        _:Unit <- need(Bool.not(known_collision(done,name)),5,"MTL",line,"duplicate or colliding material name")
        return MtlState{Some{MtlHead{name,line,None{},0}},done,join(word <> args) <> ls}
    case +route,args,MtlState{Some{head},done,ls}:
      do Result<&2,&2,Asset.Error,MtlState>:
        next:MtlHead <- property(route,args,line,head)
        return MtlState{Some{next},done,join(word <> args) <> ls}
    case _,_,_:Fail{error(5,"MTL",line,"property before newmtl or malformed declaration")}

def line_text(ls:List<&2,String>) -> String:
  match ls:
    case []:""
    case line <> rest:line ++ "\n" ++ line_text(rest)

def parsed_values(values:List<&2,J.Parsed>,+line:Nat) -> Result<&2,&2,Asset.Error,Unit>:
  match values:
    case []:Done{Unit{}}
    case value <> rest:
      do Result<&2,&2,Asset.Error,Unit>:
        _:F32 <- parsed(value,"MTL",line)
        parsed_values(rest,line)

def parsed_material(value:J.Mtl,+line:Nat) -> Result<&2,&2,Asset.Error,F.Material>:
  match value:
    case J.Mtl{[r,g,b],s,e,ns,None{},None{},None{},None{}}:
      do Result<&2,&2,Asset.Error,F.Material>:
        r:F32 <- parsed(r,"MTL",line)
        g:F32 <- parsed(g,"MTL",line)
        b:F32 <- parsed(b,"MTL",line)
        _:Unit <- parsed_values(s,line)
        _:Unit <- parsed_values(e,line)
        _:F32 <- parsed(ns,"MTL",line)
        return F.Basic{C.Vec3{r,g,b}}
    case _:Fail{error(9,"MTL",line,"unexpected upstream material layout")}

def check_materials(specs:List<&2,NamedMaterial>,values:List<&2,J.Mtl>) -> Result<&2,&2,Asset.Error,Unit>:
  match specs values:
    case [],[]:Done{Unit{}}
    case NamedMaterial{_,+line,wanted} <> rest,value <> tail:
      do Result<&2,&2,Asset.Error,Unit>:
        actual:F.Material <- parsed_material(value,line)
        _:Unit <- need(F.same_material(actual,wanted),9,"MTL",line,"upstream diffuse value mismatch")
        check_materials(rest,tail)
    case _,_:Fail{error(9,"MTL",0n,"upstream material count mismatch")}

def material_output(+specs:List<&2,NamedMaterial>,output:J.MtlOut) -> Result<&2,&2,Asset.Error,Materials>:
  J.MtlOut{ok,values,+table} = output
  do Result<&2,&2,Asset.Error,Materials>:
    _:Unit <- need(ok && J.table.ok(table),9,"MTL",0n,"pinned MTL parser or name table refused")
    _:Unit <- check_materials(specs,values)
    return Materials{specs,table}

def mtl_lines(ls:List<&2,Line>,state:MtlState) -> Result<&2,&2,Asset.Error,Materials>:
  match ls:
    case []:
      MtlState{current,done,lines} = state
      do Result<&2,&2,Asset.Error,Materials>:
        +specs:List<&2,NamedMaterial> <- flush(current,done)
        _:Unit <- need(Bool.not(List.is_empty(&2,NamedMaterial,specs)),5,"MTL",0n,"declared MTL contains no materials")
        material_output(List.reverse(&2,NamedMaterial,specs),J.mtl.parse(False{},text(line_text(List.reverse(&2,String,lines)))))
    case Line{_,[]} <> rest:mtl_lines(rest,state)
    case Line{+line,+word <> +args} <> rest:
      do Result<&2,&2,Asset.Error,Materials>:
        next:MtlState <- mtl_line(mtl_route(word),word,args,line,state)
        mtl_lines(rest,next)

def materials(bytes:List<&2,U32>) -> Result<&2,&2,Asset.Error,Materials>:
  do Result<&2,&2,Asset.Error,Materials>:
    ls:List<&2,Line> <- lines(bytes,"MTL",mtl_limit())
    mtl_lines(ls,MtlState{None{},[],[]})

type Selected is Data:
  Selected{index:U32,value:F.Material}

def named(values:List<&2,NamedMaterial>,+name:String,+line:Nat,+index:U32) -> Result<&2,&2,Asset.Error,Selected>:
  match values:
    case []:Fail{error(5,"OBJ",line,"unresolved usemtl " ++ name)}
    case NamedMaterial{other,_,value} <> rest:
      Bool.pick(Result<&2,&2,Asset.Error,Selected>,String.eq(name,other),Done{Selected{index,value}},named(rest,name,line,U32.inc(index)))

def selected(name:Maybe<&2,String>,values:List<&2,NamedMaterial>,line:Nat) -> Result<&2,&2,Asset.Error,Selected>:
  match name:
    case None{}:Done{Selected{4294967295,F.white()}}
    case Some{name}:named(values,name,line,0)

def table_choice(choice:Selected,found:Maybe<&2,U32>,line:Nat) -> Result<&2,&2,Asset.Error,Unit>:
  match choice found:
    case Selected{a,_},Some{b}:need(U32.is_eq(a,b),9,"OBJ",line,"upstream name table disagrees with exact names")
    case _,_:Fail{error(9,"OBJ",line,"upstream name table lost selection")}

def check_uses(uses:List<&2,Selection>,+values:List<&2,NamedMaterial>,+table:J.Table) -> Result<&2,&2,Asset.Error,Unit>:
  match uses:
    case []:Done{Unit{}}
    case Selection{+name,+line} <> rest:
      do Result<&2,&2,Asset.Error,Unit>:
        choice:Selected <- named(values,name,line,0)
        _:Unit <- table_choice(choice,J.table.get(table,J.djb2(text(name))),line)
        check_uses(rest,values,table)

def run_count(runs:List<&2,Run>) -> Nat:
  match runs:
    case []:0n
    case Run{count,_,_} <> rest:Nat.add(count,run_count(rest))

def check_positions(ps:List<&2,J.Parsed>) -> Result<&2,&2,Asset.Error,Unit>:
  match ps:
    case []:Done{Unit{}}
    case p <> rest:
      do Result<&2,&2,Asset.Error,Unit>:
        _:F32 <- parsed(p,"OBJ",0n)
        check_positions(rest)

def vertex(item:J.Item,+line:Nat) -> Result<&2,&2,Asset.Error,F.Vertex>:
  J.Item{x,y,z} = item
  do Result<&2,&2,Asset.Error,F.Vertex>:
    x:F32 <- parsed(x,"OBJ",line)
    y:F32 <- parsed(y,"OBJ",line)
    z:F32 <- parsed(z,"OBJ",line)
    return F.Vertex{C.Vec3{x,y,z},C.Vec3{1.0,1.0,1.0},F.UV{0.0,0.0},C.Vec3{0.0,0.0,1.0}}

def corner(c:J.FC,tree:J.ITree,depth:Nat,count:U32,+line:Nat) -> Result<&2,&2,Asset.Error,F.Vertex>:
  match c:
    case J.FC{J.Fix{ok,+index},J.Fix{False{},_},J.Fix{False{},_}}:
      do Result<&2,&2,Asset.Error,F.Vertex>:
        _:Unit <- need(ok && U32.is_lt(index,count),4,"OBJ",line,"upstream corner outside position array")
        vertex(J.itree.get(depth,tree,index),line)
    case _:Fail{error(9,"OBJ",line,"unexpected upstream corner layout")}

def emit_vertices(a:F.Vertex,b:F.Vertex,c:F.Vertex,tail:List<&2,F.Vertex>) -> List<&2,F.Vertex>:
  c <> b <> a <> tail

def emit_indices(+local:U32,tail:List<&2,U32>) -> List<&2,U32>:
  U32.add(local,2) <> U32.inc(local) <> local <> tail

type Built is Data:
  Built{part:F.ModelPart,remaining:List<&2,J.Tri>}

def built_part(built:Built) -> F.ModelPart:
  Built{part,_} = built
  part

def built_remaining(built:Built) -> List<&2,J.Tri>:
  Built{_,remaining} = built
  remaining

def expand(fuel:Nat,faces:List<&2,J.Tri>,+tree:J.ITree,+depth:Nat,+count:U32,+choice:Selected,+labels:F.ModelLabels,+line:Nat,+local:U32,vertices:List<&2,F.Vertex>,indices:List<&2,U32>) -> Result<&2,&2,Asset.Error,Built>:
  match fuel faces:
    case 0n,faces:
      Selected{_,value} = choice
      Done{Built{F.ModelPart{F.Mesh{List.reverse(&2,F.Vertex,vertices),List.reverse(&2,U32,indices)},value,labels},faces}}
    case 1n+rest,J.Tri{a,b,c,material} <> tail:
      Selected{+index,_} = choice
      do Result<&2,&2,Asset.Error,Built>:
        _:Unit <- need(U32.is_eq(material,index),9,"OBJ",line,"upstream triangle material disagrees with source run")
        a:F.Vertex <- corner(a,tree,depth,count,line)
        b:F.Vertex <- corner(b,tree,depth,count,line)
        c:F.Vertex <- corner(c,tree,depth,count,line)
        expand(rest,tail,tree,depth,count,choice,labels,line,U32.add(local,3),emit_vertices(a,b,c,vertices),emit_indices(local,indices))
    case _,_:Fail{error(9,"OBJ",line,"upstream omitted accepted faces")}

def checked(model:F.SourceModel,valid:Bool) -> Result<&2,&2,Asset.Error,F.SourceModel>:
  match valid:
    case True{}:Done{model}
    case False{}:Fail{error(10,"OBJ",0n,"converted model violates source validity")}

def admit(+model:F.SourceModel) -> Result<&2,&2,Asset.Error,F.SourceModel>:
  checked(model,F.model_valid(model))

def admit_result(result:Result<&2,&2,Asset.Error,F.SourceModel>) -> Result<&2,&2,Asset.Error,F.SourceModel>:
  match result:
    case Fail{e}:Fail{e}
    case Done{model}:admit(model)

def lower_runs(runs:List<&2,Run>,faces:List<&2,J.Tri>,+tree:J.ITree,+depth:Nat,+count:U32,+values:List<&2,NamedMaterial>,parts:List<&2,F.ModelPart>) -> Result<&2,&2,Asset.Error,F.SourceModel>:
  match runs faces:
    case [],[]:Done{F.SourceModel{List.reverse(&2,F.ModelPart,parts)}}
    case Run{n,+labels,+line} <> rest,faces:
      F.ModelLabels{_,_,name} = labels
      do Result<&2,&2,Asset.Error,F.SourceModel>:
        choice:Selected <- selected(name,values,line)
        +built:Built <- expand(n,faces,tree,depth,count,choice,labels,line,0,[],[])
        lower_runs(rest,built_remaining(built),tree,depth,count,values,built_part(built) <> parts)
    case _,_:Fail{error(9,"OBJ",0n,"upstream emitted extra faces")}

def lower(plan:Plan,materials:Materials,attrib:J.Attrib) -> Result<&2,&2,Asset.Error,F.SourceModel>:
  Plan{_,+runs,_,_,+vertices,+faces} = plan
  Materials{values,_} = materials
  J.Attrib{ok,+positions,ns,ts,+nv,nn,nt,+triangles,_} = attrib
  do Result<&2,&2,Asset.Error,F.SourceModel>:
    _:Unit <- need(ok && U32.is_zero(nn) && U32.is_zero(nt) && List.is_empty(&2,J.Parsed,ns) && List.is_empty(&2,J.Parsed,ts),9,"OBJ",0n,"pinned attribute parser refused or changed layout")
    _:Unit <- need(Nat.is_eq(U32.to_nat(nv),vertices) && Nat.is_eq(List.length(&2,J.Parsed,positions),Nat.mul(3n,vertices)),9,"OBJ",0n,"upstream position count mismatch")
    _:Unit <- need(Nat.is_eq(List.length(&2,J.Tri,triangles),faces) && Nat.is_eq(run_count(runs),faces),9,"OBJ",0n,"upstream triangle or source run count mismatch")
    _:Unit <- check_positions(positions)
    lower_runs(runs,triangles,J.itree.of(J.depth(nv),J.items3(positions,[])),J.depth(nv),nv,values,[])

def finish(+plan:Plan,+materials:Materials) -> Result<&2,&2,Asset.Error,F.SourceModel>:
  Plan{commands,_,_,uses,_,_} = plan
  Materials{values,+table} = materials
  admit_result(Result.bind(&2,&2,Asset.Error,Unit,F.SourceModel,check_uses(uses,values,table),_ => lower(plan,materials,J.attributes(commands,table))))

def finish_bytes(+plan:Plan,mtl:Maybe<&2,List<&2,U32>>) -> Result<&2,&2,Asset.Error,F.SourceModel>:
  Plan{_,_,library,_,_,_} = plan
  match library mtl:
    case None{},None{}:finish(plan,Materials{[],J.table.new()})
    case Some{_},Some{bytes}:
      do Result<&2,&2,Asset.Error,F.SourceModel>:
        values:Materials <- materials(bytes)
        finish(plan,values)
    case None{},Some{_}:Fail{error(5,"MTL",0n,"unexpected supplied MTL bytes")}
    case Some{_},None{}:Fail{error(5,"MTL",0n,"declared MTL bytes missing")}

def decode(obj_bytes:List<&2,U32>,mtl_bytes:Maybe<&2,List<&2,U32>>) -> Result<&2,&2,Asset.Error,F.SourceModel>:
  do Result<&2,&2,Asset.Error,F.SourceModel>:
    plan:Plan <- prepare(obj_bytes)
    finish_bytes(plan,mtl_bytes)

def native_error(code:U32,path:String,message:String) -> Asset.Error:
  Asset.Error{code,path ++ ": " ++ message}

def exact(result:Result<&1,&1,U32 & String,List<&2,U32>>,size:U32,+path:String) -> Result<&2,&2,Asset.Error,List<&2,U32>>:
  match result:
    case Fail{(code,message)}:Fail{native_error(code,path,message)}
    case Done{+bytes}:
      do Result<&2,&2,Asset.Error,List<&2,U32>>:
        _:Unit <- need(Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(size)),8,path,0n,"file size changed or read was incomplete")
        return bytes

def read_closed(pair:File & Result<&1,&1,U32 & String,List<&2,U32>>,size:U32,path:String) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  (file,result) = pair
  do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
    File.close(file)
    return exact(result,size,path)

def read_bounded(file:File,+size:U32,+path:String,fits:Bool) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  match fits:
    case False{}:
      do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
        File.close(file)
        return Fail{error(7,path,0n,"encoded byte limit")}
    case True{}:
      do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
        pair:File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,U32.inc(size))
        read_closed(pair,size,path)

def read_sized(pair:File & Result<&1,&1,U32 & String,U32>,+path:String,limit:Nat) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  match pair:
    case (file,Fail{(code,message)}):
      do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
        File.close(file)
        return Fail{native_error(code,path,message)}
    case (file,Done{+size}):read_bounded(file,size,path,Nat.is_le(U32.to_nat(size),limit))

def read_opened(result:Result<&1,&1,U32 & String,File>,+path:String,limit:Nat) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  match result:
    case Fail{(code,message)}:IO.pure(Result<&2,&2,Asset.Error,List<&2,U32>>,Fail{native_error(code,path,message)})
    case Done{file}:
      do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
        pair:File & Result<&1,&1,U32 & String,U32> <- File.size(file)
        read_sized(pair,path,limit)

def read_file(+path:String,limit:Nat) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  do IO<Result<&2,&2,Asset.Error,List<&2,U32>>>:
    result:Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    read_opened(result,path,limit)

def utf8_size(chars:List<&2,Char>) -> Nat:
  match chars:
    case []:0n
    case c <> rest:
      +code = Char.to_u32(c)
      Nat.add(Bool.pick(Nat,U32.is_lt(code,128),1n,Bool.pick(Nat,U32.is_lt(code,2048),2n,Bool.pick(Nat,U32.is_lt(code,65536),3n,4n))),utf8_size(rest))

def no_nul(chars:List<&2,Char>) -> Bool:
  match chars:
    case []:True{}
    case c <> rest:U32.is_ne(Char.to_u32(c),0) && no_nul(rest)

def path_valid(+path:String) -> Bool:
  Bool.not(String.eq(path,"")) && no_nul(String.to_list(path)) && Nat.is_le(utf8_size(String.to_list(path)),path_limit())

def directory(parts:List<&2,String>) -> String:
  match parts:
    case []:""
    case _ <> []:""
    case part <> rest:part ++ "/" ++ directory(rest)

def context(result:Result<&2,&2,Asset.Error,F.SourceModel>,path:String) -> Result<&2,&2,Asset.Error,F.SourceModel>:
  match result:
    case Done{value}:Done{value}
    case Fail{Asset.Error{code,message}}:Fail{native_error(code,path,message)}

def dependency_context(result:Result<&2,&2,Asset.Error,F.SourceModel>,+obj_path:String,+mtl_path:String) -> Result<&2,&2,Asset.Error,F.SourceModel>:
  match result:
    case Done{value}:Done{value}
    case Fail{Asset.Error{code,+message}}:Fail{native_error(code,Bool.pick(String,String.starts_with(message,"MTL "),mtl_path,obj_path),message)}

def dependency_loaded(result:Result<&2,&2,Asset.Error,List<&2,U32>>,plan:Plan,obj_path:String,mtl_path:String) -> Result<&2,&2,Asset.Error,F.SourceModel>:
  match result:
    case Fail{e}:Fail{e}
    case Done{bytes}:dependency_context(finish_bytes(plan,Some{bytes}),obj_path,mtl_path)

def load_dependency_valid(+path:String,plan:Plan,obj_path:String,valid:Bool) -> IO(Result<&2,&2,Asset.Error,F.SourceModel>):
  match valid:
    case False{}:IO.pure(Result<&2,&2,Asset.Error,F.SourceModel>,Fail{error(6,path,0n,"joined dependency path exceeds path policy")})
    case True{}:
      do IO<Result<&2,&2,Asset.Error,F.SourceModel>>:
        result:Result<&2,&2,Asset.Error,List<&2,U32>> <- read_file(path,mtl_limit())
        return dependency_loaded(result,plan,obj_path,path)

def load_dependency_path(+path:String,plan:Plan,obj_path:String) -> IO(Result<&2,&2,Asset.Error,F.SourceModel>):
  load_dependency_valid(path,plan,obj_path,path_valid(path))

def load_dependency(library:Maybe<&2,String>,plan:Plan,+path:String) -> IO(Result<&2,&2,Asset.Error,F.SourceModel>):
  match library:
    case None{}:IO.pure(Result<&2,&2,Asset.Error,F.SourceModel>,context(finish_bytes(plan,None{}),path))
    case Some{name}:load_dependency_path(directory(String.split(path,'/')) ++ name,plan,path)

def load_plan(result:Result<&2,&2,Asset.Error,Plan>,+path:String) -> IO(Result<&2,&2,Asset.Error,F.SourceModel>):
  match result:
    case Fail{Asset.Error{code,message}}:IO.pure(Result<&2,&2,Asset.Error,F.SourceModel>,Fail{native_error(code,path,message)})
    case Done{+plan}:
      Plan{_,_,library,_,_,_} = plan
      load_dependency(library,plan,path)

def load_bytes(result:Result<&2,&2,Asset.Error,List<&2,U32>>,path:String) -> IO(Result<&2,&2,Asset.Error,F.SourceModel>):
  match result:
    case Fail{error}:IO.pure(Result<&2,&2,Asset.Error,F.SourceModel>,Fail{error})
    case Done{bytes}:load_plan(prepare(bytes),path)

def load_valid(+path:String,valid:Bool) -> IO(Result<&2,&2,Asset.Error,F.SourceModel>):
  match valid:
    case False{}:IO.pure(Result<&2,&2,Asset.Error,F.SourceModel>,Fail{error(6,path,0n,"root path is empty, contains NUL or exceeds 4096 UTF-8 bytes")})
    case True{}:
      do IO<Result<&2,&2,Asset.Error,F.SourceModel>>:
        result:Result<&2,&2,Asset.Error,List<&2,U32>> <- read_file(path,obj_limit())
        load_bytes(result,path)

def load(path:String) -> IO(Result<&2,&2,Asset.Error,F.SourceModel>):
  +path = path
  load_valid(path,path_valid(path))

def valid_result(result:Result<&2,&2,Asset.Error,F.SourceModel>) -> Bool:
  match result:
    case Fail{_}:True{}
    case Done{model}:F.model_valid(model)

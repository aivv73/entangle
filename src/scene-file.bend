import Base
import ./json-boundary.bend as Json
import 0x37aacddc1dcb57464b8b5ac6c397bd64/json.bend as J
import ./asset.bend as Asset
import ./content.bend as F
import ./components.bend as C
import ./creation.bend as Create
import ./model-obj.bend as Obj
import ./image-png.bend as Png
import ./hierarchy.bend as H
import 0x632652e3c1c0183f12728faf3870bb68/bytes.bend as B

type AssetKind is Data:
  Model{}
  Image{}
type Reference is Data:
  Reference{id:String,kind:AssetKind,path:String}
type Manifest is Data:
  Manifest{assets:List<&2,Reference>}
type Placement is Data:
  Placement{model:String,transform:C.Transform,parent:Maybe<&2,U32>}
type Description is Data:
  Description{manifest:String,instances:List<&2,Placement>}
type Source is Data:
  ModelSource{id:String,value:F.SourceModel}
  ImageSource{id:String,value:F.SourceImage}

def asset_limit() -> Nat:64n
def instance_limit() -> Nat:256n
def expanded_limit() -> Nat:4096n

def kind(value:String,+path:String) -> Result<&2,&1,Asset.Error,AssetKind>:
  match value:
    case "obj":Done{Model{}}
    case "png":Done{Image{}}
    case _:Fail{Json.error(3,path,"kind must be obj or png")}

def id_chars(s:String) -> Bool:
  match s:
    case SNil{}:True{}
    case SCon{c,rest}:
      +c = Char.to_u32(c)
      ((U32.is_ge(c,97) && U32.is_le(c,122)) || (U32.is_ge(c,65) && U32.is_le(c,90)) || (U32.is_ge(c,48) && U32.is_le(c,57)) || U32.is_eq(c,45) || U32.is_eq(c,95)) && id_chars(rest)

def identifier(+id:String,+path:String) -> Result<&2,&1,Asset.Error,String>:
  do Result<&2,&1,Asset.Error,String>:
    _:Unit <- Json.need(Bool.not(String.eq(id,"")) && Nat.is_le(String.length(id),64n) && id_chars(id),5,path,"id requires 1..64 ASCII letters, digits, hyphens or underscores")
    return id

def relative(+name:String,+path:String) -> Result<&2,&1,Asset.Error,String>:
  do Result<&2,&1,Asset.Error,String>:
    _:Unit <- Json.need(Obj.dependency(name),5,path,"path requires relative ASCII components without dot, parent, backslash or URI syntax")
    return name

def reference_fields(values:List<&1,J.Val>,+path:String) -> Result<&2,&1,Asset.Error,Reference>:
  match values:
    case [id,tag,file]:
      do Result<&2,&1,Asset.Error,Reference>:
        id:String <- Json.text(id,path ++ ".id")
        id:String <- identifier(id,path ++ ".id")
        tag:String <- Json.text(tag,path ++ ".kind")
        tag:AssetKind <- kind(tag,path ++ ".kind")
        file:String <- Json.text(file,path ++ ".path")
        file:String <- relative(file,path ++ ".path")
        return Reference{id,tag,file}
    case _:Fail{Json.error(3,path,"invalid reference fields")}

def reference(value:J.Val,+path:String) -> Result<&2,&1,Asset.Error,Reference>:
  do Result<&2,&1,Asset.Error,Reference>:
    fields:List<&1,J.Val> <- Json.schema(value,["id","kind","path"],path)
    reference_fields(fields,path)

def fresh(refs:List<&2,Reference>,+id:String) -> Bool:
  match refs:
    case []:True{}
    case Reference{other,_,_} <> rest:Bool.not(String.eq(id,other)) && fresh(rest,id)

def reference_id(ref:Reference) -> String:
  Reference{id,_,_} = ref
  id

def references(values:List<&1,J.Val>,+path:String,+index:Nat,+acc:List<&2,Reference>) -> Result<&2,&1,Asset.Error,Manifest>:
  match values:
    case []:Done{Manifest{List.reverse(&2,Reference,acc)}}
    case value <> rest:
      do Result<&2,&1,Asset.Error,Manifest>:
        _:Unit <- Json.need(Nat.is_lt(index,asset_limit()),2,path,"manifest exceeds 64 assets")
        +ref:Reference <- reference(value,path ++ "[" ++ Nat.show(index) ++ "]")
        _:Unit <- Json.need(fresh(acc,reference_id(ref)),5,path,"duplicate asset id " ++ reference_id(ref))
        references(rest,path,1n+index,ref <> acc)

def manifest_fields(values:List<&1,J.Val>,+path:String) -> Result<&2,&1,Asset.Error,Manifest>:
  match values:
    case [version,assets]:
      do Result<&2,&1,Asset.Error,Manifest>:
        _:Unit <- Json.version(version,path ++ ".version")
        values:List<&1,J.Val> <- Json.array(assets,path ++ ".assets")
        references(values,path ++ ".assets",0n,[])
    case _:Fail{Json.error(3,path,"invalid manifest fields")}

def manifest_value(value:J.Val,+path:String) -> Result<&2,&1,Asset.Error,Manifest>:
  do Result<&2,&1,Asset.Error,Manifest>:
    values:List<&1,J.Val> <- Json.schema(value,["version","assets"],path)
    manifest_fields(values,path)

def vec(value:J.Val,+path:String) -> Result<&2,&1,Asset.Error,C.Vec3>:
  match value:
    case J.Arr{[x,y,z]}:
      do Result<&2,&1,Asset.Error,C.Vec3>:
        x:F32 <- Json.number(x,path ++ "[0]")
        y:F32 <- Json.number(y,path ++ "[1]")
        z:F32 <- Json.number(z,path ++ "[2]")
        return C.Vec3{x,y,z}
    case _:Fail{Json.error(3,path,"expected exactly three numbers")}

def quat(value:J.Val,+path:String) -> Result<&2,&1,Asset.Error,C.Quat>:
  match value:
    case J.Arr{[x,y,z,w]}:
      do Result<&2,&1,Asset.Error,C.Quat>:
        x:F32 <- Json.number(x,path ++ "[0]")
        y:F32 <- Json.number(y,path ++ "[1]")
        z:F32 <- Json.number(z,path ++ "[2]")
        w:F32 <- Json.number(w,path ++ "[3]")
        return C.Quat{x,y,z,w}
    case _:Fail{Json.error(3,path,"expected exactly four numbers")}

def transform_fields(values:List<&1,J.Val>,+path:String) -> Result<&2,&1,Asset.Error,C.Transform>:
  match values:
    case [position,rotation,scale]:
      do Result<&2,&1,Asset.Error,C.Transform>:
        position:C.Vec3 <- vec(position,path ++ ".position")
        rotation:C.Quat <- quat(rotation,path ++ ".rotation")
        scale:C.Vec3 <- vec(scale,path ++ ".scale")
        +transform:C.Transform = C.Transform{position,rotation,scale}
        _:Unit <- Json.need(Create.transform_valid(transform),4,path,"rotation must be a unit quaternion within 0.0001 squared-norm tolerance")
        return transform
    case _:Fail{Json.error(3,path,"invalid transform fields")}

def transform(value:J.Val,+path:String) -> Result<&2,&1,Asset.Error,C.Transform>:
  do Result<&2,&1,Asset.Error,C.Transform>:
    values:List<&1,J.Val> <- Json.schema(value,["position","rotation","scale"],path)
    transform_fields(values,path)

def placement_fields(values:List<&1,J.Val>,+path:String) -> Result<&2,&1,Asset.Error,Placement>:
  match values:
    case [model,t]:
      do Result<&2,&1,Asset.Error,Placement>:
        model:String <- Json.text(model,path ++ ".model")
        model:String <- identifier(model,path ++ ".model")
        t:C.Transform <- transform(t,path ++ ".transform")
        return Placement{model,t,None{}}
    case _:Fail{Json.error(3,path,"invalid placement fields")}

def parent_number(value:Maybe<&2,U32>,+token:String,+path:String) -> Result<&2,&1,Asset.Error,Maybe<&2,U32>>:
  match value:
    case None{}:Fail{Json.error(5,path,"parent must be a placement index or null")}
    case Some{+n}:
      do Result<&2,&1,Asset.Error,Maybe<&2,U32>>:
        _:Unit <- Json.need(String.eq(token,U32.show(n)) && U32.is_lt(n,256),5,path,"parent must be an integer placement index below 256")
        return Some{n}

def parent_value(value:Maybe<&1,J.Val>,+path:String) -> Result<&2,&1,Asset.Error,Maybe<&2,U32>>:
  match value:
    case None{}:Done{None{}}
    case Some{J.Null{}}:Done{None{}}
    case Some{J.Num{token}}:
      +token = B.to_string(token)
      parent_number(U32.read(token),token,path)
    case _:Fail{Json.error(5,path,"parent must be a placement index or null")}

def placement_parent(item:Placement,parent:Maybe<&2,U32>) -> Placement:
  Placement{model,t,_} = item
  Placement{model,t,parent}

def placement_optional(pair:Maybe<&1,J.Val> & List<&1,B.Bytes & J.Val>,+path:String) -> Result<&2,&1,Asset.Error,Placement>:
  (optional,fields) = pair
  do Result<&2,&1,Asset.Error,Placement>:
    parent:Maybe<&2,U32> <- parent_value(optional,path ++ ".parent")
    ordered:List<&1,J.Val> <- Json.ordered(["model","transform"],fields,path)
    item:Placement <- placement_fields(ordered,path)
    return placement_parent(item,parent)

def placement(value:J.Val,+path:String) -> Result<&2,&1,Asset.Error,Placement>:
  do Result<&2,&1,Asset.Error,Placement>:
    fields:List<&1,B.Bytes & J.Val> <- Json.fields(value,path)
    placement_optional(Json.pull(fields,"parent"),path)

def placements(values:List<&1,J.Val>,+path:String,+index:Nat) -> Result<&2,&1,Asset.Error,List<&2,Placement>>:
  match values:
    case []:Done{[]}
    case value <> rest:
      do Result<&2,&1,Asset.Error,List<&2,Placement>>:
        _:Unit <- Json.need(Nat.is_lt(index,instance_limit()),2,path,"scene exceeds 256 instances")
        +item_path:String = path ++ "[" ++ Nat.show(index) ++ "]"
        p:Placement <- placement(value,item_path)
        ps:List<&2,Placement> <- placements(rest,path,1n+index)
        return p <> ps

def placement_locals(items:List<&2,Placement>) -> List<&2,H.Local>:
  match items:
    case []:[]
    case Placement{_,t,p} <> rest:H.Local{t,p,H.Empty{},False{}} <> placement_locals(rest)

def parent_graph(result:Result<&2,&2,H.Error,List<&2,H.Spatial>>,path:String) -> Result<&2,&1,Asset.Error,Unit>:
  match result:
    case Fail{_}:Fail{Json.error(5,path,"invalid parent graph or composed transform")}
    case Done{_}:Done{Unit{}}

def scene_fields(values:List<&1,J.Val>,+path:String) -> Result<&2,&1,Asset.Error,Description>:
  match values:
    case [version,manifest,instances]:
      do Result<&2,&1,Asset.Error,Description>:
        _:Unit <- Json.version(version,path ++ ".version")
        name:String <- Json.text(manifest,path ++ ".manifest")
        name:String <- relative(name,path ++ ".manifest")
        values:List<&1,J.Val> <- Json.array(instances,path ++ ".instances")
        +items:List<&2,Placement> <- placements(values,path ++ ".instances",0n)
        _:Unit <- parent_graph(H.evaluate(placement_locals(items)),path)
        return Description{name,items}
    case _:Fail{Json.error(3,path,"invalid scene fields")}

def scene_value(value:J.Val,+path:String) -> Result<&2,&1,Asset.Error,Description>:
  do Result<&2,&1,Asset.Error,Description>:
    values:List<&1,J.Val> <- Json.schema(value,["version","manifest","instances"],path)
    scene_fields(values,path)

def decode_manifest(bytes:List<&2,U32>,+path:String) -> Result<&2,&2,Asset.Error,Manifest>:
  Json.data(Manifest,Result.bind(&2,&1,Asset.Error,J.Val,Manifest,Json.parse(bytes,path),v => manifest_value(v,path)))

def decode_scene(bytes:List<&2,U32>,+path:String) -> Result<&2,&2,Asset.Error,Description>:
  Json.data(Description,Result.bind(&2,&1,Asset.Error,J.Val,Description,Json.parse(bytes,path),v => scene_value(v,path)))

def joined(+owner:String,name:String) -> Result<&2,&2,Asset.Error,String>:
  +path = Obj.directory(String.split(owner,'/')) ++ name
  do Result<&2,&2,Asset.Error,String>:
    _:Unit <- Json.data(Unit,Json.need(Obj.path_valid(path),5,owner,"joined path exceeds 4096 UTF-8 bytes"))
    return path

def read_valid(valid:Bool,+path:String) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  match valid:
    case False{}:IO.pure(Result<&2,&2,Asset.Error,List<&2,U32>>,Fail{Json.error(5,path,"root path empty, contains NUL or exceeds 4096 UTF-8 bytes")})
    case True{}:Json.read(path)

def read(+path:String) -> IO(Result<&2,&2,Asset.Error,List<&2,U32>>):
  read_valid(Obj.path_valid(path),path)

def read_manifest(+path:String) -> IO(Result<&2,&2,Asset.Error,Manifest>):
  do IO<Result<&2,&2,Asset.Error,Manifest>>:
    result:Result<&2,&2,Asset.Error,List<&2,U32>> <- read(path)
    return Result.bind(&2,&2,Asset.Error,List<&2,U32>,Manifest,result,bytes => decode_manifest(bytes,path))

def reference_kind(found:Bool,tag:AssetKind,id:String,path:String) -> Result<&2,&2,Asset.Error,Unit>:
  match found tag:
    case True{},Image{}:Fail{Json.error(5,path,"image used as model " ++ id)}
    case _,_:Done{Unit{}}

def model_reference(refs:List<&2,Reference>,+id:String,+path:String) -> Result<&2,&2,Asset.Error,Unit>:
  match refs:
    case []:Fail{Json.error(5,path,"unresolved model " ++ id)}
    case Reference{other,tag,_} <> rest:
      +found = String.eq(id,other)
      Result.bind(&2,&2,Asset.Error,Unit,Unit,
        Bool.pick(Result<&2,&2,Asset.Error,Unit>,found,Done{Unit{}},model_reference(rest,id,path)),
        _ => reference_kind(found,tag,id,path))

def check_references(items:List<&2,Placement>,+refs:List<&2,Reference>,+path:String) -> Result<&2,&2,Asset.Error,Unit>:
  match items:
    case []:Done{Unit{}}
    case Placement{id,_,_} <> rest:
      do Result<&2,&2,Asset.Error,Unit>:
        _:Unit <- model_reference(refs,id,path)
        check_references(rest,refs,path)

def image_source(result:Result<&2,&2,Asset.Error,F.SourceImage>,id:String,path:String) -> Result<&2,&2,Asset.Error,Source>:
  match result:
    case Done{value}:Done{ImageSource{id,value}}
    case Fail{Asset.Error{code,message}}:Fail{Asset.Error{code,path ++ ": " ++ message}}

def load_source(tag:AssetKind,+id:String,+path:String) -> IO(Result<&2,&2,Asset.Error,Source>):
  match tag:
    case Model{}:
      do IO<Result<&2,&2,Asset.Error,Source>>:
        result:Result<&2,&2,Asset.Error,F.SourceModel> <- Obj.load(path)
        return Result.map(&2,&2,Asset.Error,F.SourceModel,Source,value => ModelSource{id,value},result)
    case Image{}:
      do IO<Result<&2,&2,Asset.Error,Source>>:
        result:Result<&2,&2,Asset.Error,F.SourceImage> <- Png.load(path)
        return image_source(result,id,path)

def load_path(result:Result<&2,&2,Asset.Error,String>,tag:AssetKind,id:String) -> IO(Result<&2,&2,Asset.Error,Source>):
  match result:
    case Fail{e}:IO.pure(Result<&2,&2,Asset.Error,Source>,Fail{e})
    case Done{path}:load_source(tag,id,path)

def source_counts(source:Source) -> Nat & Nat & Nat:
  match source:
    case ModelSource{_,F.SourceModel{parts}}:
      Json.pair(Nat,Nat,Nat & Nat & Nat,F.model_counts(parts),vs => is1 => (vs,is1,0n))
    case ImageSource{_,F.SourceImage{width,height,_}}:(0n,0n,Nat.mul(U32.to_nat(width),U32.to_nat(height)))

def add_counts(a:Nat & Nat & Nat,b:Nat & Nat & Nat) -> Nat & Nat & Nat:
  (vs,is1,ps) = a
  (vt,it,pt) = b
  (Nat.add(vs,vt),Nat.add(is1,it),Nat.add(ps,pt))

def total_counts(sources:List<&2,Source>) -> Nat & Nat & Nat:
  match sources:
    case []:(0n,0n,0n)
    case source <> rest:add_counts(source_counts(source),total_counts(rest))

def catalog_fits(counts:Nat & Nat & Nat) -> Bool:
  (vs,is1,ps) = counts
  F.mesh_fits(vs,is1) && Nat.is_le(ps,16777216n)

def catalog_admit(+sources:List<&2,Source>,+path:String) -> Result<&2,&2,Asset.Error,List<&2,Source>>:
  do Result<&2,&2,Asset.Error,List<&2,Source>>:
    _:Unit <- Json.data(Unit,Json.need(catalog_fits(total_counts(sources)),2,path,"aggregate source geometry or image pixel limit"))
    return sources

def load_sources(refs:List<&2,Reference>,+owner:String,acc:Result<&2,&2,Asset.Error,List<&2,Source>>) -> IO(Result<&2,&2,Asset.Error,List<&2,Source>>):
  match refs acc:
    case _,Fail{e}:IO.pure(Result<&2,&2,Asset.Error,List<&2,Source>>,Fail{e})
    case [],Done{sources}:IO.pure(Result<&2,&2,Asset.Error,List<&2,Source>>,Done{List.reverse(&2,Source,sources)})
    case Reference{id,tag,path} <> rest,Done{sources}:
      do IO<Result<&2,&2,Asset.Error,List<&2,Source>>>:
        source:Result<&2,&2,Asset.Error,Source> <- load_path(joined(owner,path),tag,id)
        next:Result<&2,&2,Asset.Error,List<&2,Source>> = Result.bind(&2,&2,Asset.Error,Source,List<&2,Source>,source,s => catalog_admit(s <> sources,owner))
        load_sources(rest,owner,next)

def manifest_loaded(result:Result<&2,&2,Asset.Error,Manifest>,owner:String) -> IO(Result<&2,&2,Asset.Error,List<&2,Source>>):
  match result:
    case Fail{e}:IO.pure(Result<&2,&2,Asset.Error,List<&2,Source>>,Fail{e})
    case Done{Manifest{refs}}:load_sources(refs,owner,Done{[]})

def load_manifest(path:String) -> IO(Result<&2,&2,Asset.Error,List<&2,Source>>):
  +path:String = path
  do IO<Result<&2,&2,Asset.Error,List<&2,Source>>>:
    result:Result<&2,&2,Asset.Error,Manifest> <- read_manifest(path)
    manifest_loaded(result,path)

def model(sources:List<&2,Source>,+id:String,+path:String) -> Result<&2,&2,Asset.Error,F.SourceModel>:
  match sources:
    case []:Fail{Json.error(5,path,"unresolved model " ++ id)}
    case ModelSource{other,value} <> rest:Bool.pick(Result<&2,&2,Asset.Error,F.SourceModel>,String.eq(id,other),Done{value},model(rest,id,path))
    case ImageSource{_,_} <> rest:model(rest,id,path)

def instances(parts:List<&2,F.ModelPart>,+transform:C.Transform) -> List<&2,Create.Instance>:
  match parts:
    case []:[]
    case F.ModelPart{mesh,material,_} <> rest:Create.Instance{mesh,material,transform} <> instances(rest,transform)

def model_instances(value:F.SourceModel,t:C.Transform) -> List<&2,Create.Instance>:
  F.SourceModel{parts} = value
  instances(parts,t)

def expand(items:List<&2,Placement>,+sources:List<&2,Source>,+path:String,+count:Nat,acc:List<&2,Create.Instance>) -> Result<&2,&2,Asset.Error,Create.Scene>:
  match items:
    case []:Done{Create.Scene{acc}}
    case Placement{id,t,_} <> rest:
      do Result<&2,&2,Asset.Error,Create.Scene>:
        value:F.SourceModel <- model(sources,id,path)
        +added:List<&2,Create.Instance> = model_instances(value,t)
        +count:Nat = Nat.add(count,List.length(&2,Create.Instance,added))
        _:Unit <- Json.data(Unit,Json.need(Nat.is_le(count,expanded_limit()),2,path,"expanded scene exceeds 4096 parts"))
        expand(rest,sources,path,count,List.append(&2,Create.Instance,acc,added))

type Group is Data:
  Group{placement:Placement,parts:List<&2,F.ModelPart>,first:U32}

def has_parent(items:List<&2,Placement>) -> Bool:
  match items:
    case []:False{}
    case Placement{_,_,Some{_}} <> _:True{}
    case _ <> rest:has_parent(rest)

def parts(value:F.SourceModel) -> List<&2,F.ModelPart>:
  F.SourceModel{parts} = value
  parts

def groups(items:List<&2,Placement>,+sources:List<&2,Source>,+path:String,+count:Nat) -> Result<&2,&2,Asset.Error,List<&2,Group>>:
  match items:
    case []:Done{[]}
    case +item <> rest:
      Placement{id,_,_} = item
      do Result<&2,&2,Asset.Error,List<&2,Group>>:
        model:F.SourceModel <- model(sources,id,path)
        +ps:List<&2,F.ModelPart> = parts(model)
        +next:Nat = Nat.add(count,List.length(&2,F.ModelPart,ps))
        _:Unit <- Json.data(Unit,Json.need(Nat.is_gt(next,count) && Nat.is_le(next,expanded_limit()),2,path,"hierarchical models must have parts and fit the 4096-part limit"))
        tail:List<&2,Group> <- groups(rest,sources,path,next)
        return Group{item,ps,U32.from_nat(count)} <> tail

def anchor(groups:List<&2,Group>,index:Nat) -> Maybe<&2,U32>:
  match groups index:
    case Group{_,_,first} <> _,0n:Some{first}
    case _ <> rest,1n+n:anchor(rest,n)
    case [] _:None{}

def anchor_parent(parent:Maybe<&2,U32>,groups:List<&2,Group>) -> Maybe<&2,U32>:
  match parent:
    case None{}:None{}
    case Some{p}:anchor(groups,U32.to_nat(p))

def attached_parts(parts:List<&2,F.ModelPart>,+first:U32) -> List<&2,Create.Instance>:
  match parts:
    case []:[]
    case F.ModelPart{m,c,_} <> rest:Create.Parented{m,c,C.Transform.identity(),first} <> attached_parts(rest,first)

def group_instances(parts:List<&2,F.ModelPart>,t:C.Transform,parent:Maybe<&2,U32>,first:U32) -> List<&2,Create.Instance>:
  match parts:
    case []:[]
    case F.ModelPart{m,c,_} <> rest:Create.parent(Create.Instance{m,c,t},parent) <> attached_parts(rest,first)

def grouped(groups:List<&2,Group>,+all:List<&2,Group>) -> List<&2,Create.Instance>:
  match groups:
    case []:[]
    case Group{Placement{_,t,p},parts,first} <> rest:List.append(&2,Create.Instance,group_instances(parts,t,anchor_parent(p,all),first),grouped(rest,all))

def expand_scene(hierarchy:Bool,items:List<&2,Placement>,sources:List<&2,Source>,path:String) -> Result<&2,&2,Asset.Error,Create.Scene>:
  match hierarchy:
    case False{}:expand(items,sources,path,0n,[])
    case True{}:
      do Result<&2,&2,Asset.Error,Create.Scene>:
        +gs:List<&2,Group> <- groups(items,sources,path,0n)
        return Create.Scene{grouped(gs,gs)}

def compilation_ok(result:Result<&2,&2,Create.Error,Create.Compiled>) -> Bool:
  match result:
    case Fail{_}:False{}
    case Done{_}:True{}

def scene_valid(scene:Create.Scene) -> Bool:
  compilation_ok(Create.compile(scene))

def checked(scene:Create.Scene,path:String,valid:Bool) -> Result<&2,&2,Asset.Error,Create.Scene>:
  match valid:
    case False{}:Fail{Json.error(4,path,"scene rejected by Creation geometry, material, transform or capacity rules")}
    case True{}:Done{scene}

def admit(+scene:Create.Scene,path:String) -> Result<&2,&2,Asset.Error,Create.Scene>:
  checked(scene,path,scene_valid(scene))

def valid_result(result:Result<&2,&2,Asset.Error,Create.Scene>) -> Bool:
  match result:
    case Fail{_}:True{}
    case Done{scene}:scene_valid(scene)

def resolve(loaded:Result<&2,&2,Asset.Error,List<&2,Source>>,+items:List<&2,Placement>,+path:String) -> Result<&2,&2,Asset.Error,Create.Scene>:
  do Result<&2,&2,Asset.Error,Create.Scene>:
    sources:List<&2,Source> <- loaded
    scene:Create.Scene <- expand_scene(has_parent(items),items,sources,path)
    admit(scene,path)

def checked_manifest(checked:Result<&2,&2,Asset.Error,Unit>,refs:List<&2,Reference>,+items:List<&2,Placement>,owner:String,path:String) -> IO(Result<&2,&2,Asset.Error,Create.Scene>):
  match checked:
    case Fail{e}:IO.pure(Result<&2,&2,Asset.Error,Create.Scene>,Fail{e})
    case Done{_}:
      do IO<Result<&2,&2,Asset.Error,Create.Scene>>:
        loaded:Result<&2,&2,Asset.Error,List<&2,Source>> <- load_sources(refs,owner,Done{[]})
        return resolve(loaded,items,path)

def scene_manifest(result:Result<&2,&2,Asset.Error,Manifest>,+items:List<&2,Placement>,owner:String,+path:String) -> IO(Result<&2,&2,Asset.Error,Create.Scene>):
  match result:
    case Fail{e}:IO.pure(Result<&2,&2,Asset.Error,Create.Scene>,Fail{e})
    case Done{Manifest{+refs}}:checked_manifest(check_references(items,refs,path),refs,items,owner,path)

def manifest_path(result:Result<&2,&2,Asset.Error,String>,items:List<&2,Placement>,path:String) -> IO(Result<&2,&2,Asset.Error,Create.Scene>):
  match result:
    case Fail{e}:IO.pure(Result<&2,&2,Asset.Error,Create.Scene>,Fail{e})
    case Done{+owner}:
      do IO<Result<&2,&2,Asset.Error,Create.Scene>>:
        result:Result<&2,&2,Asset.Error,Manifest> <- read_manifest(owner)
        scene_manifest(result,items,owner,path)

def described(result:Result<&2,&2,Asset.Error,Description>,+path:String) -> IO(Result<&2,&2,Asset.Error,Create.Scene>):
  match result:
    case Fail{e}:IO.pure(Result<&2,&2,Asset.Error,Create.Scene>,Fail{e})
    case Done{Description{name,items}}:manifest_path(joined(path,name),items,path)

def load(path:String) -> IO(Result<&2,&2,Asset.Error,Create.Scene>):
  +path:String = path
  do IO<Result<&2,&2,Asset.Error,Create.Scene>>:
    result:Result<&2,&2,Asset.Error,List<&2,U32>> <- read(path)
    described(Result.bind(&2,&2,Asset.Error,List<&2,U32>,Description,result,bytes => decode_scene(bytes,path)),path)

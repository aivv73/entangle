import Base
import ../../deps/bendvy/src/ecs/execution-state.bend as State
import ./LAWS.bend as Laws
import ./spec.bend as V
import ../../src/hierarchy.bend as H
import ../../src/scene-hierarchy.bend as S
import ../../src/components.bend as C
import ../../src/scene-schema.bend as D
import ../../deps/bendvy/src/ecs/world.bend as W

def Laws.cycle_evaluate(a,b,bounds,lit):{==}
def Laws.missing_evaluate(transform,bounds,lit):{==}

def through_rejected(+local:H.Local,+read:V.Tree,+index:U32,+rest:Nat,+count:U32,+p:U32,+entered:V.Tree,+error:H.Error,parent:{V.parent(local) == Some{p} : Maybe<&2,U32>},enter:{Array.set(H.Mark,V.thaw(read),index,H.Visiting{}) == V.thaw(entered) : Array<H.Mark>},rejected:{H.visit(rest,count,p,V.thaw(entered)) == Fail{error} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}) -> {H.visit_mark((V.thaw(read),H.Pending{local}),index,q => a => H.visit(rest,count,q,a)) == Fail{error} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}:
  match local:
    case H.Local{+t,+parent_index,+b,+l}:
      %Equal.sym(Maybe<&2,U32>,parent_index,Some{p},parent) : {H.visit_parent(_,local,index,V.thaw(read),q => a => H.visit(rest,count,q,a)) == Fail{error} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      %Equal.sym(Array<H.Mark>,Array.set(H.Mark,V.thaw(read),index,H.Visiting{}),V.thaw(entered),enter) : {H.parent_done(local,index,H.visit(rest,count,p,_)) == Fail{error} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      Equal.cong(Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>,Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>,r => H.parent_done(local,index,r),H.visit(rest,count,p,V.thaw(entered)),Fail{error},rejected)

def Laws.rejection_visit(fuel,path,count,index,before,witness):
  match fuel path:
    case 0n V.Exhausted{}:{==}
    case 1n+ +rest V.Outside{}:
      Equal.cong(Bool,Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>,b => H.visit_checked(b,index,V.thaw(before),p => a => H.visit(rest,count,p,a)),U32.is_lt(index,count),False{},witness)
    case 1n+ +rest V.BackEdge{+read}:
      (bound,read_ok) = witness
      %Equal.sym(Bool,U32.is_lt(index,count),True{},bound) : {H.visit_checked(_,index,V.thaw(before),p => a => H.visit(rest,count,p,a)) == Fail{H.Cycle{index}} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      Equal.cong(Array<H.Mark> & H.Mark,Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>,r => H.visit_mark(r,index,p => a => H.visit(rest,count,p,a)),Array.get(H.Mark,V.thaw(before),index),(V.thaw(read),H.Visiting{}),read_ok)
    case 1n+ +rest V.Through{+read,+local,+p,+entered,+ancestor}:
      (bound,(read_ok,(parent,(enter,valid)))) = witness
      %Equal.sym(Bool,U32.is_lt(index,count),True{},bound) : {H.visit_checked(_,index,V.thaw(before),q => a => H.visit(rest,count,q,a)) == Fail{V.error(ancestor,p)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      %Equal.sym(Array<H.Mark> & H.Mark,Array.get(H.Mark,V.thaw(before),index),(V.thaw(read),H.Pending{local}),read_ok) : {H.visit_mark(_,index,q => a => H.visit(rest,count,q,a)) == Fail{V.error(ancestor,p)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      through_rejected(local,read,index,rest,count,p,entered,V.error(ancestor,p),parent,enter,Laws.rejection_visit(rest,ancestor,count,p,entered,valid))
    case 0n V.Outside{}:
      match witness:
    case 0n V.BackEdge{_}:
      match witness:
    case 0n V.Through{_,_,_,_,_}:
      match witness:
    case 1n+_ V.Exhausted{}:
      match witness:

def saved(+before:V.Tree,+after:V.Tree,+index:U32,+value:H.Spatial,proof:{Array.set(H.Mark,V.thaw(before),index,H.Finished{value}) == V.thaw(after) : Array<H.Mark>}) -> {H.save(V.thaw(before),index,Done{value}) == Done{(V.thaw(after),value)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}:
  Equal.cong(Array<H.Mark>,Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>,a => Done{(a,value)},Array.set(H.Mark,V.thaw(before),index,H.Finished{value}),V.thaw(after),proof)

def parent_saved(+before:V.Tree,+after:V.Tree,+index:U32,+local:H.Local,+parent:H.Spatial,+value:H.Spatial,derived:{H.derive(local,Some{V.spatial_global(parent)},index) == Done{value} : Result<&2,&2,H.Error,H.Spatial>},stored:{Array.set(H.Mark,V.thaw(before),index,H.Finished{value}) == V.thaw(after) : Array<H.Mark>}) -> {H.parent_done(local,index,Done{(V.thaw(before),parent)}) == Done{(V.thaw(after),value)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}:
  match parent:
    case H.Spatial{_,+global,_}:
      %Equal.sym(Result<&2,&2,H.Error,H.Spatial>,H.derive(local,Some{global},index),Done{value},derived) : {H.save(V.thaw(before),index,_) == Done{(V.thaw(after),value)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      saved(before,after,index,value,stored)

def root_done(+local:H.Local,+read:V.Tree,+after:V.Tree,+index:U32,+rest:Nat,+count:U32,+spatial:H.Spatial,root:{V.parent(local) == None{} : Maybe<&2,U32>},derived:{H.derive(local,None{},index) == Done{spatial} : Result<&2,&2,H.Error,H.Spatial>},stored:{Array.set(H.Mark,V.thaw(read),index,H.Finished{spatial}) == V.thaw(after) : Array<H.Mark>}) -> {H.visit_mark((V.thaw(read),H.Pending{local}),index,p => a => H.visit(rest,count,p,a)) == Done{(V.thaw(after),spatial)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}:
  match local:
    case H.Local{+t,+p,+b,+l}:
      %Equal.sym(Maybe<&2,U32>,p,None{},root) : {H.visit_parent(_,H.Local{t,p,b,l},index,V.thaw(read),q => a => H.visit(rest,count,q,a)) == Done{(V.thaw(after),spatial)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      %Equal.sym(Result<&2,&2,H.Error,H.Spatial>,H.derive(local,None{},index),Done{spatial},derived) : {H.save(V.thaw(read),index,_) == Done{(V.thaw(after),spatial)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      saved(read,after,index,spatial,stored)

def child_done(+local:H.Local,+read:V.Tree,+after:V.Tree,+index:U32,+rest:Nat,+count:U32,+spatial:H.Spatial,+p:U32,+entered:V.Tree,+ancestor:V.Forest,parent:{V.parent(local) == Some{p} : Maybe<&2,U32>},enter:{Array.set(H.Mark,V.thaw(read),index,H.Visiting{}) == V.thaw(entered) : Array<H.Mark>},resolved:{H.visit(rest,count,p,V.thaw(entered)) == Done{(V.thaw(V.final(ancestor)),V.value(ancestor))} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>},derived:{H.derive(local,Some{V.global(ancestor)},index) == Done{spatial} : Result<&2,&2,H.Error,H.Spatial>},stored:{Array.set(H.Mark,V.thaw(V.final(ancestor)),index,H.Finished{spatial}) == V.thaw(after) : Array<H.Mark>}) -> {H.visit_mark((V.thaw(read),H.Pending{local}),index,q => a => H.visit(rest,count,q,a)) == Done{(V.thaw(after),spatial)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}:
  match local:
    case H.Local{+t,+parent_index,+b,+l}:
      %Equal.sym(Maybe<&2,U32>,parent_index,Some{p},parent) : {H.visit_parent(_,H.Local{t,parent_index,b,l},index,V.thaw(read),q => a => H.visit(rest,count,q,a)) == Done{(V.thaw(after),spatial)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      %Equal.sym(Array<H.Mark>,Array.set(H.Mark,V.thaw(read),index,H.Visiting{}),V.thaw(entered),enter) : {H.parent_done(local,index,H.visit(rest,count,p,_)) == Done{(V.thaw(after),spatial)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      %Equal.sym(Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>,H.visit(rest,count,p,V.thaw(entered)),Done{(V.thaw(V.final(ancestor)),V.value(ancestor))},resolved) : {H.parent_done(local,index,_) == Done{(V.thaw(after),spatial)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      parent_saved(V.final(ancestor),after,index,local,V.value(ancestor),spatial,derived,stored)

def Laws.forest_visit(fuel,forest,count,index,before,witness):
  match fuel forest:
    case 0n _:
      match witness:
    case 1n+ +rest V.Cached{+read,+spatial}:
      (bound,read_ok) = witness
      %Equal.sym(Bool,U32.is_lt(index,count),True{},bound) : {H.visit_checked(_,index,V.thaw(before),p => a => H.visit(rest,count,p,a)) == Done{(V.thaw(read),spatial)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      Equal.cong(Array<H.Mark> & H.Mark,Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>,r => H.visit_mark(r,index,p => a => H.visit(rest,count,p,a)),Array.get(H.Mark,V.thaw(before),index),(V.thaw(read),H.Finished{spatial}),read_ok)
    case 1n+ +rest V.Root{+read,+local,+after,+spatial}:
      (bound,(read_ok,(root,(derived,stored)))) = witness
      %Equal.sym(Bool,U32.is_lt(index,count),True{},bound) : {H.visit_checked(_,index,V.thaw(before),p => a => H.visit(rest,count,p,a)) == Done{(V.thaw(after),spatial)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      %Equal.sym(Array<H.Mark> & H.Mark,Array.get(H.Mark,V.thaw(before),index),(V.thaw(read),H.Pending{local}),read_ok) : {H.visit_mark(_,index,p => a => H.visit(rest,count,p,a)) == Done{(V.thaw(after),spatial)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      root_done(local,read,after,index,rest,count,spatial,root,derived,stored)
    case 1n+ +rest V.Child{+read,+local,+p,+entered,+ancestor,+after,+spatial}:
      (bound,(read_ok,(parent,(enter,(valid,(derived,stored)))))) = witness
      %Equal.sym(Bool,U32.is_lt(index,count),True{},bound) : {H.visit_checked(_,index,V.thaw(before),q => a => H.visit(rest,count,q,a)) == Done{(V.thaw(after),spatial)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      %Equal.sym(Array<H.Mark> & H.Mark,Array.get(H.Mark,V.thaw(before),index),(V.thaw(read),H.Pending{local}),read_ok) : {H.visit_mark(_,index,q => a => H.visit(rest,count,q,a)) == Done{(V.thaw(after),spatial)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}
      child_done(local,read,after,index,rest,count,spatial,p,entered,ancestor,parent,enter,Laws.forest_visit(rest,ancestor,count,p,entered,valid),derived,stored)

def append_nil(+xs:List<&2,H.Spatial>) -> {List.append(&2,H.Spatial,xs,[]) == xs : List<&2,H.Spatial>}:
  match xs:
    case []:{==}
    case +x <> +rest:Equal.cong(List<&2,H.Spatial>,List<&2,H.Spatial>,ys => x <> ys,List.append(&2,H.Spatial,rest,[]),rest,append_nil(rest))

def append_assoc(+xs:List<&2,H.Spatial>,+ys:List<&2,H.Spatial>,+zs:List<&2,H.Spatial>) -> {List.append(&2,H.Spatial,List.append(&2,H.Spatial,xs,ys),zs) == List.append(&2,H.Spatial,xs,List.append(&2,H.Spatial,ys,zs)) : List<&2,H.Spatial>}:
  match xs:
    case []:{==}
    case +x <> +rest:Equal.cong(List<&2,H.Spatial>,List<&2,H.Spatial>,tail => x <> tail,List.append(&2,H.Spatial,List.append(&2,H.Spatial,rest,ys),zs),List.append(&2,H.Spatial,rest,List.append(&2,H.Spatial,ys,zs)),append_assoc(rest,ys,zs))

def reverse_tail(+xs:List<&2,H.Spatial>,+acc:List<&2,H.Spatial>,+tail:List<&2,H.Spatial>) -> {List.reverse.go(&2,H.Spatial,xs,List.append(&2,H.Spatial,acc,tail)) == List.append(&2,H.Spatial,List.reverse.go(&2,H.Spatial,xs,acc),tail) : List<&2,H.Spatial>}:
  match xs:
    case []:{==}
    case +x <> +rest:reverse_tail(rest,x <> acc,tail)

def prepend_order(+acc:List<&2,H.Spatial>,+x:H.Spatial,+tail:List<&2,H.Spatial>) -> {List.append(&2,H.Spatial,List.reverse(&2,H.Spatial,x <> acc),tail) == List.append(&2,H.Spatial,List.reverse(&2,H.Spatial,acc),x <> tail) : List<&2,H.Spatial>}:
  Equal.trans(List<&2,H.Spatial>,List.append(&2,H.Spatial,List.reverse.go(&2,H.Spatial,acc,[x]),tail),List.append(&2,H.Spatial,List.append(&2,H.Spatial,List.reverse(&2,H.Spatial,acc),[x]),tail),List.append(&2,H.Spatial,List.reverse(&2,H.Spatial,acc),x <> tail),Equal.cong(List<&2,H.Spatial>,List<&2,H.Spatial>,xs => List.append(&2,H.Spatial,xs,tail),List.reverse.go(&2,H.Spatial,acc,[x]),List.append(&2,H.Spatial,List.reverse(&2,H.Spatial,acc),[x]),reverse_tail(acc,[],[x])),append_assoc(List.reverse(&2,H.Spatial,acc),[x],tail))

def Laws.sequence_order(forests,fuel,count,index,before,acc,witness):
  match forests:
    case []:Equal.cong(List<&2,H.Spatial>,Result<&2,&1,H.Error,List<&2,H.Spatial>>,xs => Done{xs},List.reverse(&2,H.Spatial,acc),List.append(&2,H.Spatial,List.reverse(&2,H.Spatial,acc),[]),Equal.sym(List<&2,H.Spatial>,List.append(&2,H.Spatial,List.reverse(&2,H.Spatial,acc),[]),List.reverse(&2,H.Spatial,acc),append_nil(List.reverse(&2,H.Spatial,acc))))
    case +forest <> +rest:
      (head,tail) = witness
      %Equal.sym(Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>,H.visit(fuel,count,index,V.thaw(before)),Done{(V.thaw(V.final(forest)),V.value(forest))},Laws.forest_visit(fuel,forest,count,index,before,head)) : {H.evaluated(H.evaluate_each(List.length(&2,V.Forest,rest),fuel,count,U32.inc(index)),acc,_) == Done{List.append(&2,H.Spatial,List.reverse(&2,H.Spatial,acc),V.value(forest) <> V.sequence_values(rest))} : Result<&2,&1,H.Error,List<&2,H.Spatial>>}
      Equal.trans(Result<&2,&1,H.Error,List<&2,H.Spatial>>,H.evaluate_each(List.length(&2,V.Forest,rest),fuel,count,U32.inc(index),V.thaw(V.final(forest)),V.value(forest) <> acc),Done{List.append(&2,H.Spatial,List.reverse(&2,H.Spatial,V.value(forest) <> acc),V.sequence_values(rest))},Done{List.append(&2,H.Spatial,List.reverse(&2,H.Spatial,acc),V.value(forest) <> V.sequence_values(rest))},Laws.sequence_order(rest,fuel,count,U32.inc(index),V.final(forest),V.value(forest) <> acc,tail),Equal.cong(List<&2,H.Spatial>,Result<&2,&1,H.Error,List<&2,H.Spatial>>,xs => Done{xs},List.append(&2,H.Spatial,List.reverse(&2,H.Spatial,V.value(forest) <> acc),V.sequence_values(rest)),List.append(&2,H.Spatial,List.reverse(&2,H.Spatial,acc),V.value(forest) <> V.sequence_values(rest)),prepend_order(acc,V.value(forest),V.sequence_values(rest))))


def plus_right(a:Nat,b:Nat) -> {Nat.add(a,1n+b) == 1n+Nat.add(a,b) : Nat}:
  match a:
    case 0n:{==}
    case 1n+p:Equal.cong(Nat,Nat,n => 1n+n,Nat.add(p,1n+b),1n+Nat.add(p,b),plus_right(p,b))

def zero_right(n:Nat) -> {Nat.add(n,0n) == n : Nat}:
  match n:
    case 0n:{==}
    case 1n+p:Equal.cong(Nat,Nat,n => 1n+n,Nat.add(p,0n),p,zero_right(p))

def reverse_length(+xs:List<&2,H.Spatial>,+acc:List<&2,H.Spatial>) -> {List.length(&2,H.Spatial,List.reverse.go(&2,H.Spatial,xs,acc)) == Nat.add(List.length(&2,H.Spatial,xs),List.length(&2,H.Spatial,acc)) : Nat}:
  match xs:
    case []:{==}
    case +x <> +rest:
      Equal.trans(Nat,List.length(&2,H.Spatial,List.reverse.go(&2,H.Spatial,rest,x <> acc)),Nat.add(List.length(&2,H.Spatial,rest),1n+List.length(&2,H.Spatial,acc)),1n+Nat.add(List.length(&2,H.Spatial,rest),List.length(&2,H.Spatial,acc)),reverse_length(rest,x <> acc),plus_right(List.length(&2,H.Spatial,rest),List.length(&2,H.Spatial,acc)))

def step_length(+left:Nat,+fuel:Nat,+count:U32,+index:U32,+acc:List<&2,H.Spatial>,ih:@array:Array<H.Mark> -> @+xs:List<&2,H.Spatial> -> V.length_result(H.evaluate_each(left,fuel,count,U32.inc(index),array,xs),Nat.add(left,List.length(&2,H.Spatial,xs))),result:Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>) -> V.length_result(H.evaluated(H.evaluate_each(left,fuel,count,U32.inc(index)),acc,result),1n+Nat.add(left,List.length(&2,H.Spatial,acc))):
  match result:
    case Fail{e}:Unit{}
    case Done{(array,+value)}:
      %plus_right(left,List.length(&2,H.Spatial,acc)) : V.length_result(H.evaluate_each(left,fuel,count,U32.inc(index),array,value <> acc),_)
      ih(array,value <> acc)

def each_length(left:Nat,+fuel:Nat,+count:U32,+index:U32,array:Array<H.Mark>,+acc:List<&2,H.Spatial>) -> V.length_result(H.evaluate_each(left,fuel,count,index,array,acc),Nat.add(left,List.length(&2,H.Spatial,acc))):
  match left:
    case 0n:
      Equal.trans(Nat,List.length(&2,H.Spatial,List.reverse(&2,H.Spatial,acc)),Nat.add(List.length(&2,H.Spatial,acc),0n),List.length(&2,H.Spatial,acc),reverse_length(acc,[]),zero_right(List.length(&2,H.Spatial,acc)))
    case 1n+ +rest:
      step_length(rest,fuel,count,index,acc,each_length(rest,fuel,count,U32.inc(index)),H.visit(fuel,count,index,array))

def reuse_length(+size:Nat,result:Result<&2,&1,H.Error,List<&2,H.Spatial>>,proof:V.length_result(result,size)) -> V.reusable_length(H.reusable(result),size):
  match result:
    case Fail{_}:Unit{}
    case Done{_}:proof

def result_length(+size:Nat,result:Result<&2,&1,H.Error,List<&2,H.Spatial>>,proof:V.length_result(result,Nat.add(size,0n))) -> V.reusable_length(H.reusable(result),size):
  %zero_right(size) : V.reusable_length(H.reusable(result),_)
  reuse_length(Nat.add(size,0n),result,proof)

def Laws.evaluate_length(items):
  +count = List.length(&2,H.Local,items)
  +size = U32.from_nat(count)
  result_length(count,H.evaluate_each(count,1n+count,size,0,H.fill(items,0,Array.new(H.Mark,U32.log2(U32.max(1,U32.mul(size,2))),H.Visiting{})),[]),each_length(count,1n+count,size,0,H.fill(items,0,Array.new(H.Mark,U32.log2(U32.max(1,U32.mul(size,2))),H.Visiting{})),[]))

def Laws.locals_length(rows):
  match rows:
    case []:{==}
    case S.Row{_,_,_,_} <> +rest:Equal.cong(Nat,Nat,n => 1n+n,List.length(&2,H.Local,S.locals(rest)),List.length(&2,S.Row,rest),Laws.locals_length(rest))

def Laws.rollback_length(rows):
  match rows:
    case []:{==}
    case S.Row{_,_,_,_} <> +rest:Equal.cong(Nat,Nat,n => 1n+n,List.length(&2,H.Spatial,S.rollback(rest)),List.length(&2,S.Row,rest),Laws.rollback_length(rest))

def Laws.replace_transform_length(items,index,transform):
  match items index:
    case [] _:{==}
    case H.Local{_,_,_,_} <> _ 0n:{==}
    case +item <> +rest 1n+ +n:Equal.cong(Nat,Nat,k => 1n+k,List.length(&2,H.Local,S.replace_transform(rest,n,transform)),List.length(&2,H.Local,rest),Laws.replace_transform_length(rest,n,transform))

def Laws.replace_parent_length(items,index,parent):
  match items index:
    case [] _:{==}
    case H.Local{_,_,_,_} <> _ 0n:{==}
    case +item <> +rest 1n+ +n:Equal.cong(Nat,Nat,k => 1n+k,List.length(&2,H.Local,S.replace_parent(rest,n,parent)),List.length(&2,H.Local,rest),Laws.replace_parent_length(rest,n,parent))

def Laws.batch_lengths(batch):
  match batch:
    case V.EmptyBatch{}:{==}
    case V.Pair{_,_,+rest}:Equal.cong(Nat,Nat,n => 1n+n,List.length(&2,S.Row,V.rows(rest)),List.length(&2,H.Spatial,V.values(rest)),Laws.batch_lengths(rest))

def install_cons(+row:S.Row,+value:H.Spatial,+rest:V.Batch,-before:S.Scope(),-middle:S.Scope(),-next:S.Scope(),-after:S.Scope(),transformed:{S.transformed(before,V.entity(row),V.transform(value)) == middle : S.Scope()},spatial:{S.spatial(middle,V.entity(row),value) == next : S.Scope()},tail:{S.install(V.rows(rest),V.values(rest),next) == after : S.Scope()}) -> {S.install(row <> V.rows(rest),value <> V.values(rest),before) == after : S.Scope()}:
  match row value:
    case S.Row{+entity,_,_,_} H.Spatial{H.Local{+t,+parent,+bounds,+lit},+global,+world}:
      %Equal.sym(S.Scope(),S.transformed(before,entity,t),middle,transformed) : {S.install(V.rows(rest),V.values(rest),S.spatial(_,entity,H.Spatial{H.Local{t,parent,bounds,lit},global,world})) == after : S.Scope()}
      %Equal.sym(S.Scope(),S.spatial(middle,entity,H.Spatial{H.Local{t,parent,bounds,lit},global,world}),next,spatial) : {S.install(V.rows(rest),V.values(rest),_) == after : S.Scope()}
      tail

def Laws.install_complete(batch,before,after,witness):
  match batch:
    case V.EmptyBatch{}:witness
    case V.Pair{+row,+value,+rest}:
      (middle,(next,(transform_ok,(spatial_ok,tail)))) = witness
      install_cons(row,value,rest,before,middle,next,after,
        Equal.cong(S.Scope() & Maybe<&2,C.Transform>,S.Scope(),S.written(C.Transform),V.transform_write(before,V.entity(row),V.transform(value)),(middle,Some{V.transform(value)}),transform_ok),
        Equal.cong(S.Scope() & Maybe<&2,H.Spatial>,S.Scope(),S.written(H.Spatial),V.spatial_write(middle,V.entity(row),value),(next,Some{value}),spatial_ok),
        Laws.install_complete(rest,next,after,tail))

def transform_candidate(+rows:List<&2,S.Row>,+transform:C.Transform,result:Result<&2,&2,H.Error,U32>) -> V.candidate_length(Result.bind(&2,&2,H.Error,U32,List<&2,H.Local>,result,n => Done{S.replace_transform(S.locals(rows),U32.to_nat(n),transform)}),List.length(&2,S.Row,rows)):
  match result:
    case Fail{_}:Unit{}
    case Done{+n}:Equal.trans(Nat,List.length(&2,H.Local,S.replace_transform(S.locals(rows),U32.to_nat(n),transform)),List.length(&2,H.Local,S.locals(rows)),List.length(&2,S.Row,rows),Laws.replace_transform_length(S.locals(rows),U32.to_nat(n),transform),Laws.locals_length(rows))

def parent_candidate(+rows:List<&2,S.Row>,+n:U32,result:Result<&2,&2,H.Error,Maybe<&2,U32>>) -> V.candidate_length(Result.bind(&2,&2,H.Error,Maybe<&2,U32>,List<&2,H.Local>,result,p => Done{S.replace_parent(S.locals(rows),U32.to_nat(n),p)}),List.length(&2,S.Row,rows)):
  match result:
    case Fail{_}:Unit{}
    case Done{+p}:Equal.trans(Nat,List.length(&2,H.Local,S.replace_parent(S.locals(rows),U32.to_nat(n),p)),List.length(&2,H.Local,S.locals(rows)),List.length(&2,S.Row,rows),Laws.replace_parent_length(S.locals(rows),U32.to_nat(n),p),Laws.locals_length(rows))

def indexed_parent_candidate(+rows:List<&2,S.Row>,+parent:Maybe<&2,W.Handle<D.Schema>>,result:Result<&2,&2,H.Error,U32>) -> V.candidate_length(Result.bind(&2,&2,H.Error,U32,List<&2,H.Local>,result,n => Result.bind(&2,&2,H.Error,Maybe<&2,U32>,List<&2,H.Local>,S.parent_index(parent,rows),p => Done{S.replace_parent(S.locals(rows),U32.to_nat(n),p)})),List.length(&2,S.Row,rows)):
  match result:
    case Fail{_}:Unit{}
    case Done{+n}:parent_candidate(rows,n,S.parent_index(parent,rows))

def Laws.candidate_length(edit,rows):
  match edit:
    case S.Propagate{}:Laws.locals_length(rows)
    case S.SetTransform{entity,+transform}:transform_candidate(rows,transform,S.index(rows,entity,0))
    case S.SetParent{entity,+parent}:indexed_parent_candidate(rows,parent,S.index(rows,entity,0))

def Laws.propagation_rejection(world,rows,error):{==}
def Laws.scheduled_write_clock(now,active,rest):{==}

def Laws.commit_administration(batch,before,after,admin,invocation,witness):
  Equal.cong(S.Scope(),D.World(),scope => State.reassemble(~D.Schema,~D.Columns(),~D.Resources(),~Unit,admin,invocation,scope),S.install(V.rows(batch),V.values(batch),before),after,Laws.install_complete(batch,before,after,witness))

def publish_length(+size:Nat,+result:Result<&2,&2,H.Error,List<&2,H.Local>>,proof:V.candidate_length(result,size)) -> V.reusable_length(Result.bind(&2,&2,H.Error,List<&2,H.Local>,List<&2,H.Spatial>,result,xs => H.evaluate(xs)),size):
  match result:
    case Fail{_}:Unit{}
    case Done{+items}:
      %proof : V.reusable_length(H.evaluate(items),_)
      Laws.evaluate_length(items)

def Laws.publication_lengths(edit,rows):publish_length(List.length(&2,S.Row,rows),S.candidate(edit,rows),Laws.candidate_length(edit,rows))

def zero_type(n:Nat) -> Type:
  match n:
    case 0n:Unit
    case 1n+_:Empty

def zero_successor(+n:Nat,proof:{0n == 1n+n : Nat}) -> Empty:
  %proof : zero_type(_)
  Unit{}

def predecessor(n:Nat) -> Nat:
  match n:
    case 0n:0n
    case 1n+rest:rest

def paired_cons(+row:S.Row,+value:H.Spatial,+rows:List<&2,S.Row>,+values:List<&2,H.Spatial>,result:Sigma<&2,&1,V.Batch,batch => {V.rows(batch) == rows : List<&2,S.Row>} & {V.values(batch) == values : List<&2,H.Spatial>}>) -> Sigma<&2,&1,V.Batch,batch => {V.rows(batch) == row <> rows : List<&2,S.Row>} & {V.values(batch) == value <> values : List<&2,H.Spatial>}>:
  match result:
    case (+batch,(rows_ok,values_ok)):
      (V.Pair{row,value,batch},(Equal.cong(List<&2,S.Row>,List<&2,S.Row>,xs => row <> xs,V.rows(batch),rows,rows_ok),Equal.cong(List<&2,H.Spatial>,List<&2,H.Spatial>,xs => value <> xs,V.values(batch),values,values_ok)))

def Laws.pair_lists(rows,values,equal):
  match rows values:
    case [], []:(V.EmptyBatch{},({==},{==}))
    case [], _ <> +rest:
      Empty.absurd(Sigma<&2,&1,V.Batch,batch => {V.rows(batch) == rows : List<&2,S.Row>} & {V.values(batch) == values : List<&2,H.Spatial>}>,zero_successor(List.length(&2,H.Spatial,rest),equal))
    case _ <> +rest, []:
      Empty.absurd(Sigma<&2,&1,V.Batch,batch => {V.rows(batch) == rows : List<&2,S.Row>} & {V.values(batch) == values : List<&2,H.Spatial>}>,zero_successor(List.length(&2,S.Row,rest),Equal.sym(Nat,1n+List.length(&2,S.Row,rest),0n,equal)))
    case +row <> +tail, +value <> +rest:
      paired_cons(row,value,tail,rest,Laws.pair_lists(tail,rest,Equal.cong(Nat,Nat,predecessor,1n+List.length(&2,S.Row,tail),1n+List.length(&2,H.Spatial,rest),equal)))

def Laws.one_row_read(old,mesh,accepted,stamp,tick):{==}
def Laws.one_row_ready(old,mesh,accepted,stamp,tick,fresh):
  (V.changed_scope(old,mesh,accepted,stamp,tick,fresh,False{}),(V.changed_scope(old,mesh,accepted,stamp,tick,fresh,True{}),({==},({==},{==}))))

def Laws.forward_certificate(child,root,child_value,root_value,child_parent,root_parent,root_derived,child_derived):
  (
    ({==}, (
      {==}, (
        child_parent, (
          {==}, (
            ({==}, ({==}, (root_parent, (root_derived, {==})))),
            (child_derived, {==})
          )
        )
      )
    )),
    (({==}, {==}), Unit{})
  )

def Laws.forward_evaluate(child,root,child_value,root_value,child_parent,root_parent,root_derived,child_derived):
  Equal.cong(Result<&2,&1,H.Error,List<&2,H.Spatial>>,Result<&2,&2,H.Error,List<&2,H.Spatial>>,H.reusable,H.evaluate_each(2n,3n,2,0,V.thaw(V.four(H.Pending{child},H.Pending{root})),[]),Done{[child_value,root_value]},Laws.sequence_order(V.forward_sequence(child,root,child_value,root_value),3n,2,0,V.four(H.Pending{child},H.Pending{root}),[],Laws.forward_certificate(child,root,child_value,root_value,child_parent,root_parent,root_derived,child_derived)))

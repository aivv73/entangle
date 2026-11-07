import Base
import ../../deps/bendvy/src/ecs/lifecycle.bend as Life
import ../../src/scene-schema.bend as D
import ../../deps/bendvy/src/ecs/execution-state.bend as State
import ../../deps/bendvy/src/ecs/change-tick.bend as Tick
import ../../deps/bendvy/src/ecs/clock-state.bend as Clock
import ./spec.bend as V
import ../../src/hierarchy.bend as H
import ../../src/scene-hierarchy.bend as S
import ../../src/components.bend as C

law evaluate_length:
  for +items:List<&2,H.Local>
  V.reusable_length(H.evaluate(items),List.length(&2,H.Local,items))

law forest_visit:
  for +fuel:Nat
  for +forest:V.Forest
  for +count:U32
  for +index:U32
  for +before:V.Tree
  for witness:V.admitted(fuel,forest,count,index,before)
  {H.visit(fuel,count,index,V.thaw(before)) == Done{(V.thaw(V.final(forest)),V.value(forest))} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}

law rejection_visit:
  for +fuel:Nat
  for +path:V.Rejection
  for +count:U32
  for +index:U32
  for +before:V.Tree
  for witness:V.rejected(fuel,path,count,index,before)
  {H.visit(fuel,count,index,V.thaw(before)) == Fail{V.error(path,index)} : Result<&2,&1,H.Error,Array<H.Mark> & H.Spatial>}

law sequence_order:
  for +forests:List<&2,V.Forest>
  for +fuel:Nat
  for +count:U32
  for +index:U32
  for +before:V.Tree
  for +acc:List<&2,H.Spatial>
  for witness:V.sequence_valid(fuel,count,index,before,forests)
  {H.evaluate_each(List.length(&2,V.Forest,forests),fuel,count,index,V.thaw(before),acc) == Done{List.append(&2,H.Spatial,List.reverse(&2,H.Spatial,acc),V.sequence_values(forests))} : Result<&2,&1,H.Error,List<&2,H.Spatial>>}


law locals_length:
  for +rows:List<&2,S.Row>
  {List.length(&2,H.Local,S.locals(rows)) == List.length(&2,S.Row,rows) : Nat}

law rollback_length:
  for +rows:List<&2,S.Row>
  {List.length(&2,H.Spatial,S.rollback(rows)) == List.length(&2,S.Row,rows) : Nat}

law replace_transform_length:
  for +items:List<&2,H.Local>
  for +index:Nat
  for +transform:C.Transform
  {List.length(&2,H.Local,S.replace_transform(items,index,transform)) == List.length(&2,H.Local,items) : Nat}

law replace_parent_length:
  for +items:List<&2,H.Local>
  for +index:Nat
  for +parent:Maybe<&2,U32>
  {List.length(&2,H.Local,S.replace_parent(items,index,parent)) == List.length(&2,H.Local,items) : Nat}

law batch_lengths:
  for +batch:V.Batch
  {List.length(&2,S.Row,V.rows(batch)) == List.length(&2,H.Spatial,V.values(batch)) : Nat}

law install_complete:
  for +batch:V.Batch
  for -before:S.Scope()
  for -after:S.Scope()
  for witness:V.ready(batch,before,after)
  {S.install(V.rows(batch),V.values(batch),before) == after : S.Scope()}

law candidate_length:
  for +edit:S.Edit
  for +rows:List<&2,S.Row>
  V.candidate_length(S.candidate(edit,rows),List.length(&2,S.Row,rows))

law propagation_rejection:
  for world:D.World()
  for +rows:List<&2,S.Row>
  for error:H.Error
  {S.rejected(S.Propagate{},world,rows,error) == (S.commit(world,rows,S.rollback(rows)),Fail{error}) : D.World() & Result<&2,&2,H.Error,Unit>}

law scheduled_write_clock:
  for +now:Tick.Tick
  for +active:Tick.Tick
  for +rest:List<&2,Tick.Tick>
  {Clock.write(Clock.State{now,active <> rest}) == (Clock.State{now,active <> rest},active) : Clock.State & Tick.Tick}

law commit_administration:
  for +batch:V.Batch
  for -before:S.Scope()
  for -after:S.Scope()
  for admin:State.Administration<D.Schema,D.Columns(),D.Resources(),Unit>
  for invocation:State.Invocation<D.Schema>
  for witness:V.ready(batch,before,after)
  {S.commit_scope(V.rows(batch),V.values(batch),(admin,(invocation,before))) == State.reassemble(~D.Schema,~D.Columns(),~D.Resources(),~Unit,admin,invocation,after) : D.World()}

law publication_lengths:
  for +edit:S.Edit
  for +rows:List<&2,S.Row>
  V.reusable_length(Result.bind(&2,&2,H.Error,List<&2,H.Local>,List<&2,H.Spatial>,S.candidate(edit,rows),xs => H.evaluate(xs)),List.length(&2,S.Row,rows))

law pair_lists:
  for +rows:List<&2,S.Row>
  for +values:List<&2,H.Spatial>
  for equal:{List.length(&2,S.Row,rows) == List.length(&2,H.Spatial,values) : Nat}
  Sigma<&2,&1,V.Batch,batch => {V.rows(batch) == rows : List<&2,S.Row>} & {V.values(batch) == values : List<&2,H.Spatial>}>

law one_row_read:
  for +old:C.Transform
  for +mesh:C.MeshRef
  for +accepted:H.Spatial
  for +stamp:Life.Stamp
  for +tick:Tick.Tick
  {S.read_rows([V.handle()],V.scope(old,mesh,accepted,stamp,tick),[]) == (V.scope(old,mesh,accepted,stamp,tick),Done{[S.Row{V.handle(),old,mesh,accepted}]}) : S.Scope() & Result<&2,&2,H.Error,List<&2,S.Row>>}

law one_row_ready:
  for +old:C.Transform
  for +mesh:C.MeshRef
  for +accepted:H.Spatial
  for +stamp:Life.Stamp
  for +tick:Tick.Tick
  for +fresh:H.Spatial
  V.ready(V.one_batch(old,mesh,accepted,fresh),V.scope(old,mesh,accepted,stamp,tick),V.changed_scope(old,mesh,accepted,stamp,tick,fresh,True{}))

law forward_certificate:
  for +child:H.Local
  for +root:H.Local
  for +child_value:H.Spatial
  for +root_value:H.Spatial
  for child_parent:{V.parent(child) == Some{1} : Maybe<&2,U32>}
  for root_parent:{V.parent(root) == None{} : Maybe<&2,U32>}
  for root_derived:{H.derive(root,None{},1) == Done{root_value} : Result<&2,&2,H.Error,H.Spatial>}
  for child_derived:{H.derive(child,Some{V.spatial_global(root_value)},0) == Done{child_value} : Result<&2,&2,H.Error,H.Spatial>}
  V.sequence_valid(3n,2,0,V.four(H.Pending{child},H.Pending{root}),V.forward_sequence(child,root,child_value,root_value))

law forward_evaluate:
  for +child:H.Local
  for +root:H.Local
  for +child_value:H.Spatial
  for +root_value:H.Spatial
  for child_parent:{V.parent(child) == Some{1} : Maybe<&2,U32>}
  for root_parent:{V.parent(root) == None{} : Maybe<&2,U32>}
  for root_derived:{H.derive(root,None{},1) == Done{root_value} : Result<&2,&2,H.Error,H.Spatial>}
  for child_derived:{H.derive(child,Some{V.spatial_global(root_value)},0) == Done{child_value} : Result<&2,&2,H.Error,H.Spatial>}
  {H.evaluate([child,root]) == Done{[child_value,root_value]} : Result<&2,&2,H.Error,List<&2,H.Spatial>>}

law cycle_evaluate:
  for +a:C.Transform
  for +b:C.Transform
  for +bounds:H.Bounds
  for +lit:Bool
  {H.evaluate([H.Local{a,Some{1},bounds,lit},H.Local{b,Some{0},bounds,lit}]) == Fail{H.Cycle{0}} : Result<&2,&2,H.Error,List<&2,H.Spatial>>}

law missing_evaluate:
  for +transform:C.Transform
  for +bounds:H.Bounds
  for +lit:Bool
  {H.evaluate([H.Local{transform,Some{1},bounds,lit}]) == Fail{H.MissingParent{1}} : Result<&2,&2,H.Error,List<&2,H.Spatial>>}

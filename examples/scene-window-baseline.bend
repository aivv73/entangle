import Base
import ../src/error.bend as Error
import ../src/measurement-counters.bend as Count
import ../src/baseline-output.bend as Out
import ./scene-window-app.bend as SceneApp
import ../src/app.bend as Scope
import ../src/time.bend as Time
import ./scene.bend as Check
import ./scene-render.bend as Extract
import ../src/scene-window.bend as Win
import ../src/scene-diagnostics.bend as D
import ../src/scene-render.bend as R
import ../src/scene.bend as Scene
import ../src/scene-observe.bend as Observe
import ../src/scene-schema.bend as Schema
import ../src/scene-draw.bend as Draw
import ../deps/bendvy/src/ecs/inspector.bend as I
import ../deps/bendvy/src/ecs/change-tick.bend as Tick
import ../deps/bendvy/src/ecs/world.bend as World
import ../deps/bend-vulkan/Vulkan.bend as V
import ../src/input.bend as Camera
import ../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as W

type Updated is Type:Updated{state:SceneApp.State,spans:List<&2,D.Span>,steps:Nat,dropped:Nat}
type Sample is Data:
  Sample{attempt:U32,phase:String,tick:U32,draw_tick:U32,digest:U32,retained_digest:U32,width:U32,height:U32,probe:D.Probe,spans:List<&2,D.Span>,steps:Nat,dropped:Nat}
type Run is Type:
  Run{renderer:Win.Renderer,state:SceneApp.State,samples:List<&2,Sample>,attempt:U32,accepted:U32,steady_ticks:U32,start:D.Metric<&2,W.U64>,startup:D.Metric<&2,W.U64>,deadline:Nat}
type Evidence is Data:
  Evidence{samples:List<&2,Sample>,startup:D.Metric<&2,W.U64>,attempts:U32,accepted:U32,ticks:U32,live_before_close:U32,device:V.PhysicalDeviceProperties,graphics:U32,present:U32}

def clock() -> V.Action(D.Metric<&2,W.U64>):
  V.Action.lift(D.Metric<&2,W.U64>,D.now(True{}))

def span(name:String,start:D.Metric<&2,W.U64>,end:D.Metric<&2,W.U64>) -> D.Span:
  D.Span{name,D.elapsed(start,end)}

def identities(baseline:List<&2,Check.Identity>,admitted:List<&2,World.Handle<Schema.Schema>>) -> List<&2,Check.Identity>:
  match baseline:
    case []:Check.identities(admitted,0)
    case _:baseline

def extracted(pair:Scene.Application() & (I.Instance<Schema.Schema> & Draw.DrawList),baseline:List<&2,Check.Identity>,+rows:List<&2,Observe.Row>,tick:U32,fixed:Time.Clock,retained:Draw.DrawList,saved:List<&2,Observe.Row>,spans:List<&2,D.Span>) -> V.Action(Updated):
  (app,(inspector,Draw.DrawList{+items})) = pair
  do V.Action<Updated>:
    Error.require(Check.drawing_equal(items,rows),"Baseline extraction changed ordered drawing bits")
    return Updated{SceneApp.State{app,inspector,baseline,rows,Draw.DrawList{items},retained,saved,tick,fixed},spans,1n,0n}

def extraction_done(pair:Scene.Application() & (I.Instance<Schema.Schema> & Result<&2,&2,Unit,Draw.DrawList>),before:String,prior:String,baseline:List<&2,Check.Identity>,rows:List<&2,Observe.Row>,tick:U32,fixed:Time.Clock,retained:Draw.DrawList,saved:List<&2,Observe.Row>,spans:List<&2,D.Span>,start:D.Metric<&2,W.U64>) -> V.Action(Updated):
  do V.Action<Updated>:
    +end:D.Metric<&2,W.U64> <- clock()
    pair:Scene.Application() & (I.Instance<Schema.Schema> & Draw.DrawList) <- Extract.observed(before,prior,pair)
    extracted(pair,baseline,rows,tick,fixed,retained,saved,span("extraction",start,end) <> spans)

def extract_key(app:Scene.Application(),pair:I.Instance<Schema.Schema> & String,before:String,baseline:List<&2,Check.Identity>,rows:List<&2,Observe.Row>,tick:U32,fixed:Time.Clock,retained:Draw.DrawList,saved:List<&2,Observe.Row>,spans:List<&2,D.Span>) -> V.Action(Updated):
  (inspector,key) = pair
  do V.Action<Updated>:
    start:D.Metric<&2,W.U64> <- clock()
    extraction_done(Observe.draw_list(app,inspector),before,key,baseline,rows,tick,fixed,retained,saved,spans,start)

def extract_clock(pair:Scene.Application() & Tick.Tick,inspector:I.Instance<Schema.Schema>,baseline:List<&2,Check.Identity>,rows:List<&2,Observe.Row>,tick:U32,fixed:Time.Clock,retained:Draw.DrawList,saved:List<&2,Observe.Row>,spans:List<&2,D.Span>) -> V.Action(Updated):
  (app,world_clock) = pair
  extract_key(app,Check.instance_key(inspector),Nat.show(Tick.total(world_clock)),baseline,rows,tick,fixed,retained,saved,spans)

def extract(app:Scene.Application(),inspector:I.Instance<Schema.Schema>,baseline:List<&2,Check.Identity>,rows:List<&2,Observe.Row>,tick:U32,fixed:Time.Clock,retained:Draw.DrawList,saved:List<&2,Observe.Row>,spans:List<&2,D.Span>) -> V.Action(Updated):
  extract_clock(Check.app_clock(app),inspector,baseline,rows,tick,fixed,retained,saved,spans)

def observed(pair:Scene.Application() & (I.Instance<Schema.Schema> & Result<&2,&2,Unit,Observe.Snapshot>),baseline:List<&2,Check.Identity>,+tick:U32,fixed:Time.Clock,retained:Draw.DrawList,saved:List<&2,Observe.Row>,spans:List<&2,D.Span>,start:D.Metric<&2,W.U64>) -> V.Action(Updated):
  match pair:
    case (app,(inspector,Done{Observe.Snapshot{+live,+admitted,+exhausted,+clean,+rows}})):
      +baseline = identities(baseline,admitted)
      do V.Action<Updated>:
        +end:D.Metric<&2,W.U64> <- clock()
        V.Action.lift(Unit,Check.validate(tick,baseline,Observe.Snapshot{live,admitted,exhausted,clean,rows}))
        extract(app,inspector,baseline,rows,tick,fixed,retained,saved,span("observation",start,end) <> spans)
    case _:IO.pure(V.VkResult(Updated),Fail{(1,"Baseline observation refused")})

def ticked(app:Scene.Application(),inspector:I.Instance<Schema.Schema>,baseline:List<&2,Check.Identity>,tick:U32,fixed:Time.Clock,retained:Draw.DrawList,saved:List<&2,Observe.Row>,start:D.Metric<&2,W.U64>) -> V.Action(Updated):
  do V.Action<Updated>:
    +end:D.Metric<&2,W.U64> <- clock()
    before:D.Metric<&2,W.U64> <- clock()
    observed(Observe.snapshot(app,inspector),baseline,tick,fixed,retained,saved,[span("simulation",start,end)],before)

def advance(state:SceneApp.State) -> V.Action(Updated):
  SceneApp.State{app,inspector,baseline,+rows,Draw.DrawList{+items},Draw.DrawList{+held},+saved,+tick,fixed} = state
  do V.Action<Updated>:
    Error.require(Check.drawing_equal(items,rows) && Check.drawing_equal(held,saved),"Baseline retained drawing changed")
    start:D.Metric<&2,W.U64> <- clock()
    app:Scene.Application() <- V.Action.lift(Scene.Application(),Scene.tick(app))
    ticked(app,inspector,baseline,U32.inc(tick),fixed,Draw.DrawList{held},saved,start)

def missing_tick(replay:Bool) -> List<&2,D.Span>:
  +reason = Bool.pick(String,replay,"not executed in replay","not scheduled")
  [D.Span{"simulation",D.Unavailable{reason}},D.Span{"observation",D.Unavailable{reason}},D.Span{"extraction",D.Unavailable{reason}}]

def sum_metric(left:D.Metric<&2,W.U64>,right:D.Metric<&2,W.U64>) -> D.Metric<&2,W.U64>:
  match left right:
    case D.Available{a} D.Available{b}:D.Available{W.add(a,b)}
    case D.Unavailable{reason} _:D.Unavailable{reason}
    case _ D.Unavailable{reason}:D.Unavailable{reason}

def sum_spans(values:List<&2,D.Span>,+prior:List<&2,D.Span>) -> List<&2,D.Span>:
  match values prior:
    case _, []:values
    case [], _:[]
    case D.Span{+name,value} <> rest, _:D.Span{name,sum_metric(value,Out.lookup(name,prior))} <> sum_spans(rest,prior)

def next_step(updated:Updated,prior:List<&2,D.Span>,next:SceneApp.State -> List<&2,D.Span> -> V.Action(Updated)) -> V.Action(Updated):
  Updated{state,spans,_,_} = updated
  next(state)(sum_spans(spans,prior))

def steps(remaining:Nat,state:SceneApp.State,spans:List<&2,D.Span>,+count:Nat,dropped:Nat) -> V.Action(Updated):
  match remaining:
    case 0n:V.Action.pure(Updated,Updated{state,spans,count,dropped})
    case 1n+rest:
      do V.Action<Updated>:
        updated:Updated <- advance(state)
        next_step(updated,spans,state => spans => steps(rest,state,spans,count,dropped))

def planned(count:Nat,state:SceneApp.State,dropped:Nat) -> V.Action(Updated):
  match count:
    case 0n:V.Action.pure(Updated,Updated{state,missing_tick(False{}),0n,dropped})
    case 1n++rest:steps(1n+rest,state,[],1n+rest,dropped)

def batch(pair:SceneApp.State & Time.Batch) -> V.Action(Updated):
  (state,Time.Batch{fixed,+count,dropped}) = pair
  planned(count,state,dropped)

def scheduled(state:SceneApp.State,now:Nat,replay:Bool) -> V.Action(Updated):
  match replay:
    case True{}:V.Action.pure(Updated,Updated{state,missing_tick(True{}),0n,0n})
    case False{}:batch(SceneApp.schedule(state,now))

def eligible(probe:D.Probe,width:U32,height:U32) -> Bool:
  match probe:
    case D.On{owner,props,active,generation,startup,counters,spans,D.Completed{V.Presented{},False{}},gpu}:U32.is_eq(width,640) && U32.is_eq(height,480)
    case _:False{}

def phase(accepted:U32) -> String:
  match accepted:
    case 0:"startup"
    case _:Bool.pick(String,U32.is_le(accepted,30),"warmup","steady")

def startup(old:D.Metric<&2,W.U64>,accepted:U32,start:D.Metric<&2,W.U64>,end:D.Metric<&2,W.U64>,ok:Bool) -> D.Metric<&2,W.U64>:
  match accepted ok:
    case 0 True{}:D.elapsed(start,end)
    case _ _:old

def buffer_spans(samples:List<&2,Sample>,checks:D.Span,loop:D.Span) -> List<&2,Sample>:
  match samples:
    case []:[]
    case Sample{a,p,t,dt,d,rd,w,h,probe,spans,steps,dropped} <> rest:Sample{a,p,t,dt,d,rd,w,h,probe,checks <> loop <> spans,steps,dropped} <> rest

def buffered(run:Run,start:D.Metric<&2,W.U64>,loop_start:D.Metric<&2,W.U64>) -> V.Action(Run):
  Run{renderer,state,samples,attempt,accepted,ticks,origin,startup,deadline} = run
  do V.Action<Run>:
    +end:D.Metric<&2,W.U64> <- clock()
    return Run{renderer,state,buffer_spans(samples,span("evidence_checks_digest_initial_buffer",start,end),span("loop_through_initial_buffer",loop_start,end)),attempt,accepted,ticks,origin,startup,deadline}

def record_sample(renderer:Win.Renderer,state:SceneApp.State,+samples:List<&2,Sample>,+attempt:U32,+accepted:U32,+ticks:U32,+start:D.Metric<&2,W.U64>,old_startup:D.Metric<&2,W.U64>,deadline:Nat,+replay:Bool,+spans:List<&2,D.Span>,render_start:D.Metric<&2,W.U64>,+loop_start:D.Metric<&2,W.U64>,+width:U32,+height:U32,+steps:Nat,dropped:Nat) -> V.Action(Run):
  Win.Renderer{window,target,id,count,+probe} = renderer
  SceneApp.State{app,inspector,baseline,+rows,Draw.DrawList{+items},Draw.DrawList{+held},+saved,+tick,fixed} = state
  +ok = eligible(probe,width,height)
  do V.Action<Run>:
    +end:D.Metric<&2,W.U64> <- clock()
    Error.require(Check.drawing_equal(items,rows) && Check.drawing_equal(held,saved),"Baseline frame changed exact ordered drawing bits")
    +sample:Sample = Sample{attempt,phase(accepted),tick,Bool.pick(U32,replay,1,tick),SceneApp.digest(Bool.pick(List<&2,Draw.DrawItem>,replay,held,items),2166136261),SceneApp.digest(held,2166136261),width,height,probe,span("render_call_wall",render_start,end) <> span("loop_service_before_buffer",loop_start,end) <> spans,steps,dropped}
    buffered(Run{Win.Renderer{window,target,id,count,probe},SceneApp.State{app,inspector,baseline,rows,Draw.DrawList{items},Draw.DrawList{held},saved,tick,fixed},sample <> samples,U32.inc(attempt),U32.add(accepted,Bool.to_u32(ok)),U32.add(ticks,Bool.pick(U32,ok && U32.is_gt(accepted,30),U32.from_nat(steps),0)),start,startup(old_startup,accepted,start,end,ok),deadline},end,loop_start)

def render(updated:Updated,renderer:Win.Renderer,snapshot:V.WindowSnapshot,+replay:Bool,samples:List<&2,Sample>,attempt:U32,+accepted:U32,ticks:U32,start:D.Metric<&2,W.U64>,startup:D.Metric<&2,W.U64>,deadline:Nat,poll:D.Span,loop_start:D.Metric<&2,W.U64>) -> V.Action(Run):
  Updated{SceneApp.State{app,inspector,baseline,+rows,+draws,+held,+saved,tick,fixed},spans,steps,dropped} = updated
  V.WindowSnapshot{+width,+height,mapped,focused,captured,events} = snapshot
  do V.Action<Run>:
    renderer:Win.Renderer <- Win.require_stable(renderer,accepted)
    Error.require(U32.is_eq(width,640) && U32.is_eq(height,480),"Baseline resized; repeat invalid; partial counters unavailable")
    Error.require(SceneApp.unchanged(draws,rows) && SceneApp.unchanged(held,saved),"Baseline pre-render drawing changed")
    before:D.Metric<&2,W.U64> <- clock()
    pair:Win.Renderer & Result<&2,&2,Win.InputError,Unit> <- Win.frame(renderer,Camera.drain(V.WindowSnapshot,pending => V.WindowSnapshot{width,height,mapped,focused,captured,pending},events),w => h => SceneApp.view(Camera.initial(),w,h),Bool.pick(Draw.DrawList,replay,held,draws))
    renderer:Win.Renderer <- Error.owner(Win.Renderer,Win.InputError,Unit,pair,"Window drawing rejected")
    record_sample(renderer,SceneApp.State{app,inspector,baseline,rows,draws,held,saved,tick,fixed},samples,attempt,accepted,ticks,start,startup,deadline,replay,poll <> spans,before,loop_start,width,height,steps,dropped)

def polled(pair:Win.Renderer & V.WindowSnapshot,state:SceneApp.State,+replay:Bool,samples:List<&2,Sample>,attempt:U32,+accepted:U32,ticks:U32,start:D.Metric<&2,W.U64>,startup:D.Metric<&2,W.U64>,deadline:Nat,poll_start:D.Metric<&2,W.U64>,loop_start:D.Metric<&2,W.U64>) -> V.Action(Run):
  (renderer,snapshot) = pair
  do V.Action<Run>:
    +end:D.Metric<&2,W.U64> <- clock()
    now:Nat <- V.Action.lift(Nat,IO.now())
    updated:Updated <- scheduled(state,now,replay)
    render(updated,renderer,snapshot,replay,samples,attempt,accepted,ticks,start,startup,deadline,span("poll",poll_start,end),loop_start)

def step(run:Run,replay:Bool) -> V.Action(Run):
  Run{renderer,state,samples,attempt,accepted,ticks,start,startup,deadline} = run
  do V.Action<Run>:
    +before:D.Metric<&2,W.U64> <- clock()
    pair:Win.Renderer & V.WindowSnapshot <- Win.poll(renderer)
    polled(pair,state,replay,samples,attempt,accepted,ticks,start,startup,deadline,before,before)

def finish_info(pair:Win.Renderer & (V.PhysicalDeviceProperties & (U32 & U32)),samples:List<&2,Sample>,startup:D.Metric<&2,W.U64>,attempt:U32,accepted:U32,ticks:U32) -> V.Action(Evidence):
  (renderer,(props,(g,p))) = pair
  do V.Action<Evidence>:
    live:U32 <- V.debug_live_objects()
    Win.close(renderer)
    return Evidence{List.reverse(&2,Sample,samples),startup,attempt,accepted,ticks,live,props,g,p}

def finish(renderer:Win.Renderer,samples:List<&2,Sample>,startup:D.Metric<&2,W.U64>,attempt:U32,accepted:U32,ticks:U32) -> V.Action(Evidence):
  do V.Action<Evidence>:
    info:Win.Renderer & (V.PhysicalDeviceProperties & (U32 & U32)) <- Win.device_info(renderer)
    finish_info(info,samples,startup,attempt,accepted,ticks)

def continue(done:Bool,run:Run,replay:Bool,next:Run -> V.Action(Evidence)) -> V.Action(Evidence):
  match done:
    case True{}:
      Run{renderer,state,samples,attempt,accepted,ticks,start,startup,deadline} = run
      finish(renderer,samples,startup,attempt,accepted,ticks)
    case False{}:
      do V.Action<Evidence>:
        run:Run <- step(run,replay)
        next(run)

def capacity_result(done:Bool,run:Run) -> V.Action(Evidence):
  match done:
    case True{}:
      Run{renderer,state,samples,attempt,accepted,ticks,start,startup,deadline} = run
      finish(renderer,samples,startup,attempt,accepted,ticks)
    case False{}:IO.pure(V.VkResult(Evidence),Fail{(1,"baseline attempt capacity exhausted; partial counters unavailable; repeat invalid")})

def quota_met(accepted:U32,ticks:U32,replay:Bool) -> Bool:
  U32.is_ge(accepted,151) && (replay || U32.is_ge(ticks,8))

def loop(remaining:Nat,run:Run,+replay:Bool) -> V.Action(Evidence):
  match remaining:
    case 0n:
      Run{renderer,state,samples,attempt,+accepted,+ticks,start,startup,deadline} = run
      capacity_result(quota_met(accepted,ticks,replay),Run{renderer,state,samples,attempt,accepted,ticks,start,startup,deadline})
    case 1n+rest:
      Run{renderer,state,samples,attempt,+accepted,+ticks,start,startup,+deadline} = run
      do V.Action<Evidence>:
        +now:Nat <- V.Action.lift(Nat,IO.now())
        Error.require(Nat.is_lt(now,deadline),"baseline deadline exceeded; partial counters unavailable; repeat invalid")
        continue(quota_met(accepted,ticks,replay),Run{renderer,state,samples,attempt,accepted,ticks,start,startup,deadline},replay,next => loop(rest,next,replay))

def validate_replay(state:SceneApp.State) -> V.Action(SceneApp.State):
  SceneApp.State{app,inspector,baseline,+rows,+draws,+held,+saved,+tick,fixed} = state
  do V.Action<SceneApp.State>:
    Error.require(U32.is_eq(tick,2) && SceneApp.unchanged(draws,rows) && SceneApp.unchanged(held,saved),"Replay must retain tick one while world reaches tick two")
    return SceneApp.State{app,inspector,baseline,rows,draws,held,saved,tick,fixed}

def advanced_replay(updated:Updated) -> V.Action(Updated):
  Updated{state,spans,steps,dropped} = updated
  do V.Action<Updated>:
    state:SceneApp.State <- validate_replay(state)
    return Updated{state,spans,steps,dropped}


def initialize_mode(replay:Bool,state:SceneApp.State) -> V.Action(Updated):
  match replay:
    case False{}:V.Action.pure(Updated,Updated{SceneApp.retain(state),[],0n,0n})
    case True{}:
      do V.Action<Updated>:
        updated:Updated <- advance(SceneApp.retain(state))
        advanced_replay(updated)

def replay_initial_spans(values:List<&2,D.Span>) -> List<&2,D.Span>:
  match values:
    case []:[]
    case D.Span{name,value} <> rest:D.Span{"replay_initial_" ++ name,value} <> replay_initial_spans(rest)

def initial_ready(updated:Updated,renderer:Win.Renderer,+replay:Bool,+start:D.Metric<&2,W.U64>,deadline:Nat,spans:List<&2,D.Span>) -> V.Action(Evidence):
  Updated{state,second,_,_} = updated
  do V.Action<Evidence>:
    run:Run <- render(Updated{state,List.append(&2,D.Span,replay_initial_spans(second),spans),0n,0n},renderer,V.WindowSnapshot{640,480,True{},True{},False{},[]},replay,[],0,0,0,start,D.Unavailable{"no completed frame"},deadline,D.Span{"poll",D.Unavailable{"startup no poll"}},start)
    loop(2999n,run,replay)

def initialized(updated:Updated,renderer:Win.Renderer,+replay:Bool,+start:D.Metric<&2,W.U64>,deadline:Nat) -> V.Action(Evidence):
  Updated{state,spans,_,_} = updated
  do V.Action<Evidence>:
    second:Updated <- initialize_mode(replay,state)
    initial_ready(second,renderer,replay,start,deadline,spans)

def add_spans(updated:Updated,prior:List<&2,D.Span>) -> Updated:
  Updated{state,spans,steps,dropped} = updated
  Updated{state,List.append(&2,D.Span,spans,prior),steps,dropped}

def setup(pair:Win.Renderer & List<&2,D.Span>,+replay:Bool,+start:D.Metric<&2,W.U64>,+now:Nat,setup_end:D.Metric<&2,W.U64>) -> V.Action(Evidence):
  (renderer,spans) = pair
  do V.Action<Evidence>:
    before:D.Metric<&2,W.U64> <- clock()
    app:Scene.Application() <- V.Action.lift(Scene.Application(),Scene.create())
    +created:D.Metric<&2,W.U64> <- clock()
    app:Scene.Application() <- V.Action.lift(Scene.Application(),Scene.tick(app))
    end_tick:D.Metric<&2,W.U64> <- clock()
    tick_now:Nat <- V.Action.lift(Nat,IO.now())
    obs_start:D.Metric<&2,W.U64> <- clock()
    updated:Updated <- observed(Observe.snapshot(app,I.Fresh{}),[],1,Time.start(tick_now),Draw.DrawList{[]},[],[span("simulation",created,end_tick)],obs_start)
    initialized(add_spans(updated,span("open_window_device_mesh",start,setup_end) <> span("world_create",before,created) <> spans),renderer,replay,start,Nat.add(now,60000n))

def run(+entry:V.Entry,+replay:Bool) -> V.Action(Evidence):
  do V.Action<Evidence>:
    +start:D.Metric<&2,W.U64> <- clock()
    +now:Nat <- V.Action.lift(Nat,IO.now())
    renderer:Win.Renderer <- Win.open_measured(entry,"Entangle baseline",SceneApp.mesh())
    +end:D.Metric<&2,W.U64> <- clock()
    setup(Win.setup_spans(renderer),replay,start,now,end)

def sample(value:Sample) -> String:
  Sample{attempt,phase,tick,draw_tick,digest,retained,width,height,probe,spans,steps,dropped} = value
  "{\"fixed_steps\":" ++ Nat.show(steps) ++ ",\"dropped_steps\":" ++ Nat.show(dropped) ++ ",\"schema\":1,\"kind\":\"attempt\",\"attempt\":" ++ U32.show(attempt) ++ ",\"phase\":" ++ Out.quote(phase) ++ ",\"world_tick\":" ++ U32.show(tick) ++ ",\"draw_tick\":" ++ U32.show(draw_tick) ++ ",\"drawing_digest\":" ++ U32.show(digest) ++ ",\"retained_digest\":" ++ U32.show(retained) ++ ",\"width\":" ++ U32.show(width) ++ ",\"height\":" ++ U32.show(height) ++ ",\"application_cpu_ns\":{" ++ Out.spans(spans) ++ "}," ++ Out.probe(probe) ++ "}"

def emit(values:List<&2,Sample>) -> IO(Unit):
  match values:
    case []:IO.pure(Unit,Unit{})
    case value <> rest:
      do IO<Unit>:
        IO.print(sample(value))
        emit(rest)

def renderer_spans(probe:D.Probe) -> List<&2,D.Span>:
  match probe:
    case D.Off{}:[]
    case D.On{owner,props,active,generation,startup,counters,spans,outcome,gpu}:spans

def gpu_metric(probe:D.Probe) -> D.Metric<&2,W.U64>:
  match probe:
    case D.On{owner,props,active,generation,startup,counters,spans,outcome,D.Gpu{g,raw,bound,D.Available{duration}}}:D.Available{W.of_u32(U32.from_nat(F32.to_nat(duration)))}
    case _:D.Unavailable{"GPU duration unavailable"}

def metric_selected(gpu:Bool,probe:D.Probe,name:String,spans:List<&2,D.Span>) -> D.Metric<&2,W.U64>:
  match gpu:
    case True{}:gpu_metric(probe)
    case False{}:Out.lookup(name,spans)

def sample_metric(value:Sample,+name:String) -> D.Metric<&2,W.U64>:
  Sample{attempt,phase,tick,draw_tick,digest,retained,width,height,+probe,spans,steps,dropped} = value
  metric_selected(String.eq(name,"gpu_interval_truncated_ns"),probe,name,List.append(&2,D.Span,spans,renderer_spans(probe)))

def primary(+value:Sample) -> Bool:
  Sample{attempt,phase,tick,draw_tick,digest,retained,width,height,probe,spans,steps,dropped} = value
  String.eq(phase,"steady") && eligible(probe,width,height)

def collect_value(value:D.Metric<&2,W.U64>,numbers:List<&2,Nat>,missing:Nat,next:List<&2,Nat> -> Nat -> List<&2,Nat> & Nat) -> List<&2,Nat> & Nat:
  match value:
    case D.Available{ns}:next(Out.insert(Out.nat(ns),numbers))(missing)
    case D.Unavailable{reason}:next(numbers)(Nat.add(missing,1n))

def collect_selected(selected:Bool,value:Sample,name:String,numbers:List<&2,Nat>,missing:Nat,next:List<&2,Nat> -> Nat -> List<&2,Nat> & Nat) -> List<&2,Nat> & Nat:
  match selected:
    case False{}:next(numbers)(missing)
    case True{}:collect_value(sample_metric(value,name),numbers,missing,next)

def collect_metric(+name:String,values:List<&2,Sample>,numbers:List<&2,Nat>,missing:Nat) -> List<&2,Nat> & Nat:
  match values:
    case []:(numbers,missing)
    case +value <> rest:collect_selected(primary(value),value,name,numbers,missing,ns => miss => collect_metric(name,rest,ns,miss))

def emit_summary(+name:String,pair:List<&2,Nat> & Nat) -> IO(Unit):
  (values,missing) = pair
  IO.print("{\"schema\":1,\"kind\":\"summary\",\"metric\":" ++ Out.quote(name) ++ ",\"statistics\":" ++ Out.summary(values,missing) ++ "}")

def summarize(names:List<&2,String>,+samples:List<&2,Sample>) -> IO(Unit):
  match names:
    case []:IO.pure(Unit,Unit{})
    case +name <> rest:
      do IO<Unit>:
        emit_summary(name,collect_metric(name,samples,[],0n))
        summarize(rest,samples)

def metric_names() -> List<&2,String>:
  ["simulation","observation","extraction","target_upkeep","view_preflight","acquire_call","acquire_wait_and_reset","record","submit","render_wait","query_read_and_conversion","render_fence_reset","command_reset","present_call","present_wait_and_reset","retirement","render_call_wall","poll","loop_service_before_buffer","evidence_checks_digest_initial_buffer","loop_through_initial_buffer","gpu_interval_truncated_ns"]

def assert_clean(live:U32) -> Result<&1,&1,U32 & String,Unit>:
  match live:
    case 0:Done{Unit{}}
    case _:Fail{(1,"Baseline leaked Vulkan objects")}

def counters_valid(c:Count.Counters,startup:Count.Counters) -> Bool:
  Count.Counters{w,W.U64{wb,wh},p,W.U64{pb,ph},d,s} = c
  Count.Counters{sw,W.U64{sb,sh},sp,spb,sd,ss} = startup
  U32.is_zero(w) && U32.is_zero(wb) && U32.is_zero(wh) && U32.is_eq(p,100) && U32.is_eq(pb,6400) && U32.is_zero(ph) && U32.is_eq(d,100) && U32.is_eq(s,1) && U32.is_eq(sw,2) && U32.is_eq(sb,720) && U32.is_zero(sh)

def probe_valid(probe:D.Probe,+attempt:U32) -> Bool:
  match probe:
    case D.On{owner,props,active,+generation,startup,counters,spans,D.Completed{outcome,suboptimal},D.Gpu{gpu_generation,raw,bound,duration}}:
      U32.is_eq(generation,U32.inc(attempt)) && U32.is_eq(generation,gpu_generation) && counters_valid(counters,startup)
    case D.On{owner,props,active,generation,startup,counters,spans,D.Skipped{reason},gpu}:True{}
    case _:False{}

def verify_samples(samples:List<&2,Sample>) -> IO(Unit):
  match samples:
    case []:IO.pure(Unit,Unit{})
    case Sample{+attempt,phase,tick,draw_tick,digest,retained,width,height,probe,spans,steps,dropped} <> rest:
      do IO<Unit>:
        Check.require(probe_valid(probe,attempt),"Baseline actual counters or query generation violated")
        verify_samples(rest)

def device_record(props:V.PhysicalDeviceProperties,g:U32,p:U32) -> String:
  V.PhysicalDeviceProperties{name,api,driver,vendor,id,kind} = props
  "{\"kind\":\"device\",\"name\":" ++ Out.quote(name) ++ ",\"api_version\":" ++ U32.show(api) ++ ",\"driver_version\":" ++ U32.show(driver) ++ ",\"vendor_id\":" ++ U32.show(vendor) ++ ",\"device_id\":" ++ U32.show(id) ++ ",\"device_type\":" ++ U32.show(kind) ++ ",\"graphics_family\":" ++ U32.show(g) ++ ",\"present_family\":" ++ U32.show(p) ++ "}"

def startup_summary(value:D.Metric<&2,W.U64>) -> IO(Unit):
  match value:
    case D.Available{ns}:emit_summary("startup_through_first_completed_frame",([Out.nat(ns)],0n))
    case D.Unavailable{reason}:emit_summary("startup_through_first_completed_frame",([],1n))

def emitted(result:V.VkResult(Evidence),+live:U32) -> IO(Unit):
  match result:
    case Fail{(code,+message)}:
      do IO<Unit>:
        IO.print("{\"schema\":1,\"kind\":\"terminal\",\"status\":\"invalid\",\"partial_counters\":null,\"reason\":" ++ Out.quote(message) ++ ",\"live_after_cleanup\":" ++ U32.show(live) ++ "}")
        IO.die(Unit,code,message)
    case Done{Evidence{+samples,+startup,attempts,accepted,ticks,before,device,graphics,present}}:
      do IO<Unit>:
        verify_samples(samples)
        IO.print(device_record(device,graphics,present))
        startup_summary(startup)
        emit(samples)
        summarize(metric_names(),samples)
        IO.print("{\"schema\":1,\"kind\":\"terminal\",\"status\":\"complete\",\"attempts\":" ++ U32.show(attempts) ++ ",\"completed_presentations\":" ++ U32.show(accepted) ++ ",\"steady_actual_ticks\":" ++ U32.show(ticks) ++ ",\"startup_through_first_completed_frame_ns\":" ++ Out.ns(startup) ++ ",\"live_before_close\":" ++ U32.show(before) ++ ",\"live_after_cleanup\":" ++ U32.show(live) ++ "}")
        IO.pass(Unit,assert_clean(live))

def finished(pair:V.VkResult(Evidence) & U32) -> IO(Unit):
  (result,live) = pair
  emitted(result,live)

def replay_mode(result:Result<&1,&1,U32 & String,String>) -> Bool:
  match result:
    case Done{"replay"}:True{}
    case _:False{}

def main() -> IO(Unit):
  do IO<Unit>:
    environment:Result<&1,&1,U32 & String,String> <- IO.get_env("ENTANGLE_WINDOW_MODE")
    +replay:Bool = replay_mode(environment)
    workers:U32 <- IO.thread_count()
    IO.print("{\"schema\":1,\"kind\":\"config\",\"mode\":" ++ Out.quote(Bool.pick(String,replay,"replay","live")) ++ ",\"workers\":" ++ U32.show(workers) ++ ",\"warmup_completed\":30,\"minimum_steady_completed\":120,\"minimum_live_steady_ticks\":8,\"max_attempts\":3000,\"deadline_ms\":60000,\"frame_slots\":1,\"present_mode\":\"FIFO\",\"initial_camera\":\"Camera.initial\",\"extent\":[640,480]}")
    scoped:V.VkResult(Evidence) & U32 <- Scope.with(Evidence,entry => run(entry,replay))
    finished(scoped)

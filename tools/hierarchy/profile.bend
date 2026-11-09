import Base
import ./benchmark.bend as B
import ./check.bend as Check
import ./scenes.bend as Scenes
import ../../src/scene-runtime.bend as Scene
import ../../src/scene.bend as Factory
import ../../src/scene-hierarchy.bend as HW
import ../../src/hierarchy.bend as H
import ../../src/scene-schema.bend as D
import ../../src/creation.bend as Create
import ../../deps/bendvy/src/ecs/world.bend as W
import ../../deps/bend-vulkan/deps/bend-collections/src/math/u64.bend as U
import ../verify-creation.bend as Consumer

def report(label:String,start:U.U64,end:U.U64) -> IO(Unit):
  IO.print("profile " ++ label ++ " ms=" ++ F32.show(B.milliseconds(U.add(end,U.neg(start)))))

def committed(world:D.World(),start:U.U64) -> IO(D.World()):
  do IO<D.World()>:
    end:U.U64 <- B.time()
    report("commit",start,end)
    return world

def derived(world:D.World(),rows:List<&2,HW.Row>,result:Result<&2,&2,H.Error,List<&2,H.Spatial>>,start:U.U64) -> IO(D.World()):
  match result:
    case Fail{_}:IO.die(D.World(),1,"Profile derivation rejected")
    case Done{values}:
      do IO<D.World()>:
        end:U.U64 <- B.time()
        report("derive",start,end)
        start:U.U64 <- B.time()
        committed(HW.commit(world,rows,values),start)

def read(result:D.World() & Result<&2,&2,H.Error,List<&2,HW.Row>>,edit:HW.Edit,start:U.U64) -> IO(D.World()):
  match result:
    case (world,Fail{_}):IO.die(D.World(),1,"Profile read rejected")
    case (world,Done{+rows}):
      do IO<D.World()>:
        end:U.U64 <- B.time()
        report("read",start,end)
        start:U.U64 <- B.time()
        derived(world,rows,Result.bind(&2,&2,H.Error,List<&2,H.Local>,List<&2,H.Spatial>,HW.candidate(edit,rows),xs => H.evaluate(xs)),start)

def profile(app:Scene.Application(),edit:HW.Edit) -> IO(Scene.Application()):
  Scene.Application{world,schedule} = app
  do IO<Scene.Application()>:
    start:U.U64 <- B.time()
    world:D.World() <- read(HW.read(world),edit,start)
    return Scene.Application{world,schedule}

def measured(pair:Scene.Application() & List<&2,HW.Row>) -> IO(Unit):
  (app,rows) = pair
  do IO<Unit>:
    root:W.Handle<D.Schema> <- Check.entity(Check.at(rows,0n))
    app:Scene.Application() <- profile(app,HW.SetTransform{root,Scenes.pose(0.5,0.125,0.0,Scenes.rotation(),Scenes.unit())})
    app:Scene.Application() <- B.verified(app,0,1000,0.5)
    return Unit{}

def start(compiled:Create.Compiled) -> IO(Unit):
  Create.Compiled{seeds,_} = compiled
  do IO<Unit>:
    app:Scene.Application() <- Factory.create(seeds)
    app:Scene.Application() <- Scene.tick(app)
    pair:Scene.Application() & List<&2,HW.Row> <- Check.capture(app)
    measured(pair)

def main() -> IO(Unit):
  do IO<Unit>:
    compiled:Create.Compiled <- Consumer.compiled(Create.compile(Create.Scene{B.instances(1000n,0,0)}))
    start(compiled)

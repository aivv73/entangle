import Base
import ./scene-observe.bend as Observe
import ./scene-runtime.bend as Scene
import ./scene-schema.bend as D
import ./scene-hierarchy.bend as Hierarchy
import ./hierarchy.bend as H
import ./scene-draw.bend as Draw
import ../deps/bendvy/src/ecs/inspector.bend as I

def snapshot(app:Scene.Application(),instance:I.Instance<D.Schema>) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Observe.Snapshot>):
  Observe.snapshot(app,instance)
def draw_list(app:Scene.Application(),instance:I.Instance<D.Schema>) -> Scene.Application() & (I.Instance<D.Schema> & Result<&2,&2,Unit,Draw.DrawList>):
  Observe.draw_list(app,instance)
def spatial(app:Scene.Application()) -> Scene.Application() & Result<&2,&2,H.Error,List<&2,Hierarchy.Row>>:
  Observe.spatial(app)

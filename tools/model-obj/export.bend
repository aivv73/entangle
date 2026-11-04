import Base
import ../image-decoder/common.bend as C

# Blender exposes its authoring/export API through Python, not a Bend effect.
def main() -> IO(Unit):
  do IO<Unit>:
    output:String <- C.command("blender",["--background","--factory-startup","--python-expr","import bpy\nbpy.data.objects.remove(bpy.data.objects.get('Cube'),do_unlink=True)\nm=bpy.data.meshes.new('wedge')\nm.from_pydata([(-1,-1,0),(1,-1,0),(1,1,0),(-1,1,0),(-1,-1,1),(1,-1,2)],[],[(0,2,1),(0,3,2),(0,1,5),(0,5,4),(1,2,5),(2,3,4),(2,4,5),(3,0,4)])\no=bpy.data.objects.new('wedge',m)\nbpy.context.collection.objects.link(o)\nbpy.ops.object.select_all(action='DESELECT')\no.select_set(True)\nbpy.context.view_layer.objects.active=o\nbpy.ops.wm.obj_export(filepath=bpy.path.abspath('//docs/verification/2026-11-04-model-obj/corpus/wedge.obj'),export_selected_objects=True,export_triangulated_mesh=True,export_uv=False,export_normals=False,export_materials=False,forward_axis='Y',up_axis='Z')"])
    IO.write(output)

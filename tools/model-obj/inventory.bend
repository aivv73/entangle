import Base
import ../image-decoder/common.bend as C

def sources() -> List<String>:
  ["src/model-obj.bend","src/content.bend","src/components.bend","src/asset.bend","deps/jonlib-obj/obj.bend","deps/jonlib-obj/binary64_fma.bend","deps/jonlib-obj/binary64_add_sub.bend","deps/jonlib-obj/binary64_ops.bend","deps/jonlib-obj/binary64_narrow.bend","deps/jonlib-obj/resize_numeric.bend","deps/jonlib-obj/float64.bend","deps/jonlib-obj/float64_ops.bend"]

def copy(dest:String,files:List<String>) -> IO(Unit):
  do IO<Unit>:
    _:String <- C.command("cp",List.append(&1,String,["--parents"],List.append(&1,String,files,[dest])))
    return Unit{}

def main() -> IO(Unit):
  do IO<Unit>:
    +dest:String <- C.command("mktemp",["-d","build/model-obj/source-only-XXXXXXXX"])
    +dest:String = String.trim(dest)
    copy(dest,List.append(&1,String,sources(),["tools/model-obj/consumer.bend"]))
    _:String <- C.command("bend",[dest ++ "/tools/model-obj/consumer.bend","-o",dest ++ "/consumer"])
    output:String <- C.command(dest ++ "/consumer",["+RTS","--threads","1","--gpu","off"])
    IO.write(output)
    inventory:String <- C.command("rg",["--files",dest])
    IO.print(inventory)
    IO.print("Source-only inventory compiled and ran with only Base, Content, Components, Asset, OBJ adapter and eight pinned parser modules.")

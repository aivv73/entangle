import Base
import ./replace.bend as Replace
import ./common.bend as C

# Mutate isolated production sources, then require the real pixel verifier to fail.
def text_closed(pair:File & Result<&1,&1,U32 & String,String>) -> IO(String):
  (file,value) = pair
  do IO<String>:
    File.close(file)
    IO.try(String,IO.pure(Result<&1,&1,U32 & String,String>,value))

def replace(+path:String,+before:String,after:String) -> IO(Unit):
  do IO<Unit>:
    file:File <- IO.try(File,File.open(path,"r"))
    pair:File & Result<&1,&1,U32 & String,String> <- File.read(file,1048576)
    +text:String <- text_closed(pair)
    C.require(String.contains(text,before),"Mutation target missing " ++ path)
    file:File <- IO.try(File,File.open(path,"w"))
    pair:File & Result<&1,&1,U32 & String,Unit> <- File.write(file,Replace.all(text,before,after))
    C.written(pair)

def failed(+name:String,+expected:String,value:U32 & (String & String)) -> IO(Unit):
  (+code,pair) = value
  (out,err) = pair
  +text:String = out ++ err
  do IO<Unit>:
    C.require(U32.is_ne(code,0) && String.contains(text,expected),name ++ " mutation escaped or failed for another reason " ++ text)
    IO.print(name ++ " detected by native verifier status=" ++ U32.show(code) ++ " message=" ++ expected)

def mutation(+name:String,source:String,before:String,after:String,expected:String) -> IO(Unit):
  do IO<Unit>:
    +dest:String = "build/image-mutations/" ++ name
    _:String <- C.command("mkdir",["-p",dest])
    _:String <- C.command("cp",["--parents","src/content.bend","src/components.bend","src/asset.bend","src/image-png.bend","deps/jonlib-png/png.bend","deps/jonlib-png/codec.bend","deps/jonlib-png/inflate.bend","tools/image-decoder/common.bend","tools/image-decoder/corpus.bend","tools/image-decoder/probes.bend","tools/image-decoder/runtime.bend",dest])
    replace(dest ++ "/" ++ source,before,after)
    _:String <- C.command("bend",[dest ++ "/tools/image-decoder/runtime.bend","-o",dest ++ "/runtime"])
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(dest ++ "/runtime",["+RTS","--threads","1","--gpu","off"],"",1048576,60000))
    failed(name,expected,result)

def main() -> IO(Unit):
  do IO<Unit>:
    mutation("order","src/image-png.bend","array_words(left,array_words(right,tail))","array_words(right,array_words(left,tail))","pixels differ")
    mutation("packing","src/image-png.bend","ALeaf{value}:value <> tail","ALeaf{+value}:((value << 8n) .|. (value >> 24n) : U32) <> tail","pixels differ")
    mutation("input-limit","src/image-png.bend","2097152","1048576","input-at-limit file failed")
    mutation("side-limit","deps/jonlib-png/png.bend","decode.checked(4096, bytes","decode.checked(4095, bytes","width4096 decode failed")
    IO.print("Wrong order, packing, encoded limit and side limit were each rejected by actual runtime evidence.")

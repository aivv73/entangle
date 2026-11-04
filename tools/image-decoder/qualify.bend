import Base
import ./common.bend as C
import ./compare.bend as Compare
import ./corpus.bend as Corpus
import ./probes.bend as Probes

def main() -> IO(Unit):
  do IO<Unit>:
    +home:String <- IO.try(String,IO.get_env("HOME"))
    +pin:String <- C.command("cat",[home ++ "/.bend/lib/names/emerging-ezimg@1.3.0.0"])
    C.require(String.eq(String.trim(pin),"0x57618559b9b26dd8415f821176a3e692"),"Ezimg version resolved to another source pin")
    +text:String <- C.command("bend",["tools/image-decoder/ezimg-probe.bend","-o","build/image-comparison/ezimg-probe"])
    IO.write(text)
    +text:String <- C.command("bend",["tools/image-decoder/jonlib-probe.bend","-o","build/image-comparison/jonlib-probe"])
    IO.write(text)
    Compare.cases(List.append(&2,Corpus.Case,Corpus.cases(),Probes.cases()))

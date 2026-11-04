import Base
import ./common.bend as C
import ./corpus.bend as Corpus
import ./probes.bend as Probes

def result(+label:String,value:Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Unit):
  match value:
    case Fail{(+code,message)}:IO.print(label ++ Bool.pick(String,U32.is_eq(code,110)," timeout "," process-failure ") ++ U32.show(code) ++ " " ++ message)
    case Done{(code,pair)}:
      (out,err) = pair
      +out:String = out
      +code:U32 = code
      do IO<Unit>:
        IO.print(label ++ " exit=" ++ U32.show(code) ++ " " ++ String.trim(out) ++ " " ++ String.trim(err))
        C.require(Bool.not(String.contains(out,"MISMATCH")),label ++ " returned incorrect pixels")

def probe(+codec:String,+name:String,width:U32,height:U32) -> IO(Unit):
  do IO<Unit>:
    value:Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("prlimit",["--as=25769803776","--cpu=30","--", "build/image-comparison/" ++ codec ++ "-probe",Corpus.output() ++ "/" ++ name ++ ".png",Corpus.output() ++ "/" ++ name ++ ".rgba",U32.show(width),U32.show(height),"+RTS","--threads","1","--gpu","off"],"",65536,45000)
    result(name ++ " " ++ codec,value)

def cases(items:List<&2,Corpus.Case>) -> IO(Unit):
  match items:
    case []:IO.pure(Unit,Unit{})
    case Corpus.Case{+name,+w,+h,_} <> rest:
      do IO<Unit>:
        probe("jonlib",name,w,h)
        probe("ezimg",name,w,h)
        cases(rest)

def main() -> IO(Unit):
  cases(List.append(&2,Corpus.Case,Corpus.cases(),Probes.cases()))

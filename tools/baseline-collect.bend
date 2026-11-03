import Base
import ../src/baseline-output.bend as Out
import ../examples/scene-window-baseline.bend as B

type Repeat is Data:Repeat{mode:String,repeat:U32,output:String}

def require(ok:Bool,message:String) -> IO(Unit):
  match ok:
    case True{}:IO.pure(Unit,Unit{})
    case False{}:IO.die(Unit,1,message)

def close_written(pair:File & Result<&1,&1,U32 & String,Unit>) -> IO(Unit):
  (file,result) = pair
  do IO<Unit>:
    File.close(file)
    IO.pass(Unit,result)

def write_file(path:String,contents:String) -> IO(Unit):
  do IO<Unit>:
    file:File <- IO.try(File,File.open(path,"w"))
    written:File & Result<&1,&1,U32 & String,Unit> <- File.write(file,contents)
    close_written(written)

def captured(pair:U32 & (String & String),+mode:String,+repeat:U32) -> IO(Repeat):
  (+status,strings) = pair
  (out,err) = strings
  +out:String = out
  +err:String = err
  +path = "docs/verification/2026-11-03-baseline/" ++ mode ++ "-" ++ U32.show(repeat)
  do IO<Repeat>:
    write_file(path ++ ".jsonl",out)
    write_file(path ++ ".stderr",err)
    write_file(path ++ ".status",U32.show(status) ++ "\n")
    require(U32.is_zero(status),"Baseline repeat failed; archived without replacement " ++ path ++ " status=" ++ U32.show(status))
    require(String.contains(out,"\"status\":\"complete\"") && String.contains(out,"\"live_after_cleanup\":0"),"Incomplete baseline repeat " ++ path)
    require(String.is_empty(err),"Baseline stderr is not empty " ++ path)
    IO.print("collected " ++ mode ++ " " ++ U32.show(repeat))
    return Repeat{mode,repeat,out}

def run(+mode:String,+repeat:U32) -> IO(Repeat):
  do IO<Repeat>:
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("env",["ENTANGLE_WINDOW_MODE=" ++ mode,"timeout","--signal=TERM","--kill-after=5s","70s","./build/scene-window-baseline","+RTS","--threads","1","--gpu","off"],"",16777216,80000))
    captured(result,mode,repeat)

def repeats(fuel:Nat,+repeat:U32,acc:List<&2,Repeat>) -> IO(List<&2,Repeat>):
  match fuel:
    case 0n:IO.pure(List<&2,Repeat>,List.reverse(&2,Repeat,acc))
    case 1n+rest:
      do IO<List<&2,Repeat>>:
        live:Repeat <- run("live",repeat)
        replay:Repeat <- run("replay",repeat)
        repeats(rest,U32.inc(repeat),replay <> live <> acc)

def half_parts(parts:List<&2,String>) -> Maybe<&2,Nat>:
  match parts:
    case whole <> []:
      do Maybe<&2,Nat>:
        n:Nat <- Nat.read(whole)
        return Nat.mul(n,2n)
    case whole <> "5" <> []:
      do Maybe<&2,Nat>:
        n:Nat <- Nat.read(whole)
        return Nat.add(Nat.mul(n,2n),1n)
    case _:None{}

def number_half(value:String) -> Maybe<&2,Nat>:
  half_parts(String.split(value,'.'))

def median_found(found:Bool,field:String,next:Unit -> Maybe<&2,Nat>) -> Maybe<&2,Nat>:
  match found:
    case True{}:number_half(String.drop(field,12n))
    case False{}:next(Unit{})

def median_field(fields:List<&2,String>) -> Maybe<&2,Nat>:
  match fields:
    case []:None{}
    case +field <> rest:median_found(String.starts_with(field,"\"median_ns\":"),field,_ => median_field(rest))

def line_found(found:Bool,line:String,next:Unit -> Maybe<&2,Nat>) -> Maybe<&2,Nat>:
  match found:
    case True{}:median_field(String.split(line,','))
    case False{}:next(Unit{})

def median_line(lines:List<&2,String>,+metric:String) -> Maybe<&2,Nat>:
  match lines:
    case []:None{}
    case +line <> rest:line_found(String.contains(line,"\"kind\":\"summary\"") && String.contains(line,"\"metric\":" ++ Out.quote(metric)),line,_ => median_line(rest,metric))

def collect_median(value:Maybe<&2,Nat>,numbers:List<&2,Nat>,next:List<&2,Nat> -> List<&2,Nat>) -> List<&2,Nat>:
  match value:
    case None{}:next(numbers)
    case Some{n}:next(Out.insert(n,numbers))

def collect_mode(selected:Bool,output:String,metric:String,numbers:List<&2,Nat>,next:List<&2,Nat> -> List<&2,Nat>) -> List<&2,Nat>:
  match selected:
    case False{}:next(numbers)
    case True{}:collect_median(median_line(String.lines(output),metric),numbers,next)

def collect(values:List<&2,Repeat>,+mode:String,+metric:String,numbers:List<&2,Nat>) -> List<&2,Nat>:
  match values:
    case []:numbers
    case Repeat{selected,repeat,output} <> rest:collect_mode(String.eq(mode,selected),output,metric,numbers,ns => collect(rest,mode,metric,ns))

def range_values(+count:Nat,+numbers:List<&2,Nat>) -> String:
  match count:
    case 0n:",\"median_ns\":null"
    case _:",\"median_ns\":" ++ Out.half(Out.nth(numbers,Nat.div(count,2n))) ++ ",\"min_ns\":" ++ Out.half(Out.nth(numbers,0n)) ++ ",\"max_ns\":" ++ Out.half(Out.nth(numbers,Nat.sub(count,1n)))

def range(mode:String,metric:String,+numbers:List<&2,Nat>) -> String:
  +count = List.length(&2,Nat,numbers)
  "{\"kind\":\"repeat_median_range\",\"mode\":" ++ Out.quote(mode) ++ ",\"metric\":" ++ Out.quote(metric) ++ ",\"count\":" ++ Nat.show(count) ++ range_values(count,numbers) ++ "}\n"

def ranges(names:List<&2,String>,+mode:String,+values:List<&2,Repeat>) -> String:
  match names:
    case []:""
    case +name <> rest:range(mode,name,collect(values,mode,name,[])) ++ ranges(rest,mode,values)

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<&2,Repeat> <- repeats(5n,1,[])
    +values:List<&2,Repeat> = values
    write_file("docs/verification/2026-11-03-baseline/repeat-ranges.jsonl",ranges("startup_through_first_completed_frame" <> B.metric_names(),"live",values) ++ ranges("startup_through_first_completed_frame" <> B.metric_names(),"replay",values))
    IO.print("Five fresh alternating live/replay repeats archived.")

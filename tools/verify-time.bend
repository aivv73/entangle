import Base
import ../src/time.bend as Time

def same(clock:Time.Clock,batch:Time.Batch) -> Bool:
  Time.Clock{sample,remainder} = clock
  Time.Batch{Time.Clock{other,carry},steps,dropped} = batch
  Nat.is_eq(sample,other) && Nat.is_eq(remainder,carry) && Nat.is_eq(steps,0n) && Nat.is_eq(dropped,0n)

def property(+config:Time.Config,old:Time.Clock,+now:Nat,+batch:Time.Batch) -> Bool:
  Time.Clock{+sample,+remainder} = old
  Time.Batch{Time.Clock{+next,+carry},+steps,+dropped} = batch
  +clock:Time.Clock = Time.Clock{next,carry}
  Nat.is_le(steps,Time.limit(config)) &&
    Bool.pick(Bool,Nat.is_gt(dropped,0n),Nat.is_eq(steps,Time.limit(config)),True{}) &&
    Nat.is_lt(carry,Time.interval(config)) &&
    Nat.is_eq(Nat.add(Nat.mul(Nat.add(steps,dropped),Time.interval(config)),carry),Nat.add(remainder,Nat.sub(now,sample))) &&
    Nat.is_eq(next,Nat.max(sample,now)) &&
    same(clock,Time.poll(config,clock,now)) &&
    Bool.pick(Bool,Nat.is_le(now,sample),same(Time.Clock{sample,remainder},batch),True{})

def samples(remaining:Nat,+config:Time.Config,+old:Time.Clock,+now:Nat) -> Bool:
  match remaining:
    case 0n:True{}
    case 1n+rest:property(config,old,now,Time.poll(config,old,now)) && samples(rest,config,old,1n+now)

def remainders(remaining:Nat,+config:Time.Config,+sample:Nat,+range:Nat) -> Bool:
  match remaining:
    case 0n:True{}
    case 1n++rest:samples(range,config,Time.Clock{sample,rest},0n) && remainders(rest,config,sample,range)

def limits(remaining:Nat,+interval:Nat) -> Bool:
  match remaining:
    case 0n:True{}
    case 1n++rest:remainders(1n+interval,Time.Config{interval,rest},32n,129n) && limits(rest,interval)

def intervals(remaining:Nat) -> Bool:
  match remaining:
    case 0n:True{}
    case 1n++rest:limits(4n,rest) && intervals(rest)

def require(ok:Bool) -> IO(Unit):
  match ok:
    case True{}:IO.print("Fixed-step accounting, cap, remainder, duplicate and regressing samples verified across 768826 configurations and clock samples.")
    case False{}:IO.die(Unit,1,"Fixed-step runtime property violated")

def main() -> IO(Unit):
  require(intervals(8n) && remainders(250n,Time.defaults(),1000n,3001n))

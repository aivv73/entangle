import Base

type Config is Data:
  Config{interval_tail:Nat,limit_tail:Nat}

type Clock is Data:
  Clock{sample:Nat,remainder:Nat}

type Batch is Data:
  Batch{clock:Clock,steps:Nat,dropped:Nat}

def defaults() -> Config:
  Config{249n,3n}

def interval(config:Config) -> Nat:
  Config{tail,_} = config
  1n+tail

def limit(config:Config) -> Nat:
  Config{_,tail} = config
  1n+tail

def start(now:Nat) -> Clock:
  Clock{now,0n}

def clock(batch:Batch) -> Clock:
  Batch{clock,_,_} = batch
  clock

def steps(batch:Batch) -> Nat:
  Batch{_,steps,_} = batch
  steps

def total(batch:Batch) -> Nat:
  Batch{_,steps,dropped} = batch
  Nat.add(steps,dropped)

def remainder(batch:Batch) -> Nat:
  Batch{Clock{_,remainder},_,_} = batch
  remainder

def covered(config:Config,+batch:Batch) -> Nat:
  Nat.add(Nat.mul(total(batch),interval(config)),remainder(batch))

def partition(+limit:Nat,+whole:Nat,remainder:Nat,sample:Nat) -> Batch:
  +steps = Nat.min(whole,limit)
  Batch{Clock{sample,remainder},steps,Nat.sub(whole,steps)}

def accumulated(+config:Config,+sample:Nat,+elapsed:Nat) -> Batch:
  +dt = interval(config)
  partition(limit(config),Nat.div(elapsed,dt),Nat.mod(elapsed,dt),sample)

def poll(config:Config,clock:Clock,+now:Nat) -> Batch:
  Clock{+sample,remainder} = clock
  accumulated(config,Nat.max(sample,now),Nat.add(remainder,Nat.sub(now,sample)))

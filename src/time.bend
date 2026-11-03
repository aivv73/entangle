import Base

def ready(now:Nat,due:Nat) -> Bool:
  Nat.is_ge(now,due)

def next_due(now:Nat,interval:Nat) -> Nat:
  Nat.add(now,interval)

import Base

def advance(~A:Type,~tick:A -> IO(A),remaining:Nat,state:A) -> IO(A):
  match remaining:
    case 0n:IO.pure(A,state)
    case 1n+rest:
      do IO<A>:
        next : A <- tick(state)
        advance(~A,~tick,rest,next)

import Base

def select(-A:Data,old:A,fresh:A,sealed:Bool) -> A:
  match sealed:
    case False{}:old
    case True{}:fresh

def allocations(-A:Type,pair:Maybe<(A & A)>) -> List<A>:
  match pair:
    case None{}:[]
    case Some{(vertices,indices)}:[vertices,indices]

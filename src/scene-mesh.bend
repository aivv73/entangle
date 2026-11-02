import Base

def indices_valid(indices:List<&2,U32>,+count:U32) -> Bool:
  match indices:
    case []:True{}
    case i <> rest:U32.is_lt(i,count) && indices_valid(rest,count)

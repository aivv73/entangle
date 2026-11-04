import Base

# A reusable witness permits induction without copying an affine Array.
type Tree is Data:
  Leaf{value:U32}
  Node{left:Tree,right:Tree}

def array(tree:Tree) -> Array<U32>:
  match tree:
    case Leaf{x}:ALeaf{x}
    case Node{left,right}:ANode{array(left),array(right)}

def count(tree:Tree) -> Nat:
  match tree:
    case Leaf{_}:1n
    case Node{left,right}:Nat.add(count(left),count(right))

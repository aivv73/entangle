import Base
import ./scan.bend as S

def paths(xs:List<&2,String>) -> List<&2,String>:
  match xs:
    case []:[]
    case x <> rest:String.drop(x,2n) <> paths(rest)

def files() -> IO(List<&2,String>):
  do IO<List<&2,String>>:
    text:String <- S.run("find",[".","-path","./.git","-prune","-o","-path","./deps","-prune","-o","-path","./build","-prune","-o","-path","./docs","-prune","-o","-type","f","-name","*.bend","-print"])
    return paths(String.lines(String.trim(text)))

def refs(xs:List<&2,String>,+alias:String,+path:String) -> IO(Unit):
  match xs:
    case []:IO.pure(Unit,Unit{})
    case +x <> rest:
      do IO<Unit>:
        IO.write(Bool.pick(String,String.starts_with(x,alias ++ "."),path ++ " " ++ String.drop(x,1n+String.length(alias)) ++ "\n",""))
        refs(rest,alias,path)

def dependency(+path:String,+alias:String,tokens:List<&2,String>) -> IO(Unit):
  do IO<Unit>:
    IO.print("module " ++ path)
    refs(tokens,alias,path)

def imports(xs:List<&2,S.Import>,+file:String,+tokens:List<&2,String>) -> IO(Unit):
  match xs:
    case []:IO.pure(Unit,Unit{})
    case S.Import{+alias,+path} <> rest:
      do IO<Unit>:
        +target:String <- Bool.pick(IO(String),String.starts_with(path,"./") || String.starts_with(path,"../"),S.resolve(path,file),IO.pure(String,path))
        IO.write(Bool.pick(String,String.contains(path,"@"),"package " ++ path ++ "\n",""))
        Bool.pick(IO(Unit),String.starts_with(target,"deps/") || String.contains(path,"@"),dependency(target,alias,tokens),IO.pure(Unit,Unit{}))
        imports(rest,file,tokens)

def inventory(xs:List<&2,String>) -> IO(Unit):
  match xs:
    case []:IO.pure(Unit,Unit{})
    case +file <> rest:
      do IO<Unit>:
        text:String <- S.read(file)
        +tokens:List<&2,String> = S.lex(text)
        imports(S.imports(tokens),file,tokens)
        inventory(rest)

def main() -> IO(Unit):
  do IO<Unit>:
    paths:List<&2,String> <- files()
    inventory(paths)

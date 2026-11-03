import Base

type Import is Data:
  Import{alias:String,path:String}

def has(+xs:List<&2,String>,+s:String) -> Bool:
  match xs:
    case []:False{}
    case x <> rest:Bool.or(String.eq(x,s),has(rest,s))

def word(+c:Char) -> Bool:
  Chr{+n} = c
  Bool.or(Bool.and(U32.is_ge(n,48),U32.is_le(n,57)),Bool.or(Bool.and(U32.is_ge(n,65),U32.is_le(n,90)),Bool.or(Bool.and(U32.is_ge(n,97),U32.is_le(n,122)),has(["_",".","/","-","@"],SCon{c,SNil{}}))))

def push(s:String,rest:List<&2,String>) -> List<&2,String>:
  match s:
    case SNil{}:rest
    case _:String.reverse(s) <> rest

def emit(c:Char,rest:List<&2,String>) -> List<&2,String>:
  match c:
    case ' ':rest
    case '\n':rest
    case '\r':rest
    case '\t':rest
    case _:SCon{c,SNil{}} <> rest

type Lex is Data:
  Lex{state:U32,acc:String,tokens:List<&2,String>}

def step_word(c:Char,acc:String,tokens:List<&2,String>,is_word:Bool) -> Lex:
  match is_word:
    case True{}:Lex{0,SCon{c,acc},tokens}
    case False{}:Lex{0,"",emit(c,push(acc,tokens))}

def step(value:Lex,c:Char) -> Lex:
  Lex{state,acc,tokens} = value
  match state c:
    case 0 '#':Lex{1,"",push(acc,tokens)}
    case 0 '"':Lex{2,"","quoted" <> push(acc,tokens)}
    case 0 '\'':Lex{3,"","quoted" <> push(acc,tokens)}
    case 0 +c:step_word(c,acc,tokens,word(c))
    case 1 '\n':Lex{0,acc,tokens}
    case 1 _:Lex{1,acc,tokens}
    case 2 '\\':Lex{4,acc,tokens}
    case 2 '"':Lex{0,acc,tokens}
    case 2 _:Lex{2,acc,tokens}
    case 3 '\\':Lex{5,acc,tokens}
    case 3 '\'':Lex{0,acc,tokens}
    case 3 _:Lex{3,acc,tokens}
    case 4 _:Lex{2,acc,tokens}
    case _ _:Lex{3,acc,tokens}

def lex_end(value:Lex) -> List<&2,String>:
  Lex{+state,acc,+tokens} = value
  List.reverse(&2,String,Bool.pick(List<&2,String>,U32.is_le(state,1),push(acc,tokens),"unterminated-literal" <> tokens))

def lex_go(s:String,value:Lex) -> List<&2,String>:
  match s:
    case SNil{}:lex_end(value)
    case SCon{c,t}:lex_go(t,step(value,c))

def lex(s:String) -> List<&2,String>:
  lex_go(s,Lex{0,"",[]})

def require(ok:Bool,message:String) -> IO(Unit):
  Bool.pick(IO(Unit),ok,IO.pure(Unit,Unit{}),IO.die(Unit,1,message))

def finished(label:String,result:U32 & (String & String)) -> IO(String):
  (status,(out,err)) = result
  do IO<String>:
    require(U32.is_zero(status),label ++ ": " ++ err)
    return out

def run(+program:String,args:List<String>) -> IO(String):
  do IO<String>:
    result:U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(program,args,"",16777216,300000))
    finished(program,result)

def read_done(path:String,+size:U32,pair:File & Result<&1,&1,U32 & String,String>) -> IO(String):
  (file,result) = pair
  do IO<String>:
    File.close(file)
    +text:String <- IO.try(String,IO.pure(Result<&1,&1,U32 & String,String>,result))
    require(Nat.is_eq(String.length(text),U32.to_nat(size)),path ++ ": short or non-ASCII source read")
    return text

def read_size(+path:String,pair:File & Result<&1,&1,U32 & String,U32>) -> IO(String):
  (file,result) = pair
  do IO<String>:
    +size:U32 <- IO.try(U32,IO.pure(Result<&1,&1,U32 & String,U32>,result))
    require(U32.is_lt(size,1048576),path ++ ": source exceeds scanner 1 MiB bound")
    pair:File & Result<&1,&1,U32 & String,String> <- File.read(file,U32.inc(size))
    read_done(path,size,pair)

def read(+path:String) -> IO(String):
  do IO<String>:
    file:File <- IO.try(File,File.open(path,"r"))
    pair:File & Result<&1,&1,U32 & String,U32> <- File.size(file)
    read_size(path,pair)

def next(tokens:List<&2,String>) -> String:
  match tokens:
    case []:""
    case x <> _:x

def import_tail(tokens:List<&2,String>) -> Import:
  match tokens:
    case +path <> +as_ <> alias <> _:
      Bool.pick(Import,String.eq(as_,"as"),Import{alias,path},Import{"invalid","invalid"})
    case _:Import{"invalid","invalid"}

def collect_import(x:String,+rest:List<&2,String>,+tail:List<&2,Import>) -> List<&2,Import>:
  Bool.pick(List<&2,Import>,String.eq(x,"import") && Bool.not(String.eq(next(rest),"Base")),import_tail(rest) <> tail,tail)

def imports(tokens:List<&2,String>) -> List<&2,Import>:
  match tokens:
    case x <> +rest:collect_import(x,rest,imports(rest))
    case []:[]

def base_dir(path:String) -> IO(String):
  do IO<String>:
    out:String <- run("dirname",[path])
    return String.trim(out)

def resolve(path:String,from:String) -> IO(String):
  do IO<String>:
    dir:String <- base_dir(from)
    out:String <- run("realpath",["-s","--relative-to=.","--",dir ++ "/" ++ path])
    return String.trim(out)

def canonical(imports:List<&2,Import>,+from:String,+files:List<&2,String>,+policy:List<&2,String>) -> IO(List<&2,Import>):
  match imports:
    case []:IO.pure(List<&2,Import>,[])
    case Import{+alias,+path} <> rest:
      do IO<List<&2,Import>>:
        require(String.starts_with(path,"./") || String.starts_with(path,"../") || has(policy,"package " ++ path),from ++ ": unapproved import " ++ path)
        +target:String <- Bool.pick(IO(String),has(policy,"package " ++ path),IO.pure(String,path),resolve(path,from))
        require(has(files,target) || has(policy,"module " ++ target),from ++ ": import outside scanned sources/reviewed dependencies " ++ target)
        tail:List<&2,Import> <- canonical(rest,from,files,policy)
        return Import{alias,target} <> tail

def public() -> List<&2,String>:
  ["Buffer","byte_length","capacity_for","capacity","handle","allocation","allocate","write","read","upload_new","retire","discard"]

def approved(applies:Bool,+name:String,+next:String,+previous:String,+alias:String,+path:String,+policy:List<&2,String>,+from:String) -> IO(Unit):
  match applies:
    case False{}:IO.pure(Unit,Unit{})
    case True{}:
      do IO<Unit>:
        +symbol:String = String.drop(name,1n+String.length(alias))
        require(Bool.not(String.eq(path,"src/scene-buffer.bend")) || (has(public(),symbol) && (Bool.not(String.eq(symbol,"Buffer")) || (has([":","<","(",">"],previous) && has([",",">",")","<","=","}",":"],next)))),from ++ ": forbidden buffer representation/helper " ++ name)
        require(Bool.not(has(policy,"module " ++ path)) || has(policy,path ++ " " ++ symbol),from ++ ": unapproved dependency symbol " ++ path ++ " " ++ symbol)

def reference(+name:String,+next:String,+previous:String,imports:List<&2,Import>,+policy:List<&2,String>,+from:String) -> IO(Unit):
  match imports:
    case []:IO.pure(Unit,Unit{})
    case Import{+alias,+path} <> rest:
      do IO<Unit>:
        approved(String.starts_with(name,alias ++ "."),name,next,previous,alias,path,policy,from)
        reference(name,next,previous,rest,policy,from)

def references(tokens:List<&2,String>,previous:String,+imports:List<&2,Import>,+policy:List<&2,String>,+from:String) -> IO(Unit):
  match tokens:
    case []:IO.pure(Unit,Unit{})
    case +x <> +rest:
      do IO<Unit>:
        require(Bool.not(String.ends_with(x,"write_memory") || String.ends_with(x,"write_memory_words") || String.eq(x,"unterminated-literal")),from ++ ": raw upload or unsupported literal " ++ x)
        reference(x,next(rest),previous,imports,policy,from)
        references(rest,x,imports,policy,from)

def scan(+from:String,+files:List<&2,String>,+policy:List<&2,String>) -> IO(Unit):
  do IO<Unit>:
    +text:String <- read(from)
    +tokens:List<&2,String> = lex(text)
    imports:List<&2,Import> <- canonical(imports(tokens),from,files,policy)
    references(tokens,"",imports,policy,from)

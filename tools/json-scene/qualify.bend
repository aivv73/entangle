import Base
import 0x37aacddc1dcb57464b8b5ac6c397bd64/json.bend as J
import 0x632652e3c1c0183f12728faf3870bb68/bytes.bend as B
import 0xdab377b48b4edd8247427c10e2120805/main.bend as Ez
import 0xdab377b48b4edd8247427c10e2120805/src/value.bend as EzValue
import ../image-decoder/common.bend as C

def accepted(value:Maybe<&1,J.Val>) -> Bool:
  match value:
    case None{}:False{}
    case Some{_}:True{}

def check(+s:String,+want:Bool,depth:U32) -> IO(Unit):
  do IO<Unit>:
    C.require(Bool.not(Bool.xor(accepted(J.parse.strict.unique.bytes(B.from_string(s),depth)),want)),"kit qualification mismatch " ++ s)
    IO.print("kit expected=" ++ Bool.show(want) ++ " input=" ++ s)

def number(v:Maybe<&1,J.Val>) -> Bool:
  match v:
    case Some{J.Num{s}}:String.eq(B.to_string(s),"9007199254740993")
    case _:False{}

def bytes_text(bs:List<&2,U32>) -> String:
  match bs:
    case []:""
    case b <> rest:SCon{Char.from_u32(b),bytes_text(rest)}

def main() -> IO(Unit):
  do IO<Unit>:
    raw:List<&2,U32> <- C.read("docs/verification/2026-11-04-json-scene/corpus/manifest.json")
    +text:String = bytes_text(raw)
    C.require(accepted(J.parse.strict.unique.bytes(B.from_string(text),8)),"kit real manifest rejected")
    C.require(Maybe.is_some(&2,EzValue.Json,Ez.parse(text)),"ezjson real manifest rejected")
    C.require(number(J.parse.strict.unique.bytes(B.from_string("9007199254740993"),8)),"exact numeric token lost")
    check("{\"x\":1,\"x\":2}",False{},8)
    check("{\"x\":1,\"\\u0078\":2}",False{},8)
    check("{\"nested\":{\"x\":1,\"x\":2}}",False{},8)
    check("[[]]",True{},2)
    check("[[]]",False{},1)
    check("\"\\ud800\"",False{},8)
    check("\"\\ud83d\\ude00\"",True{},8)
    check("01",False{},8)
    check("{} trailing",False{},8)
    IO.print("ezjson duplicate accepted=" ++ Bool.show(Maybe.is_some(&2,EzValue.Json,Ez.parse("{\"x\":1,\"x\":2}"))))
    IO.print("Selected bend-kit-json strict unique byte parser. Exact numbers, decoded-key uniqueness and pre-descent depth checks qualified.")

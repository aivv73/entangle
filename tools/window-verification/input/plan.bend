import Base

def key(+code: U32) -> List<Event>:
  [Key{code, True{}}, Key{code, False{}}]

def click(+x: U32, +y: U32) -> List<Event>:
  [Press{0,Tool.Mouse{},U32.to_f32(x),U32.to_f32(y),0,0,True{}}, Press{0,Tool.Mouse{},U32.to_f32(x),U32.to_f32(y),0,0,False{}}]

def request_close() -> List<Event>:
  [Close{}]


import Base

def bend_version() -> String: "bend 2.0.40"
def bend_revision() -> String: "624dd9f4607cd29b0871a9b96d413bfb11e92f52"
def bend_host_version() -> String: "1.4.4"
def clang_version() -> String: "clang version 23.1.4"
def native_target() -> String: "x86_64-pc-linux-gnu"

def dependencies() -> List<(String & String)>:
  [("deps/bendvy", "59833adc4dc007588d3b43158e0144abbdad45b4"),
   ("deps/bend-vulkan", "190023575c64915677ae02e4d5ef082b51c239e9"),
   ("deps/bend-vulkan/deps/bend-collections", "32526a9a3d82ffc988bf4a122f8c37240a70a87b")]

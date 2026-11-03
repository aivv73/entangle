import Base

def bend_version() -> String: "bend 2.0.39"
def clang_version() -> String: "clang version 23.1.4"
def native_target() -> String: "x86_64-pc-linux-gnu"

def dependencies() -> List<(String & String)>:
  [("deps/bendvy", "16405fbeb75cd6da1eb8c79ea48d3532ee9a30ee"),
   ("deps/bend-vulkan", "a144f7dd4fb4835ca3d5ce17350fc850de049038"),
   ("deps/bend-vulkan/deps/bend-collections", "bc78c4f4cabb536a2a1dd6e308b6a8f0afafda7c")]

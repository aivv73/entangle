import Base

def bend_version() -> String: "bend 2.0.40"
def bend_revision() -> String: "624dd9f4607cd29b0871a9b96d413bfb11e92f52"
def bend_host_version() -> String: "1.4.4"
def clang_version() -> String: "clang version 23.1.4"
def native_target() -> String: "x86_64-pc-linux-gnu"

def dependencies() -> List<(String & String)>:
  [("deps/bendvy", "16405fbeb75cd6da1eb8c79ea48d3532ee9a30ee"),
   ("deps/bend-vulkan", "979a8c2840dcdfd53f41cd70ebaed8de74ec8bed"),
   ("deps/bend-vulkan/deps/bend-collections", "bc78c4f4cabb536a2a1dd6e308b6a8f0afafda7c")]

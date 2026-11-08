import Base
import ./upload-boundary/scan.bend as S
import ./verify-native-failures.bend as Native
import ../proofs/native-failures/tool.bend as Tool
import ./window-verification/check.bend as Output
import ../proofs/presentation/frontend.bend as Frontend

def targets() -> List<&2,String>:
  ["verify_presentation_serial_sequence","verify_presentation_acquire_results","verify_presentation_serial_exhaustion","verify_presentation_identity","verify_presentation_recording","verify_presentation_borrowed_recording","verify_presentation_submit_results","verify_presentation_uncertain_render_sequence","verify_presentation_fence_status","verify_presentation_frame_sequence","verify_presentation_present_results","verify_presentation_present_identity","verify_presentation_observation","verify_presentation_stale_completion","verify_presentation_reacquire_overlap","verify_presentation_release_results","verify_presentation_reuse_guards","verify_presentation_resize_guards","verify_presentation_drain_sequence","verify_presentation_close_sequence","verify_presentation_broken_association"]

def run(+negative:Bool) -> IO(Unit):
  do IO<Unit>:
    +binary:String <- Tool.ensure()
    +compiler:String <- Tool.ensure_compiler()
    _:String <- S.run("mkdir",["-p","build/verification"])
    directory:String <- S.run("mktemp",["-d","build/verification/presentation-XXXXXXXX"])
    +dest:String = String.trim(directory)
    IO.print("Presentation evidence: " ++ dest)
    Output.write(dest ++ "/run.status","1\n")
    Output.write(dest ++ "/selection.txt","presentation\nmutations=" ++ Bool.show(negative) ++ "\n")
    hashes:String <- S.run("sha256sum",["deps/bend-vulkan/src/native.c","src/scene-window.bend","src/scene-target.bend","proofs/native-failures/extract.bend","proofs/native-failures/tool.bend","proofs/native-failures/prelude.h","proofs/presentation/handlers.in.c","proofs/presentation/claims.h","proofs/presentation/frontend.bend","proofs/presentation/mutations.tsv","tools/verify-native-failures.bend","tools/verify-presentation.bend",binary,compiler])
    Output.write(dest ++ "/sources.sha256",hashes)
    version:String <- S.run(compiler,["--version"])
    Output.write(dest ++ "/goto-cc-version.txt",version)
    Frontend.run(dest,negative)
    Native.suite(Native.Suite{"presentation","proofs/presentation/handlers.in.c","proofs/presentation/claims.h",targets(),"proofs/presentation/mutations.tsv"},binary,dest,negative)
    Output.write(dest ++ "/run.status","0\n")
    IO.print("Production presentation ownership verified within the documented bounds.")

def args(values:List<String>) -> IO(Unit):
  match values:
    case [_]:run(False{})
    case [_,"--mutations"]:run(True{})
    case _:IO.die(Unit,1,"usage: verify-presentation [--mutations]")

def main() -> IO(Unit):
  do IO<Unit>:
    values:List<String> <- IO.args()
    args(values)

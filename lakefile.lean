import Lake
open Lake DSL System

package metabench where
  version := v!"0.1.0"
  leanOptions := #[⟨`autoImplicit, false⟩, ⟨`pp.fieldNotation, false⟩]

@[default_target]
lean_lib MetaBench

@[default_target]
lean_lib Tests where
  globs := #[.submodules `Tests]

/-- Build the native code for the CPU instruction count feature -/
target perfNative pkg : FilePath := do
  let src ←
    if Platform.isOSX then pure "perf_macos.c"
    else if Platform.isLinux then pure "perf_linux.c"
    else error "instructions can only be counted on Linux and macOS"
  let srcJob ← inputTextFile <| pkg.dir / "native" / src
  buildO (pkg.buildDir / "native" / "perf.o") srcJob (traceArgs := #["-O2", "-fPIC"])

@[default_target]
target perfDynlib pkg : Dynlib := do
  let some mod ← findModule? `MetaBench.Perf | error "the module MetaBench.Perf is missing"
  let leanO ← mod.oExport.fetch
  let nativeO ← perfNative.fetch
  buildLeanSharedLib "metabench_perf" (pkg.sharedLibDir / nameToSharedLib "metabench_perf")
    #[leanO, nativeO] #[]

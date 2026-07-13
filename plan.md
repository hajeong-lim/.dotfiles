# LLVM Frontend Constant-Time Fuzzing Plan

## Goal

Build a Python-based fuzzing framework that finds LLVM front/middle-end pass sequences that turn a constant-time LLVM IR program into a non-constant-time LLVM IR program.

Scope:

- Target LLVM IR and LLVM optimization passes.
- Exclude the backend-only `cmov` issue from the paper.
- Use the local XLLVM project as the default oracle.
- Keep the oracle pluggable so it can be replaced later.
- Reuse LLVM tooling wherever possible.

Non-goal:

- Proving backend machine code constant-time behavior in this first version.

## Assumptions

- LLVM 18 toolchain is available locally: `opt-18`, `clang-18`, `llvm-as-18`, `llvm-dis-18`, `llvm-reduce-18`, `llvm-stress-18`, `bugpoint-18`.
- XLLVM lives at `/home/hajeong/workspace/sc-fuzz-llvm/xllvm`.
- We will analyze IR-level constant-time violations only.
- A valid bug must be differential:
  - original IR is constant-time under the oracle
  - transformed IR is not constant-time under the oracle

## What We Are Trying to Reproduce

The referenced paper points to LLVM middle-end cases where:

- `InstCombine` introduces or reshapes `select`
- later passes such as `SimpleLoopUnswitchPass` and loop vectorization can turn that structure into non-constant-time IR
- pass interactions matter: one pass can create the precondition for a later pass, and another pass can sometimes undo the leak

This framework should be able to reproduce those findings, then generalize beyond them by varying:

- optimization level
- enabled/disabled passes
- pass order
- pass parameters
- seed program structure

## Core Design

The fuzzer has three moving parts:

1. Seed generator / corpus manager
2. Pass-pipeline mutator / executor
3. Oracle adapter

The main fuzzing unit is:

- `seed.ll`
- `seed.tags.json`
- optional `seed.ct_specs.json`
- `pipeline.txt`

Each fuzz iteration mutates either the seed, the pipeline, or both.

## Oracle

### Oracle definition

The oracle answers:

- Is the input IR constant-time?
- If not, what is the witness instruction or witness class?
- At what transformation point did the IR stop being constant-time?

### Default oracle: XLLVM

Use XLLVM `lcm` as the default oracle, driven through `opt-18`.

Representative invocation:

```bash
opt-18 \
  -load-pass-plugin "$XLLVM_BUILD/src/XLLVM.so" \
  -passes=lcm \
  -disable-output \
  -lcm-results=results.json \
  -lcm-security-tags=seed.tags.json \
  -lcm-constant-time-specs=seed.ct_specs.json \
  -lcm-constant-time-check \
  -lcm-relative-security \
  -lcm-transmitter-search \
  -lcm-leakage-search \
  candidate.ll
```

### Oracle verdict

For this project, a seed is considered baseline constant-time if:

- `constant_time_check.transmitters` is empty, and
- `relative_security_cache.is_secure == true`

A transformed IR is considered a finding if:

- baseline IR is constant-time, and
- transformed IR has a non-empty `constant_time_check.transmitters`, or
- transformed IR flips `relative_security_cache.is_secure` to `false`

### Frontend-only filtering

Because backend `select` to `cmov` handling is explicitly out of scope, the framework should not report a case solely because a secret-tainted `select` exists in IR.

A reportable frontend/middle-end finding should include at least one IR-level witness such as:

- secret-dependent `br` or `switch`
- secret-dependent control transmitter
- secret-dependent universal control transmitter
- secret-dependent address/data transmitter introduced in transformed IR
- operand-dependent timing instruction introduced in transformed IR according to `ct_specs`

### Differential oracle rule

The oracle must always run on both:

- original seed IR
- transformed IR

This avoids false positives from seeds that were already non-constant-time.

### Replaceable oracle interface

Define a small adapter boundary:

```python
class OracleResult(TypedDict):
    is_constant_time: bool
    witness_kind: list[str]
    witness_locations: list[str]
    raw_result_path: str

class Oracle(Protocol):
    def analyze(self, ir_path: str, metadata: SeedMetadata) -> OracleResult: ...
```

The fuzzing loop should depend only on this interface, not on XLLVM JSON details.

## Mutation

There are two separate genomes:

1. Program genome: LLVM IR seed
2. Pipeline genome: LLVM pass pipeline

Both need mutation because leaks depend on the interaction between program shape and pass sequence.

### Program mutation

Use targeted mutations, not purely random IR generation.

Good mutations:

- mutate constants, widths, loop trip counts, and array sizes
- clone or remove basic blocks when IR stays valid
- replace arithmetic masking idioms with equivalent IR forms
- vary `icmp` predicates and `select` placement
- wrap straight-line constant-time idioms inside loops
- insert or remove canonicalization opportunities that tempt `InstCombine`, unswitching, or vectorization

Program mutations must be followed by:

- IR verification
- baseline oracle check

If a mutated seed is not constant-time before optimization, discard it from the main corpus.

### Pipeline mutation

Represent the pass pipeline as a parsed `-passes=` tree, not a flat string. This matters because LLVM pipelines are nested by module/function/loop pass managers.

Initial pipelines:

- `default<O1>`
- `default<O2>`
- `default<O3>`
- `default<Os>`
- `default<Oz>`

Pipeline mutations:

- enable / disable a pass
- insert a pass near a compatible pass-manager scope
- delete a pass
- swap adjacent passes within the same scope
- duplicate a pass
- splice a subsequence from another interesting pipeline
- mutate pass parameters

High-priority pass families:

- `instcombine`
- `simple-loop-unswitch`
- `loop-vectorize`
- `slp-vectorizer`
- `loop-unroll`
- `simplifycfg`
- `licm`
- `loop-rotate`
- `jump-threading`
- `gvn` / `newgvn`
- `loop-simplifycfg`
- `loop-predication`

This list should be weighted, not hard-coded as the only search space.

### Seed sourcing

Use three seed classes.

1. Handwritten and known CT kernels
   - small constant-time idioms
   - XLLVM isolated tests
   - reduced crypto kernels

2. LLVM-derived structural seeds
   - mined from LLVM test cases, especially `Transforms/` and loop/vectorization tests
   - used as shape donors, not assumed to be constant-time by default

3. Generator-produced seeds
   - template-driven constant-time kernels
   - optionally mixed with `llvm-stress-18` fragments only after strong filtering

Important point:

`llvm-stress` is useful as a structure donor, but it is a poor primary source for this problem. The hard part is not “random valid IR”; the hard part is “baseline constant-time IR that sits near optimizer cliffs.”

## Feedback / Coverage

This fuzzer should use optimizer-behavior coverage, not runtime edge coverage of the program under test.

### Coverage signals

Use a union of three coverage spaces.

1. Pass-change coverage
   - which passes ran
   - which passes changed IR
   - first pass that caused CT to flip

2. IR-shape coverage
   - structural hash of IR snapshots after changed passes
   - CFG or loop-shape features
   - opcode and terminator distributions

3. Oracle-witness coverage
   - witness kind: branch, control transmitter, address transmitter, timing op, etc.
   - culprit pass
   - opcode class at witness site
   - source/debug location if available

### How to collect coverage

Reuse LLVM output where possible:

- `opt-18 -print-passes`
- `opt-18 -print-pipeline-passes`
- `opt-18 -print-changed`
- `opt-18 -debug-pass-manager`
- `opt-18 -pass-remarks*`
- LLVM structural hash printing pass

Each interesting input should save:

- original seed ID
- pipeline text
- per-pass changed snapshots or hashes
- oracle witness
- culprit pass

### How feedback drives mutation

Keep an input in the corpus if it yields any of:

- new pass-change coverage
- new IR-shape coverage
- new oracle-witness coverage
- a new differential constant-time violation

Assign more mutation energy to inputs that:

- flip the oracle
- reach rare pass sequences
- create rare structural hashes
- expose a new culprit pass or new witness type

## Execution Flow

1. Load seed package.
2. Verify seed IR with `opt-18 -passes=verify`.
3. Run the baseline oracle on the unoptimized seed.
4. Discard the seed if baseline is not constant-time.
5. Mutate the pipeline, the seed, or both.
6. Run `opt-18` with the candidate pipeline and capture changed-IR information.
7. Replay or inspect pass-by-pass snapshots to identify the earliest pass where CT flips.
8. Confirm the differential oracle result:
   - before culprit pass: constant-time
   - after culprit pass: non-constant-time
9. Save a reproducer.
10. Minimize the IR with `llvm-reduce-18` using the differential oracle as the reduction predicate.

## How To Identify the Culprit Pass

The paper is about which passes break constant time, so this is not optional.

Use one of these two modes:

1. Primary mode: parse `-print-changed` output and test snapshots lazily until the oracle flips.
2. Fallback mode: replay prefixes of the pipeline and rerun the oracle until the first failing prefix is found.

The final report for a finding should always include:

- seed ID
- original IR path
- minimized failing IR path
- exact pipeline
- culprit pass
- witness kind
- oracle output path

## Recommended Project Structure

```text
sc-fuzz/
  pyproject.toml
  .venv/
  src/sc_fuzz/
    corpus.py
    pipeline.py
    mutate_ir.py
    runner.py
    coverage.py
    reducers.py
    reporting.py
    oracles/
      base.py
      xllvm.py
  seeds/
    handwritten/
    llvm_mined/
    generated/
  artifacts/
    crashes/
    interesting/
    coverage/
```

## LLVM Infrastructure To Reuse

- `clang-18` for source-to-IR generation
- `opt-18` for pass execution, pass enumeration, pipeline printing, and pass diagnostics
- `llvm-as-18` / `llvm-dis-18` for normalization
- `llvm-reduce-18` for testcase minimization
- `bugpoint-18` as an optional fallback reducer / debugger
- LLVM test suite files as seed sources

## Key Challenges

### 1. High-quality constant-time seed generation

This is the main challenge.

Random IR is easy. Constant-time IR that is both:

- valid under the oracle, and
- likely to be transformed into non-constant-time IR

is hard.

The plan should therefore bias toward templates based on real constant-time idioms:

- branchless compare-and-select
- masked table scans
- arithmetic masking
- loop-based constant-time scans
- reduction patterns that look harmless until unswitched or vectorized

### 2. Security-tag generation for foreign seeds

LLVM test cases rarely come with High/Low labels. For imported seeds, we need either:

- automatic tag synthesis, or
- wrapper generation that embeds the interesting IR fragment into a tagged constant-time harness

The second approach is more reliable for early milestones.

### 3. Frontend vs backend separation

We must avoid rediscovering backend `cmov` effects and calling them frontend bugs.

The finding filter should require an IR-level witness, not only a suspicious `select`.

### 4. Pass interaction explosion

The search space is combinatorial. A flat random search across all LLVM passes will waste time.

The framework should start from default pipelines and mutate locally around them, with higher weight on the pass families implicated by the paper.

### 5. Oracle cost

Running XLLVM on every snapshot is expensive. The implementation should cache:

- oracle results by IR hash
- pipeline results by `(seed hash, pipeline hash)`
- structural coverage by snapshot hash

## Milestones

### Milestone 0: Environment

- create Python project and virtualenv
- define config for LLVM tools and XLLVM build path
- smoke-test XLLVM on a known input

### Milestone 1: Oracle adapter

- implement `Oracle` interface
- implement XLLVM adapter
- parse XLLVM JSON into a normalized verdict

### Milestone 2: Pipeline runner

- run arbitrary `opt-18 -passes=...`
- capture changed-IR metadata
- replay prefixes

### Milestone 3: Corpus and mutation

- seed package format
- initial handwritten constant-time corpus
- pipeline mutation engine
- targeted IR mutation engine

### Milestone 4: Coverage-guided loop

- corpus retention policy
- mutation scheduling
- artifact persistence

### Milestone 5: Reduction and reporting

- automatic `llvm-reduce-18` integration
- stable reproducer bundle
- culprit-pass report

### Milestone 6: Reproduction of paper cases

- reproduce front/middle-end cases from the paper
- verify the framework can isolate the same or equivalent culprit passes
- extend search beyond published examples

## Success Criteria

The first version is successful if it can:

- ingest constant-time seeds from handwritten cases and LLVM-derived cases
- mutate LLVM pass pipelines around default optimization pipelines
- use XLLVM as a differential oracle
- identify the earliest culprit pass that breaks constant time
- reduce the failing input automatically
- reproduce at least one frontend/middle-end finding of the paper without relying on backend `cmov`
- allow a future oracle replacement without changing the main fuzzing loop

## Recommended First Reproduction Target

Start with a narrow target before opening the full search space:

- constant-time loop-based seed with branchless `select`-like structure
- optimize under `default<O2>` / `default<O3>`
- prioritize mutations around:
  - `instcombine`
  - `simple-loop-unswitch`
  - `loop-vectorize`
  - `simplifycfg`

This gives the best chance of reproducing the paper quickly while keeping the architecture generic.

# FFT IP Security Analysis

## Scope

This page lists what the FFT IP does to keep its own state consistent, and what has been checked.
It is not a safety or security certification. No ISO 26262, NIST or other certification has been
done.

## Threat model

1. **Memory access:** an engine or host access outside the data or twiddle region.
2. **Control state:** a start, abort or length change in the middle of a run.
3. **Bus protocol:** a master that does not follow the APB protocol.
4. **Reset:** asynchronous reset in the middle of a run.

## Behaviour

- **Memory access.** The engine only addresses the data region (words 0 to 1023) and reads the
  twiddle region (words 1024 to 1535). The APB windows decode fixed address ranges.
- **Length check.** A run with an FFT length of 0 or above the build's maximum is refused at
  launch: FFT_STATUS.error is set and no computation runs.
- **Abort.** FFT_CTRL[1] stops a run; the engine issues no further memory write after it.
- **Bus protocol.** The APB slave assumes a compliant master. It has no PSLVERR and does not
  detect protocol violations: if a master drops PSEL in the middle of an access, the slave still
  completes it.
- **Reset.** All control registers have an asynchronous active-low reset. Reset synchronization
  is the SoC's responsibility.

## Verification

- A bit-exact regression (`tb/golden/`) compares the RTL and the synthesized netlist against a
  fixed-point model, including the buffer-swap and interrupt behaviour.
- Formal property proofs cover the control and memory-interface claims above under a compliant
  APB master, and mutation runs confirm the proofs fail when the checked behaviour is broken.
  Defects they found are fixed in this repository's history.

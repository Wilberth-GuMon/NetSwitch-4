A 4-port Ethernet L2 switch datapath built as **five chained, independently specified IP blocks**, each owning one hard problem of switch design: clock domain crossing, register access, line-rate parsing and MAC learning, buffered switching, and egress traffic management. Frames travel as 64-bit AXI-Stream from four independent recovered RX clocks (156.25 MHz, ±100 ppm) through a 250 MHz core to a shared TX clock, under a 100 MHz control domain.

#### 💠 Subproject 1 — CDCKit (✅Spec - ✅RTL - ⏩Testplan - 🏳️Verification - 🏳️Synthesis - 🏳️Signoff)
 
A parameterizable library of five clock-domain-crossing primitives (level, reset, pulse, multi-bit word, and streaming FIFO), each matched to the signal class it can cross safely. The design goal was to make **every crossing correct by construction, so that no simulation luck is needed**: the structure itself rules out the failure.

| Component / Feature | Description |
| :--- | :--- |
| **Asynchronous FIFO (Cummings-style)** | Gray pointers are registered before crossing, so the synchronizer never sees combinational glitches from the binary-to-Gray conversion, and a metastable sample can only resolve to the old or the new pointer. Full/empty are computed from the next pointer for single-cycle response and are conservative by construction: a stale remote pointer can only hide space or data, never invent it, so overflow and underflow are structurally impossible. |
| **First-word fall-through on distributed RAM** | Asynchronous read puts the head word on the output with zero read latency, trading BRAM efficiency for a simpler consumer. An optional gate blocks the memory-to-output path when empty. |
| **Reset crossing** | Async-assert / sync-deassert synchronizers, one per domain. Independent resets between FIFO sides are left as a documented reset-domain-crossing hazard, not silently ignored. |
| **Pulse crossing** | Toggle-based, because a one-cycle pulse can be missed entirely by a slower clock. An arming window masks the false edge the destination sees when its synchronizer converges after reset. |
| **SVA checkers** | Assertions for single-bit pointer change, no push when full, no pop when empty, handshake ordering, and minimum pulse spacing, kept in a separate file and bound in the verification phase. |
| **Synthesis-aware RTL** | Synchronizer flops are protected from retiming and shift-register packing, and the Gray pointer registers from merging with their binary twins (identical MSB). That merge is silent and breaks the one-bit-change guarantee the whole FIFO relies on. |
| **Shared package** | A single package holds the binary-to-Gray and Gray-to-binary conversions, so both FIFO pointer managers reuse one verified implementation and a width or encoding change touches one file. |
 
📂 Project Repository: [Clock Domain Crossing Kit](https://github.com/Wilberth-GuMon/NetSwitch-4/blob/main/1_Clock-Domain-Crossing-Kit)

#### 💠 Subproject 2 — Statistics CSR block (AXI4-Lite + APB) (⏩Spec - ⏩RTL - 🏳️Testplan - 🏳️Verification - 🏳️Synthesis - 🏳️Signoff)
AXI4-Lite slave that accepts AW and W in any order and responds only when it holds both, plus an APB4 slave with configurable wait states, sharing one register file. Register types cover RW, hardware RO, W1C interrupts, and clear-on-read without losing a same-cycle event; DECERR for unmapped and SLVERR for read-only writes. 64-bit counters live in their source clock domain and cross as coherent snapshots through the CDCKit handshake; software reads them atomically through a per-port high-half latch. Configuration is mirrored into the core domain, and interrupt events are coalesced so the pulse synchronizer's spacing rule can never be violated.

📂 Project Repository: [Statistics CSR Block](https://github.com/Wilberth-GuMon/NetSwitch-4/blob/main/2_Stats-CSR-Block)

#### 💠 Subproject 3 — Ethernet RX parser with parallel CRC-32 and L2 MAC table (AXI-Stream, 64-bit) (⏩Spec - ⏩RTL - 🏳️Testplan - 🏳️Verification - 🏳️Synthesis - 🏳️Signoff)
Three-block FSM with Moore outputs registered from the next state, VLAN/PCP extraction without latches, runt and oversize detection, and 802.1Qbb PFC frame decoding. The FCS is checked by the CRC residue: eight parallel per-byte-count XOR trees plus a mux are compared against the byte-chained baseline, with the **Fmax/area trade-off measured, not asserted**. Skid buffers break the `tready` path, and the RX clock adapter recovers from overruns without ever leaving a frame unterminated. A shared 2-way set-associative MAC table in BRAM does lookup, learning, station move, aging, and flooding at line rate for all four ports, with no read-after-write hazards by construction.

📂 Project Repository: [Ethernet RX Parser](https://github.com/Wilberth-GuMon/NetSwitch-4/blob/main/3_Ethernet-RX-Parser)

#### 💠 Subproject 4 — 4×4 fabric with VOQ, linked-list shared buffer, and iSLIP (⏩Spec - ⏩RTL - 🏳️Testplan - 🏳️Verification - 🏳️Synthesis - 🏳️Signoff)
Per-input shared cell buffer (free list, next-pointer RAM) with store-and-forward commit after the L2 decision, and 16 VOQs as linked lists with head/tail/count and the enqueue+dequeue bypass at count 1. Iterative iSLIP in packet mode (pairs locked until the last cell, so egress needs no reassembly), AND-OR crossbar with one-hot select, multicast through shared cells and reference counts, and credit-based flow control towards egress. Switchable to an input-FIFO mode to **reproduce the classic head-of-line blocking throughput gap** against VOQ+iSLIP.

📂 Project Repository: [Switch Fabric iSLIP](https://github.com/Wilberth-GuMon/NetSwitch-4/blob/main/4_Switch-Fabric-iSLIP)

#### 💠 Subproject 5 — QoS egress port (⏩Spec - ⏩RTL - 🏳️Testplan - 🏳️Verification - 🏳️Synthesis - 🏳️Signoff)
Eight-class strict-priority + byte-based deficit round-robin scheduler, Q8.8 fixed-point token-bucket shaper, and full Priority Flow Control: hysteresis generation with on-the-fly FCS, per-priority pause timers, and a storm watchdog. Credit interface to the fabric and clock gating inferred from `valid`. The port is a switchable power domain sequenced by an always-on FSM (drain → save → isolate → off), with glitch-free controls, isolation clamps, and state retention; the UPF is the next deliverable.

📂 Project Repository: [5 Egress QoS Port](https://github.com/Wilberth-GuMon/NetSwitch-4/blob/main/5_Egress-QoS-Port)

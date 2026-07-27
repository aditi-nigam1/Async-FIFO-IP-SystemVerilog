# Async-FIFO-IP-SystemVerilog
# Parameterised Asynchronous FIFO IP with Multi-Stage CDC Synchronization & SystemVerilog Verification

## 📌 Project Overview
This repository contains a production-grade, fully parameterised **Asynchronous FIFO (First-In, First-Out)** buffer designed in **SystemVerilog**. The core architecture acts as a highly resilient elastic data buffer operating between two completely independent, unrelated clock domains (Multi-Clock Domain System). This design is a critical building block in complex SOCs, Network-on-Chip (NoC) frameworks, and high-speed communication protocol controllers (PCIe, Ethernet, USB).

The project successfully demonstrates robust mitigation strategies for **Clock Domain Crossing (CDC)** challenges, including synchronization latency, data bus skew, and hardware **metastability**.

---

## 🏗️ Hardware Architecture & Design Features
The design is split into four distinct modular functional blocks to ensure clean structural boundary synthesis:

1. **Dual-Port Memory Matrix:** A true dual-port RAM array where write access is bound to the write clock domain (`w_clk`) and read access is bound to the independent read clock domain (`r_clk`). Includes structural boundary guards to prevent illegal pointer overflows or underflows.
2. **Binary to Gray Pointer Sequencers:** Implements pointer tracking using an extra Wrap-Around Bit (`ADDR_WIDTH + 1`) to accurately differentiate between a completely Full vs. completely Empty buffer status. Binary pointers are converted to Gray Code combinationally before crossing clock boundaries.
3. **Multi-Stage Cross-Domain Synchronizers:** Employs a robust 2-stage flip-flop synchronization pipeline to safely capture asynchronous pointers, allowing a full clock cycle for potential metastability oscillations to settle into clean digital states.
4. **Advanced Flag Generation Logic:** Computes dynamic status conditions (`w_full`, `r_empty`) alongside programmable early-warning flow-control backpressure flags (`w_almost_full`, `r_almost_empty`) to handle hardware data throttling.


---

## 🔬 Verification Strategy & Testbench Framework
The design was verified using a robust **SystemVerilog Procedural Verification Framework** built inside AMD Xilinx Vivado. The simulation models a highly stressed asymmetric clock infrastructure representing real-world hardware operating conditions:
* **Write Clock Domain (`w_clk`):** 100 MHz (10ns clock cycle period)
* **Read Clock Domain (`r_clk`):** 40 MHz (25ns clock cycle period)

### Automated Test Phases Executed:
* **Phase 1: Asynchronous System Reset Execution** — Drives predictable initialization metrics across both domains, safely routing the pipeline clear of uninitialized (`X`) locking logic states.
* **Phase 2: Burst Write Operations (FIFO Full Stress Test)** — Drives sequential data blocks into the fast write domain until backpressure signals trigger. Demonstrates that the design successfully asserts `w_full` and rejects extra inputs without data corruption.
* **Phase 3: Burst Read Operations (FIFO Empty Stress Test)** — Safely samples data crossing over to the slow read clock domain, tracking complete data delivery until `r_empty` asserts.
* **Phase 4: Concurrent Simultaneous Traffic** — Forks simultaneous, random parallel read and write request operations across mismatched clock cycles to verify timing margin safety.

---

## 📊 Simulation Waveform Analysis
*(Below is the verified behavioral simulation waveform trace showing the precise transaction performance)*



### Key Observations from Waveform Diagnostics:
* **Startup Initialization:** `r_data` properly retains an undefined state (`XX`) while the FIFO remains empty, proving safe boundary checking. 
* **CDC Flag Stability:** `w_almost_full` and `w_full` execute flawlessly during burst writes, preventing pointer overwrites.
* **Data Integrity Verification:** Hexadecimal marker patterns (`0xA0` through `0xAF`) are written rapidly by the 100 MHz clock and read out systematically by the slower 40 MHz clock with zero single-bit skew or packet loss.

---

## 🛠️ Tools Used
* **HDL Language:** SystemVerilog (IEEE 1800-2012 Compliance)
* **IDE & Simulator:** AMD Xilinx Vivado ML Edition (XSIM Simulation Engine)
* **Waveform Viewer:** Vivado Integrated Waveform Analysis Dashboard

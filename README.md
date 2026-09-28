![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) 

This project was executed by Vinutha S T, Yatin Sangwan, and Shylashree N from RVCE.
Direct-Mapped Cache Controller

A small, direct-mapped, write-through cache controller written in Verilog, verified in simulation, hardened on the SkyWater 130nm process, and packaged for a Tiny Tapeout shuttle.

Authors: Vinutha S T, Yatin Sangwan, Shylashree N (RV College of Engineering, Bengaluru)

What it does

A processor is much faster than main memory, so a cache keeps recently used data close by. This design is the controller for such a cache. It holds 4 cache lines. Each line stores a 4-bit tag, 8 bits of data, and a valid bit.

Every request is split into a 2-bit index and a 4-bit tag:

The index selects exactly one of the 4 lines (direct-mapped, so no searching).
The tag is compared with the tag stored in that line.
If the line is valid and the tags match, it is a hit and the stored data is returned.
Otherwise it is a miss: the data is taken from the memory data input, stored in the line, and returned. Cache and memory stay consistent (write-through), so no dirty bits are needed.
Architecture
Module	Role
cache_storage	4 slots holding tag, data and valid bit, with a synchronous reset that clears all valid bits
tag_comparator	Combinational hit check: valid AND stored tag equals requested tag
cache_fsm	4-state controller: Idle, Compare, Miss, Done
cache_controller	Top-level core that wires the three modules together
tt_um_vinutha_cache_controller	Tiny Tapeout wrapper that maps the core onto the fixed pin interface

FSM flow: Idle (wait for request) → Compare (check hit or miss) → on a hit go to Done; on a miss go to Miss (fetch and store) then Done → back to Idle.

Pin mapping
Pin	Direction	Function
ui_in[0]	input	request (pulse high for one clock)
ui_in[2:1]	input	index (selects the cache line)
ui_in[6:3]	input	tag
ui_in[7]	input	unused
uio_in[6:0]	input	mem_data_in[6:0], the value fetched on a miss
uo_out[7:0]	output	data_out, the returned data
uio_out[7]	output	done (uio_oe[7] is set, the other bidirectional pins are inputs)
clk, rst_n	input	clock and active-low reset

The top bit of the memory data input is tied to 0, so stored values range from 0 to 127. This is a limit of the pin budget in the wrapper; the core logic itself is 8 bits wide.

How to test
Hold rst_n low for a few clocks, then release it.
Put a 4-bit tag on ui_in[6:3] and a 2-bit index on ui_in[2:1].
Put the value that "memory" would return on uio_in[6:0].
Pulse ui_in[0] (request) high for one clock cycle.
Wait for uio_out[7] (done) to go high, then read uo_out[7:0].
Repeat with the same tag and index to see a hit. Use the same index with a different tag to see a miss, which replaces the old entry.
Verification

Five directed cocotb tests in test/test.py cover these cases:

First access to a new address (miss, fetch, store)
Repeat access to the same address (hit)
A different address in a different slot (independent miss)
Same index, different tag (must miss, proving the tag check works)
Return to the first address after it was evicted (miss again)

Two real bugs were found and fixed along the way:

Read-after-write hazard: the storage output lagged one cycle behind a write, so the first access returned an undefined value. Fixed by forwarding the write data directly to the outputs.
Unsynthesizable reset: valid bits were initialised only by a simulation-time initial block, which does not exist in real hardware. The gate-level test exposed it, and a real reset was added to cache_storage.

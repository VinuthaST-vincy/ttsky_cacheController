## How it works

This project is a small, direct-mapped, write-through cache controller. It holds 4 cache lines, each storing a tag, 8 bits of data, and a valid bit.

On a request, the controller checks whether the requested address (split into a 2-bit index and a 4-bit tag) is already cached:
- If the tag matches and the slot is valid, it's a **hit** -- the stored data is returned immediately.
- If not, it's a **miss** -- the controller fetches the value from the input data bus, stores it in the cache, and then returns it.

The design is built from four modules: a storage array (4 tagged slots), a tag comparator (checks for a hit), a 4-state FSM (Idle, Compare, Miss, Done) that sequences the request, and a top-level module that wires them together. The design was functionally verified with a directed testbench covering hit, miss, independent-slot, index-collision, and eviction scenarios, and was also carried through a full RTL-to-GDSII physical implementation using OpenLane on the SkyWater 130nm process (0.09 mm^2 die area, 2.24 ns critical path against a 10 ns target, zero timing/routing/LVS violations) before being adapted for Tiny Tapeout submission.

## How to test

1. Set `rst_n` low, then high to release reset.
2. Drive `ui_in[6:3]` with a 4-bit tag and `ui_in[2:1]` with a 2-bit index to select an address.
3. Drive `uio_in[6:0]` with the value you want stored at that address (this acts as the "main memory" data for a miss).
4. Pulse `ui_in[0]` (request) high for one cycle.
5. Wait for `uio_out[7]` (done) to go high.
6. Read the result on `uo_out[7:0]` (data_out).
7. Repeat step 2-6 with the same tag/index to observe a hit (faster, same data returned). Use a different tag with the same index to observe a miss despite an index match, confirming the tag comparison logic works correctly.

## External hardware

None. This project only uses the standard Tiny Tapeout digital I/O pins.

## Credits

We gratefully acknowledge the Center of Excellence (CoE) in Integrated Circuits and Systems (ICAS) and the Department of Electronics and Communication Engineering (ECE) for providing the necessary resources and guidance.

Special thanks to Dr. H V Ravish Aradhya (HoD - ECE), Dr. K R Usha Rani (Associate Dean - PG), Dr. K. S. Geetha (Vice Principal) and Dr. K. N. Subramanya (Principal) for their constant encouragement and support in facilitating this Tiny Tapeout submission.

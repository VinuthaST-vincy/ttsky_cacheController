/*
 * Cache Controller - Tiny Tapeout submission
 * Direct-mapped, write-through, 4-line cache controller
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module cache_storage (
    input clk,
    input reset,
    input write_enable,
    input [1:0] index,
    input [3:0] tag_in,
    input [7:0] data_in,

    output reg [3:0] tag_out,
    output reg [7:0] data_out,
    output reg valid_out
);

    reg [3:0] tag_array [0:3];
    reg [7:0] data_array [0:3];
    reg valid_array [0:3];

    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 4; i = i + 1) begin
                valid_array[i] <= 1'b0;
            end
            tag_out   <= 4'b0;
            data_out  <= 8'b0;
            valid_out <= 1'b0;
        end else if (write_enable) begin
            tag_array[index]   <= tag_in;
            data_array[index]  <= data_in;
            valid_array[index] <= 1'b1;

            tag_out   <= tag_in;
            data_out  <= data_in;
            valid_out <= 1'b1;
        end else begin
            tag_out   <= tag_array[index];
            data_out  <= data_array[index];
            valid_out <= valid_array[index];
        end
    end

endmodule


module tag_comparator (
    input [3:0] tag_a,
    input [3:0] tag_b,
    input valid,
    output hit
);

    assign hit = valid && (tag_a == tag_b);

endmodule


module cache_fsm (
    input clk,
    input reset,
    input request,
    input [3:0] tag_in,
    input [1:0] index_in,

    input stored_valid,
    input tag_match,

    output reg mem_fetch,
    output reg cache_write,
    output reg done
);

    localparam IDLE    = 2'b00;
    localparam COMPARE = 2'b01;
    localparam MISS    = 2'b10;
    localparam DONE    = 2'b11;

    reg [1:0] state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state       <= IDLE;
            mem_fetch   <= 0;
            cache_write <= 0;
            done        <= 0;
        end else begin
            case (state)

                IDLE: begin
                    done <= 0;
                    if (request)
                        state <= COMPARE;
                end

                COMPARE: begin
                    if (stored_valid && tag_match) begin
                        state <= DONE;
                    end else begin
                        mem_fetch <= 1;
                        state     <= MISS;
                    end
                end

                MISS: begin
                    mem_fetch   <= 0;
                    cache_write <= 1;
                    state       <= DONE;
                end

                DONE: begin
                    cache_write <= 0;
                    done        <= 1;
                    state       <= IDLE;
                end

            endcase
        end
    end

endmodule


module cache_controller (
    input clk,
    input reset,
    input request,
    input [1:0] index_in,
    input [3:0] tag_in,
    input [7:0] mem_data_in,

    output done,
    output [7:0] data_out
);

    wire mem_fetch;
    wire cache_write;
    wire [3:0] stored_tag;
    wire [7:0] stored_data;
    wire stored_valid;
    wire tag_match;

    cache_storage storage_inst (
        .clk(clk),
        .reset(reset),
        .write_enable(cache_write),
        .index(index_in),
        .tag_in(tag_in),
        .data_in(mem_data_in),
        .tag_out(stored_tag),
        .data_out(stored_data),
        .valid_out(stored_valid)
    );

    tag_comparator comparator_inst (
        .tag_a(tag_in),
        .tag_b(stored_tag),
        .valid(stored_valid),
        .hit(tag_match)
    );

    cache_fsm fsm_inst (
        .clk(clk),
        .reset(reset),
        .request(request),
        .tag_in(tag_in),
        .index_in(index_in),
        .stored_valid(stored_valid),
        .tag_match(tag_match),
        .mem_fetch(mem_fetch),
        .cache_write(cache_write),
        .done(done)
    );

    assign data_out = stored_data;

endmodule


// Tiny Tapeout wrapper: maps the fixed TT pin interface onto cache_controller
module tt_um_vinutha_cache_controller (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    wire reset      = ~rst_n;
    wire request    = ui_in[0];
    wire [1:0] index_in = ui_in[2:1];
    wire [3:0] tag_in   = ui_in[6:3];
    wire [7:0] mem_data_in = {1'b0, uio_in[6:0]};

    wire done;
    wire [7:0] data_out;

    cache_controller dut (
        .clk(clk),
        .reset(reset),
        .request(request),
        .index_in(index_in),
        .tag_in(tag_in),
        .mem_data_in(mem_data_in),
        .done(done),
        .data_out(data_out)
    );

    assign uo_out  = data_out;
    assign uio_out = {done, 7'b0};
    assign uio_oe  = 8'b10000000;

    wire _unused = &{ena, 1'b0};

endmodule

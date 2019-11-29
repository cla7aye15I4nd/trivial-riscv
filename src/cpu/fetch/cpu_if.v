module cpu_if(
    input wire clk,
    input wire rdy,
    input wire rst,
    
    // From Icache
    input wire hitx,
    input wire hity,
    input wire `word_t instx,
    input wire `word_t insty,

    // To Icache
    output wire en_rx_out,
    output wire en_ry_out,
    output wire `addr_t pcx_out,
    output wire `addr_t pcy_out,

    // From alu
    input wire en_jmp0,
    input wire `addr_t jmp_addr0,
    input wire en_jmp1,
    input wire `addr_t jmp_addr1,

    // To Decoder
    input wire issue0, issue1,
    output reg `inst_t pc0_out,
    output reg `inst_t pc1_out,
    output reg hitx_out,
    output reg hity_out,
    output reg `word_t instx_out,
    output reg `word_t insty_out
);

reg jmp_stall;
wire is_jmp0, is_jmp1;
reg `addr_t pcx, pcy;
wire en_jmp;
wire `addr_t jmp_addr;

assign en_jmp = en_jmp0 | en_jmp1;
assign jmp_addr = en_jmp0 ? jmp_addr0: jmp_addr1;
assign en_rx_out = 1;
assign en_ry_out = 1;
assign pcx_out = pcx;
assign pcy_out = pcy;
assign is_jmp0 = hitx && (instx[30 : 24] == 7'b1101111 || (instx[30 : 24] == 7'b1100111 && instx[22 : 20] == 3'b000)) ? 1 : 0;
assign is_jmp1 = hity && (insty[30 : 24] == 7'b1101111 || (insty[30 : 24] == 7'b1100111 && insty[22 : 20] == 3'b000)) ? 1 : 0;

`define REV(inst) {inst[7 : 0], inst[15 : 8], inst[23: 16], inst[31 : 24]}

always @(negedge clk) begin
    if (rst) begin
        jmp_stall <= 0;
        pcx <= 0;
        pcy <= 4;
    end else if (rdy) begin
        if (en_jmp) begin
            jmp_stall <= 0;
            pc0_out <= jmp_addr;
            pc1_out <= jmp_addr + 4;
            pcx <= jmp_addr;
            pcy <= jmp_addr + 4;
            instx_out <= `OP_NOP;
            insty_out <= `OP_NOP;
        end else begin
            if (issue0) begin
                if (issue1) begin
                    pc0_out <= pcx;
                    pc1_out <= pcy;
                    if (hitx) begin
                        hitx_out  <= 1;
                        instx_out <= jmp_stall ? `OP_NOP : `REV(instx);
                        if (hity) begin
                            hity_out  <= 1;
                            insty_out <= (is_jmp0 || jmp_stall) ? `OP_NOP : `REV(insty);
                            pcx <= en_jmp == 0 ? pcx + 8 : jmp_addr + 8;
                            pcy <= en_jmp == 0 ? pcy + 8 : jmp_addr + 12;
                        end else begin
                            hity_out  <= 0;
                            insty_out <= `OP_NOP;
                            pcx <= en_jmp == 0 ? pcx + 4 : jmp_addr + 4;
                            pcy <= en_jmp == 0 ? pcy + 4 : jmp_addr + 8;
                        end
                    end else begin
                        instx_out <= `OP_NOP;
                        hitx_out <= 0;
                        hity_out <= 0;
                    end
                    if (jmp_stall == 0 && (is_jmp0 || is_jmp1)) begin
                        jmp_stall <= 1;
                    end
                end else begin
                    /* no */
                end
            end else begin
                /* just reamin | do nothing */
            end
        end
    end
end
endmodule // cpu_if
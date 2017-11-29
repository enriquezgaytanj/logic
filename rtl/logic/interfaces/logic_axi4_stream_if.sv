/* Copyright 2017 Tymoteusz Blazejczyk
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

`include "logic.svh"

`ifndef LOGIC_STD_OVL_DISABLED
`include "std_ovl_defines.h"
`endif

/* Interface: logic_axi4_stream_if
 *
 * AXI4-Stream interface.
 *
 * Parameters:
 *  TDATA_BYTES - Number of bytes for tdata signal.
 *  TDEST_WIDTH - Number of bits for tdest signal.
 *  TUSER_WIDTH - Number of bits for tuser signal.
 *  TID_WIDTH   - Number of bits for tid signal.
 *
 * Ports:
 *  aclk        - Clock. Used only for internal checkers and assertions
 *  areset_n    - Asynchronous active-low reset. Used only for internal checkers
 *                and assertions
 */
interface logic_axi4_stream_if #(
    int TDATA_BYTES = 1,
    int TDEST_WIDTH = 1,
    int TUSER_WIDTH = 1,
    int TID_WIDTH = 1
) (
    input aclk,
    input areset_n
);
    localparam TSTRB_WIDTH = TDATA_BYTES;
    localparam TKEEP_WIDTH = TDATA_BYTES;

    typedef logic [TDATA_BYTES-1:0][7:0] tdata_t;
    typedef logic [TSTRB_WIDTH-1:0] tstrb_t;
    typedef logic [TKEEP_WIDTH-1:0] tkeep_t;
    typedef logic [TDEST_WIDTH-1:0] tdest_t;
    typedef logic [TUSER_WIDTH-1:0] tuser_t;
    typedef logic [TID_WIDTH-1:0] tid_t;

    typedef struct packed {
        tuser_t tuser;
        tdest_t tdest;
        tid_t tid;
        logic tlast;
        tkeep_t tkeep;
        tstrb_t tstrb;
        tdata_t tdata;
    } packet_t;

    logic tready;
    logic tvalid;
    logic tlast;
    tdata_t tdata;
    tstrb_t tstrb;
    tkeep_t tkeep;
    tdest_t tdest;
    tuser_t tuser;
    tid_t tid;

    function packet_t read();
        return '{tuser, tdest, tid, tlast, tkeep, tstrb, tdata};
    endfunction

    task write(input packet_t packet);
        {tuser, tdest, tid, tlast, tkeep, tstrb, tdata} <= packet;
    endtask

    task comb_write(input packet_t packet);
        {tuser, tdest, tid, tlast, tkeep, tstrb, tdata} = packet;
    endtask

`ifndef LOGIC_MODPORT_DISABLED
    modport rx (
        input tvalid,
        input tuser,
        input tdest,
        input tid,
        input tlast,
        input tkeep,
        input tstrb,
        input tdata,
        output tready,
        import read
    );

    modport tx (
        output tvalid,
        output tuser,
        output tdest,
        output tid,
        output tlast,
        output tkeep,
        output tstrb,
        output tdata,
        input tready,
        import write,
        import comb_write
    );

    modport mon (
        input tvalid,
        input tuser,
        input tdest,
        input tid,
        input tlast,
        input tkeep,
        input tstrb,
        input tdata,
        input tready,
        import read
    );
`endif

`ifndef LOGIC_STD_OVL_DISABLED
    genvar k;

    logic [`OVL_FIRE_WIDTH-1:0] assert_tvalid_always_reset_fire;

    ovl_always #(
        .severity_level(`OVL_FATAL),
        .property_type(`OVL_ASSERT),
        .msg("tvalid signal must be low during reset phase")
    )
    assert_tvalid_always_reset (
        .clock(aclk),
        .reset(1'b1),
        .enable(1'b1),
        .test_expr(areset_n || (!areset_n && !tvalid)),
        .fire(assert_tvalid_always_reset_fire)
    );

    generate
        for (k = 0; k < TDATA_BYTES; ++k) begin: tdata_bytes
            logic [`OVL_FIRE_WIDTH-1:0] assert_tkeep_tstrb_always_valid_fire;

            ovl_always #(
                .severity_level(`OVL_FATAL),
                .property_type(`OVL_ASSERT),
                .msg("tstrb cannot be high when tkeep is low")
            )
            assert_tkeep_tstrb_always_valid (
                .clock(aclk),
                .reset(areset_n),
                .enable(tvalid),
                .test_expr(tkeep[k] || (!tkeep[k] && !tstrb[k])),
                .fire(assert_tkeep_tstrb_always_valid_fire)
            );

            logic _unused_assert_fires = &{
                1'b0,
                assert_tkeep_tstrb_always_valid_fire,
                1'b0
            };
        end
    endgenerate

    logic [`OVL_FIRE_WIDTH-1:0] assert_tvalid_unchange_fire;

    ovl_win_unchange #(
        .severity_level(`OVL_FATAL),
        .width($bits(tvalid)),
        .property_type(`OVL_ASSERT),
        .msg("tvalid signal cannot change value during bus hold")
    )
    assert_tvalid_unchange (
        .clock(aclk),
        .reset(areset_n),
        .enable(1'b1),
        .start_event(tvalid && !tready),
        .test_expr(tvalid),
        .end_event(tvalid && tready),
        .fire(assert_tvalid_unchange_fire)
    );

    logic [`OVL_FIRE_WIDTH-1:0] assert_tlast_unchange_fire;

    ovl_win_unchange #(
        .severity_level(`OVL_FATAL),
        .width($bits(tlast)),
        .property_type(`OVL_ASSERT),
        .msg("tlast signal cannot change value during bus hold")
    )
    assert_tlast_unchange (
        .clock(aclk),
        .reset(areset_n),
        .enable(1'b1),
        .start_event(tvalid && !tready),
        .test_expr(tlast),
        .end_event(tvalid && tready),
        .fire(assert_tlast_unchange_fire)
    );

    logic [`OVL_FIRE_WIDTH-1:0] assert_tdata_unchange_fire;

    ovl_win_unchange #(
        .severity_level(`OVL_FATAL),
        .width($bits(tdata)),
        .property_type(`OVL_ASSERT),
        .msg("tdata signal cannot change value during bus hold")
    )
    assert_tdata_unchange (
        .clock(aclk),
        .reset(areset_n),
        .enable(1'b1),
        .start_event(tvalid && !tready),
        .test_expr(tdata),
        .end_event(tvalid && tready),
        .fire(assert_tdata_unchange_fire)
    );

    logic [`OVL_FIRE_WIDTH-1:0] assert_tkeep_unchange_fire;

    ovl_win_unchange #(
        .severity_level(`OVL_FATAL),
        .width($bits(tkeep)),
        .property_type(`OVL_ASSERT),
        .msg("tkeep signal cannot change value during bus hold")
    )
    assert_tkeep_unchange (
        .clock(aclk),
        .reset(areset_n),
        .enable(1'b1),
        .start_event(tvalid && !tready),
        .test_expr(tkeep),
        .end_event(tvalid && tready),
        .fire(assert_tkeep_unchange_fire)
    );

    logic [`OVL_FIRE_WIDTH-1:0] assert_tstrb_unchange_fire;

    ovl_win_unchange #(
        .severity_level(`OVL_FATAL),
        .width($bits(tstrb)),
        .property_type(`OVL_ASSERT),
        .msg("tstrb signal cannot change value during bus hold")
    )
    assert_tstrb_unchange (
        .clock(aclk),
        .reset(areset_n),
        .enable(1'b1),
        .start_event(tvalid && !tready),
        .test_expr(tstrb),
        .end_event(tvalid && tready),
        .fire(assert_tstrb_unchange_fire)
    );

    logic [`OVL_FIRE_WIDTH-1:0] assert_tuser_unchange_fire;

    ovl_win_unchange #(
        .severity_level(`OVL_FATAL),
        .width($bits(tuser)),
        .property_type(`OVL_ASSERT),
        .msg("tuser signal cannot change value during bus hold")
    )
    assert_tuser_unchange (
        .clock(aclk),
        .reset(areset_n),
        .enable(1'b1),
        .start_event(tvalid && !tready),
        .test_expr(tuser),
        .end_event(tvalid && tready),
        .fire(assert_tuser_unchange_fire)
    );

    logic [`OVL_FIRE_WIDTH-1:0] assert_tdest_unchange_fire;

    ovl_win_unchange #(
        .severity_level(`OVL_FATAL),
        .width($bits(tdest)),
        .property_type(`OVL_ASSERT),
        .msg("tdest signal cannot change value during bus hold")
    )
    assert_tdest_unchange (
        .clock(aclk),
        .reset(areset_n),
        .enable(1'b1),
        .start_event(tvalid && !tready),
        .test_expr(tdest),
        .end_event(tvalid && tready),
        .fire(assert_tdest_unchange_fire)
    );

    logic [`OVL_FIRE_WIDTH-1:0] assert_tid_unchange_fire;

    ovl_win_unchange #(
        .severity_level(`OVL_FATAL),
        .width($bits(tid)),
        .property_type(`OVL_ASSERT),
        .msg("tid signal cannot change value during bus hold")
    )
    assert_tid_unchange (
        .clock(aclk),
        .reset(areset_n),
        .enable(1'b1),
        .start_event(tvalid && !tready),
        .test_expr(tid),
        .end_event(tvalid && tready),
        .fire(assert_tid_unchange_fire)
    );

    logic _unused_assert_fires = &{
        1'b0,
        assert_tvalid_always_reset_fire,
        assert_tvalid_unchange_fire,
        assert_tlast_unchange_fire,
        assert_tdata_unchange_fire,
        assert_tkeep_unchange_fire,
        assert_tstrb_unchange_fire,
        assert_tuser_unchange_fire,
        assert_tdest_unchange_fire,
        assert_tid_unchange_fire,
        1'b0
    };
`endif
endinterface

// Se parametriza expected_item para que coincida con la llamada del checker
class expected_item #(parameter int width = 16);
  int rx_id;
  transaction #(width) tr;   
  function new(int rx_id, transaction #(width) tr);
    this.rx_id = rx_id;
    this.tr    = tr;
  endfunction
endclass

class bus_scoreboard #(parameter int width = 16, parameter int drvs = 4);
  localparam bit [7:0] BCAST_ID = 8'hFF;
  typedef enum {DST_UNICAST, DST_BCAST, DST_INVALID} dst_kind_e;

  mailbox #(transaction #(width))  agnt_sb_mbx;
  mailbox #(expected_item #(width)) sb_chkr_mbx;

  int n_unicast, n_bcast, n_invalid, n_expected;

  function new(mailbox #(transaction #(width)) agnt_sb_mbx, mailbox #(expected_item #(width)) sb_chkr_mbx);
    this.agnt_sb_mbx = agnt_sb_mbx;
    this.sb_chkr_mbx = sb_chkr_mbx;
  endfunction

  function dst_kind_e classify(bit [7:0] dst);
    if (dst == BCAST_ID) return DST_BCAST;
    if (dst < drvs)      return DST_UNICAST;
    return DST_INVALID;
  endfunction

  task add_expected(int rx_id, transaction #(width) tr);
    expected_item #(width) e = new(rx_id, tr);
    sb_chkr_mbx.put(e);
    n_expected++;
  endtask

  task run();
    transaction #(width) tr;
    forever begin
      agnt_sb_mbx.get(tr);
      case (classify(tr.dst_addr)) // Adaptado a la nomenclatura unificada
        DST_UNICAST: begin add_expected(tr.dst_addr, tr); n_unicast++; end
        DST_BCAST: begin
          for (int d = 0; d < drvs; d++)
            if (d != tr.src_terminal) add_expected(d, tr);
          n_bcast++;
        end
        DST_INVALID: begin n_invalid++; end
      endcase
    end
  endtask

  function void report();
    $display("[SB] unicast=%0d bcast=%0d invalid=%0d expected=%0d",
             n_unicast, n_bcast, n_invalid, n_expected);
  endfunction
endclass

class mon_hijo #(parameter int drvs = 4, parameter int width = 16);
  virtual dut_compl_if.MON vif;
  mailbox #(transaction #(width)) hijo_padre_mbx;
  int id;

  function new(int id, virtual dut_compl_if.MON vif, mailbox #(transaction #(width)) mbx);
    this.id = id;
    this.vif = vif;
    this.hijo_padre_mbx = mbx;
  endfunction

  task run();
    transaction #(width) t;
    forever begin
      @(vif.cb_mon);
      if (vif.cb_mon.push[0][id]) begin
        t = new();
        t.unpack(vif.cb_mon.D_push[0][id]); // Uso de unpack para extraer payload y destino
        t.rx_terminal = id;
        t.receive_time = $realtime;
        hijo_padre_mbx.put(t);
      end
    end
  endtask
endclass

class bus_monitor #(parameter int width = 16, parameter int drvs = 4);
  virtual dut_compl_if.MON vif;
  mailbox #(transaction #(width)) mon_chkr_mbx;
  mailbox #(transaction #(width)) hijo_padre_mbx;
  mon_hijo #(drvs, width) hijos[drvs];

  function new(virtual dut_compl_if.MON vif, mailbox #(transaction #(width)) mbx);
    this.vif = vif;
    this.mon_chkr_mbx = mbx;
    hijo_padre_mbx = new();
    for (int i = 0; i < drvs; i++) begin
      hijos[i] = new(i, vif, hijo_padre_mbx);
    end
  endfunction

  task run();
    for (int i = 0; i < drvs; i++) begin
      automatic int k = i;
      fork hijos[k].run(); join_none
    end
    forever begin
      transaction #(width) t;
      hijo_padre_mbx.get(t);
      mon_chkr_mbx.put(t);
    end
  endtask
endclass

class chk_result;
  int src; 
  int rx; 
  bit [63:0] data; 
  real sent_time; 
  real receive_time; 
  real delay;
endclass

class bus_checker #(parameter int width = 16, parameter int drvs = 4);
  mailbox #(expected_item #(width)) sb_chkr_mbx;
  mailbox #(transaction #(width)) mon_chkr_mbx;

  expected_item #(width) pending[drvs][$];
  chk_result results[$];

  int n_ok, n_unexpected, n_order, n_missing;
  real sum_delay, min_delay, max_delay;

  function new(mailbox #(expected_item #(width)) sb_chkr_mbx, mailbox #(transaction #(width)) mon_chkr_mbx);
    this.sb_chkr_mbx = sb_chkr_mbx;
    this.mon_chkr_mbx = mon_chkr_mbx;
  endfunction

  function void pull_expected();
    expected_item #(width) e;
    while (sb_chkr_mbx.try_get(e)) begin
      pending[e.rx_id].push_back(e);
    end
  endfunction

  task run();
    transaction #(width) obs;
    forever begin
      mon_chkr_mbx.get(obs);
      pull_expected();
      check(obs);
    end
  endtask

  function void check(transaction #(width) obs);
    int rx = obs.rx_terminal;
    int idx = -1;
    expected_item #(width) e;
    chk_result r;

    for (int i = 0; i < pending[rx].size(); i++) begin
      if (pending[rx][i].tr.pack() == obs.pack()) begin
        idx = i; break;
      end
    end

    if (idx < 0) begin
      n_unexpected++;
      $error("[CHK] unexpected %h at rx %0d, t=%0t", obs.pack(), rx, obs.receive_time);
      return;
    end

    e = pending[rx][idx];
    if (e.tr.sent_time == 0) $warning("[CHK] %h arrived with no sent_time", obs.pack());

    for (int j = 0; j < pending[rx].size(); j++) begin
      transaction #(width) o = pending[rx][j].tr;
      if (j != idx && o.src_terminal == e.tr.src_terminal && o.sent_time > 0 && o.sent_time < e.tr.sent_time) begin
        n_order++;
        $error("[CHK] out of order: %h", obs.pack());
        break;
      end
    end

    pending[rx].delete(idx);
    r = new();
    r.src = e.tr.src_terminal;
    r.rx = rx;
    r.data = obs.pack();
    r.sent_time = e.tr.sent_time;
    r.receive_time = obs.receive_time;
    r.delay = r.receive_time - r.sent_time;
    results.push_back(r);

    if (n_ok == 0 || r.delay < min_delay) min_delay = r.delay;
    if (r.delay > max_delay) max_delay = r.delay;
    sum_delay += r.delay; n_ok++;
  endfunction

  function void report();
    pull_expected();
    for (int rx = 0; rx < drvs; rx++) begin
      for (int i = 0; i < pending[rx].size(); i++) begin
        n_missing++;
        $error("[CHK] missing %h", pending[rx][i].tr.pack());
      end
    end
    $display("[CHK] ok=%0d unexpected=%0d out_of_order=%0d missing=%0d", n_ok, n_unexpected, n_order, n_missing);
  endfunction

  function void write_csv();
    int csv_file;
    
    // Abrir (o crear) el archivo en modo escritura ("w")
    csv_file = $fopen("reporte_retardos.csv", "w");
    
    if (csv_file) begin
      // 1. Escribir el encabezado de las columnas
      $fwrite(csv_file, "Terminal_Origen,Terminal_Destino,Tiempo_Envio,Tiempo_Recibido,Retardo\n");
      
      // 2. Iterar sobre la cola de resultados y escribir cada fila
      foreach (results[i]) begin
        $fwrite(csv_file, "%0d,%0d,%0t,%0t,%0t\n", 
                results[i].src, 
                results[i].rx, 
                results[i].sent_time, 
                results[i].receive_time, 
                results[i].delay);
      end
      
      // 3. Cerrar el archivo de forma segura
      $fclose(csv_file);
      $display("[CHK] Archivo reporte_retardos.csv generado exitosamente con %0d registros.", results.size());
    end else begin
      $error("[CHK] No se pudo crear el archivo CSV.");
    end
  endfunction

endclass

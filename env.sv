class bus_env #(parameter int width = 16, parameter int drvs = 4);
    
    generator      #(width)       gen;
    bus_agent      #(width, drvs) agent;
    bus_monitor    #(width, drvs) monitor;
    bus_scoreboard #(width)       sb;
    bus_checker    #(width, drvs) checker;

    mailbox #(transaction #(width))   mbx_gen_agent; 
    mailbox #(transaction #(width))   mbx_agent_sb;  
    mailbox #(expected_item #(width)) mbx_sb_chk;    
    mailbox #(transaction #(width))   mbx_mon_chk;   

    virtual dut_compl_if #(width, drvs, 16) vif;

    string csv_name = "reporte.csv";

    function new(virtual dut_compl_if #(width, drvs, 16) vif_in, int num_tx);
        this.vif = vif_in;

        mbx_gen_agent = new();
        mbx_agent_sb  = new();
        mbx_sb_chk    = new();
        mbx_mon_chk   = new();

        gen = new(mbx_gen_agent, num_tx);
        agent = new(mbx_gen_agent, mbx_agent_sb, vif.DRV);
        monitor = new(vif.MON, mbx_mon_chk);
        sb = new(mbx_agent_sb, mbx_sb_chk);
        checker = new(mbx_sb_chk, mbx_mon_chk);
    endfunction

    task wait_drain();
        fork
            begin
                fork
                    begin
                        while (agent.driver.sent() < gen.num_transactions) @(posedge vif.clk);
                        while (!checker.idle()) @(posedge vif.clk);
                        repeat (4 * width) @(posedge vif.clk);
                    end
                    begin
                        #(gen.num_transactions * 1000 + 10000);
                        $error("[ENV] Timeout: the bus did not drain");
                    end
                join_any
                disable fork;
            end
        join
    endtask

    task run();
        $display("[ENV] ==================================================");
        $display("[ENV] INICIANDO AMBIENTE DE VERIFICACION");
        $display("[ENV] ==================================================");

        fork
            agent.run();
            monitor.run();
            sb.run();
            checker.run();
        join_none

        gen.run();

        wait(gen.gen_completed.triggered);
        $display("[ENV] Generacion de estimulos completada. Esperando vaciado de FIFOs...");

        wait_drain();

        sb.report();
        checker.report();
        checker.write_csv(csv_name);
        
        $display("[ENV] ==================================================");
        $display("[ENV] SIMULACION FINALIZADA");
        $display("[ENV] ==================================================");
    endtask
endclass

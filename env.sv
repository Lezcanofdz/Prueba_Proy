class bus_env #(parameter int width = 16, parameter int drvs = 4);

    generator      #(width, drvs) gen;
    bus_agent      #(width, drvs) agent;
    bus_driver     #(width, drvs) driver;
    bus_monitor    #(width, drvs) monitor;
    bus_scoreboard #(width, drvs) sb;
    bus_checker    #(width, drvs) checker;

    mailbox #(transaction #(width, drvs))   mbx_gen_agent;
    mailbox #(transaction #(width, drvs))   mbx_agent_drv;
    mailbox #(transaction #(width, drvs))   mbx_agent_sb;
    mailbox #(expected_item #(width, drvs)) mbx_sb_chk;
    mailbox #(transaction #(width, drvs))   mbx_mon_chk;

    virtual dut_compl_if #(width, drvs) vif;

    string csv_name = "reporte.csv";

    function new(virtual dut_compl_if #(width, drvs) vif_in, int num_tx);
        this.vif = vif_in;

        mbx_gen_agent = new();
        mbx_agent_drv = new();
        mbx_agent_sb  = new();
        mbx_sb_chk    = new();
        mbx_mon_chk   = new();

        gen     = new(mbx_gen_agent, num_tx);
        agent   = new(mbx_gen_agent, mbx_agent_drv, mbx_agent_sb);
        driver  = new(vif, mbx_agent_drv);
        monitor = new(vif, mbx_mon_chk);
        sb      = new(mbx_agent_sb, mbx_sb_chk);
        checker = new(mbx_sb_chk, mbx_mon_chk);
    endfunction

    task wait_drain();
        fork
            begin
                fork
                    begin
                        while (!driver.is_empty()) @(posedge vif.clk);
                        while (!checker.idle()) @(posedge vif.clk);
                        repeat (4 * width) @(posedge vif.clk);
                    end
                    begin
                        #(gen.total_tx * 1000 + 10000);
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
            driver.run();
            monitor.run();
            sb.run();
            checker.run();
        join_none

        gen.run();

        wait (gen.done);
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

// Class bus_env.sv. The bus_env class is responsible for building every
// unit of the verification environment, connecting them with mailboxes,
// starting each one in its own process and deciding when the traffic has
// been drained so the results can be reported.
class bus_env #(parameter int width = 16, parameter int drvs = 4);

    virtual dut_compl_if #(width, drvs) vif;

    generator #(width, drvs) gen;
    bus_agent #(width, drvs) agent;
    bus_driver #(width, drvs) drv;
    bus_monitor #(width, drvs) mon;
    bus_scoreboard #(width, drvs) sb;
    bus_checker #(width, drvs) chk;

    mailbox #(transaction #(width, drvs)) gen_agent_mbx;
    mailbox #(transaction #(width, drvs)) agent_drv_mbx;
    mailbox #(transaction #(width, drvs)) agent_sb_mbx;
    mailbox #(transaction #(width, drvs)) mon_chk_mbx;
    mailbox #(expected_item #(width, drvs)) sb_chk_mbx;

    // Cycles allowed for the DUT to pop every packet (the bus is shared,
    // so packets are serialized one after another)
    int pop_timeout;
    // Cycles to wait for the expected packets after the FIFOs are empty
    int drain_timeout;

    function new(
        virtual dut_compl_if #(width, drvs) vif,
        int num_tx
    );
        this.vif = vif;

        gen_agent_mbx = new();
        agent_drv_mbx = new();
        agent_sb_mbx = new();
        mon_chk_mbx = new();
        sb_chk_mbx = new();

        gen = new(gen_agent_mbx, num_tx);
        agent = new(gen_agent_mbx, agent_drv_mbx, agent_sb_mbx);
        drv = new(vif, agent_drv_mbx);
        mon = new(vif, mon_chk_mbx);
        sb = new(agent_sb_mbx, sb_chk_mbx);
        chk = new(sb_chk_mbx, mon_chk_mbx);

        // One packet uses roughly width cycles of serialization plus a few
        // of protocol; allow a full arbitration round per packet
        pop_timeout = 4 * num_tx * (width + 16) + 1000;
        drain_timeout = 4 * drvs * (width + 16) + 1000;
    endfunction

    task run();
        int cycles;

        // FIFOs idle while the DUT is in reset
        drv.drive_idle();
        do @(vif.cb_drv); while (vif.cb_drv.reset !== 1'b0);

        fork
            gen.run();
            agent.run();
            drv.run();
            mon.run();
            sb.run();
            chk.run();
        join_none

        // 1. Every transaction generated and handed to the DUT
        wait (gen.done);
        cycles = 0;
        while ((!drv.is_empty() || gen_agent_mbx.num() != 0) && cycles < pop_timeout) begin
            @(vif.cb_mon);
            cycles++;
        end
        if (cycles >= pop_timeout) begin
            $error("[ENV] El DUT dejo de sacar paquetes de las FIFOs (timeout despues de %0d ciclos)", cycles);
        end else begin
            $display("[ENV] El DUT saco todos los paquetes de las FIFOs en %0t", $realtime);
        end

        // 2. Every expected reception arrived, or timeout
        cycles = 0;
        while (chk.outstanding() > 0 && cycles < drain_timeout) begin
            @(vif.cb_mon);
            cycles++;
        end
        if (cycles >= drain_timeout) begin
            $display("[ENV] Timeout esperando los paquetes pendientes despues de %0d ciclos", cycles);
        end

        // 3. Let packets without receivers (invalid addresses) finish
        repeat (2 * (width + 16)) @(vif.cb_mon);

        sb.report();
        chk.report();
        chk.write_csv();
    endtask

endclass

class fifo_emulator #(parameter int width = 16, parameter int id = 0);
    virtual dut_compl_if.DRV vif;
    transaction #(width) pkt_queue[$]; 

    function new(virtual dut_compl_if.DRV vif_in);
        this.vif = vif_in;
    endfunction

    task run();
        transaction #(width) current_pkt;
        forever begin
            @(vif.cb_drv);
            if (pkt_queue.size() > 0) begin
                vif.cb_drv.pndng[0][id] <= 1'b1;
                vif.cb_drv.D_pop[0][id] <= pkt_queue[0].pack();

                if (vif.cb_drv.pop[0][id] === 1'b1) begin
                    current_pkt = pkt_queue.pop_front();
                    current_pkt.sent_time = $realtime;
                    $display("[FIFO-%0d] Pkt inyectado al tiempo %0t", id, current_pkt.sent_time);
                end
            end else begin
                vif.cb_drv.pndng[0][id] <= 1'b0;
                vif.cb_drv.D_pop[0][id] <= '0;
            end
        end
    endtask
endclass

class bus_driver #(parameter int width = 16, parameter int drvs = 4);
    mailbox mbx_agent_driver;
    virtual dut_compl_if.DRV vif;
    
    fifo_emulator #(width, 0) hijo_0;
    fifo_emulator #(width, 1) hijo_1;
    fifo_emulator #(width, 2) hijo_2;
    fifo_emulator #(width, 3) hijo_3;

    function new(mailbox mbx, virtual dut_compl_if.DRV vif_in);
        this.mbx_agent_driver = mbx;
        this.vif = vif_in;
        hijo_0 = new(vif); hijo_1 = new(vif); hijo_2 = new(vif); hijo_3 = new(vif);
    endfunction

    task run();
        fork
            hijo_0.run(); hijo_1.run(); hijo_2.run(); hijo_3.run();
        join_none

        forever begin
            transaction #(width) pkt;
            mbx_agent_driver.get(pkt);
            fork
                automatic transaction #(width) p = pkt;
                begin
                    repeat(p.delay) @(vif.cb_drv);
                    case (p.src_terminal)
                        0: hijo_0.pkt_queue.push_back(p);
                        1: hijo_1.pkt_queue.push_back(p);
                        2: hijo_2.pkt_queue.push_back(p);
                        3: hijo_3.pkt_queue.push_back(p);
                    endcase
                end
            join_none
        end
    endtask
endclas

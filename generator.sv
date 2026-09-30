// Class generator.sv. The generator class is responsible for creating the
// randomized transactions of a test and sending them to the agent.
class generator #(parameter int width = 16, parameter int drvs = 4);

    mailbox #(transaction #(width, drvs)) gen_agent_mbx;
    int num_transactions;
    // Set when every transaction has been handed to the agent
    bit done;

    function new(
        mailbox #(transaction #(width, drvs)) gen_agent_mbx,
        int num_transactions
    );
        this.gen_agent_mbx = gen_agent_mbx;
        this.num_transactions = num_transactions;
        this.done = 0;
    endfunction

    task run();
        transaction #(width, drvs) pkt;
        $display("[GEN] Creating %0d transactions", num_transactions);
        for (int i = 0; i < num_transactions; i++) begin
            pkt = new();
            if (!pkt.randomize()) begin
                $fatal(1, "[GEN] Randomization failed on transaction %0d", i);
            end
            gen_agent_mbx.put(pkt);
            pkt.print($sformatf("GEN %0d", i));
        end
        done = 1;
    endtask

endclass

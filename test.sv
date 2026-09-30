// Class bus_test.sv. The bus_test class is responsible for configuring the
// scenario (number of transactions, read from +NUM_TX=<n>), running the
// environment and printing the final verdict.
class bus_test #(parameter int width = 16, parameter int drvs = 4);

    bus_env #(width, drvs) env;
    int num_tx;

    function new(
        virtual dut_compl_if #(width, drvs) vif
    );
        if (!$value$plusargs("NUM_TX=%d", num_tx)) num_tx = 50;
        env = new(vif, num_tx);
    endfunction

    task run();
        $display("[TEST] ancho=%0d terminales=%0d transacciones=%0d", width, drvs, num_tx);
        env.run();
        if (env.chk.n_errors() == 0 && env.chk.n_ok > 0) begin
            $display("[TEST] APROBADO");
        end else begin
            $display("[TEST] FALLIDO (%0d errores)", env.chk.n_errors());
        end
    endtask

endclass

// Class bus_test.sv. The bus_test class is responsible for configuring the scenario, building the environment, running it and deciding whether the test passed or failed from the checker results.
class bus_test #(parameter int width = 16, parameter int drvs = 4);

    bus_env #(width, drvs) env;

    string test_name;
    int num_transacciones;
    int seed;

    function new(
        virtual dut_compl_if #(width, drvs) vif_in,
        bit [7:0] bcast_id = 8'hFF
    );
        this.test_name = "base";
        this.num_transacciones = 50;

        if (!$value$plusargs("ntb_random_seed=%d", seed)) seed = 0;

        this.env = new(vif_in, num_transacciones);
        // The RTL (testbench.sv) was built with this broadcast id; the
        // generator and the scoreboard need the same value to classify
        // packets the same way the DUT does.
        this.env.gen.bcast_id = bcast_id;
        this.env.sb.bcast_id  = bcast_id;
        this.env.csv_name = $sformatf("reporte_%s_w%0d_seed%0d.csv", test_name, width, seed);
    endfunction

    task run();
        int errors;

        $display("[TEST] ==================================================");
        $display("[TEST] INICIANDO PRUEBA %s (semilla %0d)", test_name, seed);
        $display("[TEST] Generando %0d transacciones...", num_transacciones);
        $display("[TEST] ==================================================");

        env.run();

        errors = env.checker.errors();

        $display("[TEST] ==================================================");
        if (errors == 0 && env.checker.n_ok > 0) begin
            $display("[TEST] RESULTADO: PASS (%0d paquetes correctos)", env.checker.n_ok);
        end else if (env.checker.n_ok == 0) begin
            $display("[TEST] RESULTADO: FAIL (no llego ningun paquete)");
        end else begin
            $display("[TEST] RESULTADO: FAIL (%0d errores: inesperados=%0d, fuera de orden=%0d, perdidos=%0d)",
                     errors, env.checker.n_unexpected, env.checker.n_order, env.checker.n_missing);
        end
        $display("[TEST] ==================================================");
    endtask

endclass

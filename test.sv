// Class bus_test.sv. The bus_test class is responsible for configuring the scenario, building the environment, running it and deciding whether the test passed or failed from the checker results.
//
// The scenario is chosen with +TEST_CASE=<name> (default GENERAL):
//   GENERAL    - random mix of unicast/broadcast/invalid traffic
//   BCAST      - every packet is broadcast
//   INVALID    - every packet is addressed to a nonexistent terminal
//   OVERFLOW   - one terminal is flooded with back-to-back packets and a
//                small FIFO depth, to force the emulated FIFO to fill up
//   UNDERFLOW  - heavy random traffic with near-zero delay, used to stress
//                the handshake and confirm the DUT never pops an empty FIFO
//                (the check itself lives in driver.sv; passing here means
//                the "[DRV-x] pop recibido con la FIFO vacia" message never
//                showed up in the log)
//
// Other optional plusargs: +ntb_random_seed=<n>, +NUM_TX=<n>, +FIFO_DEPTH=<n>
class bus_test #(parameter int width = 16, parameter int drvs = 4);

    bus_env #(width, drvs) env;

    string test_name;
    int num_transacciones;
    int seed;
    int unsigned fifo_depth;

    function new(
        virtual dut_compl_if #(width, drvs) vif_in,
        bit [7:0] bcast_id = 8'hFF
    );
        string case_name;

        if (!$value$plusargs("ntb_random_seed=%d", seed)) seed = 0;
        if (!$value$plusargs("TEST_CASE=%s", case_name)) case_name = "GENERAL";

        this.test_name = case_name.tolower();
        this.num_transacciones = 50;
        this.fifo_depth = 16;

        // Case-specific defaults (can still be overridden by +NUM_TX / +FIFO_DEPTH below)
        case (case_name)
            "OVERFLOW":  begin this.num_transacciones = 20; this.fifo_depth = 2; end
            "UNDERFLOW": this.num_transacciones = 150;
            default: ; // GENERAL, BCAST, INVALID: defaults above are fine
        endcase

        void'($value$plusargs("NUM_TX=%d", this.num_transacciones));
        void'($value$plusargs("FIFO_DEPTH=%d", this.fifo_depth));

        this.env = new(vif_in, num_transacciones, fifo_depth);
        this.env.gen.bcast_id = bcast_id;
        this.env.sb.bcast_id  = bcast_id;

        // Configure the generator knobs for the chosen case
        case (case_name)
            "GENERAL": ; // keep the generator's own randomized defaults
            "BCAST": begin
                this.env.gen.pct_bcast = 100;
                this.env.gen.pct_inv   = 0;
            end
            "INVALID": begin
                this.env.gen.pct_bcast = 0;
                this.env.gen.pct_inv   = 100;
            end
            "OVERFLOW": begin
                this.env.gen.pct_bcast = 0;
                this.env.gen.pct_inv   = 0;
                this.env.gen.min_delay = 0;
                this.env.gen.max_delay = 0;
                this.env.gen.flood_terminal = 0; // floods terminal 0
            end
            "UNDERFLOW": begin
                this.env.gen.min_delay = 0;
                this.env.gen.max_delay = 2;
            end
            default: begin
                $fatal(1, "[TEST] TEST_CASE desconocido: '%s' (opciones: GENERAL, BCAST, INVALID, OVERFLOW, UNDERFLOW)", case_name);
            end
        endcase

        this.env.csv_name = $sformatf("reporte_%s_w%0d_seed%0d.csv", test_name, width, seed);
    endfunction

    task run();
        int errors;

        $display("[TEST] ==================================================");
        $display("[TEST] INICIANDO PRUEBA %s (semilla %0d)", test_name, seed);
        $display("[TEST] Generando %0d transacciones (fifo_depth=%0d)...", num_transacciones, fifo_depth);
        $display("[TEST] ==================================================");

        env.run();

        errors = env.checker.errors();

        $display("[TEST] ==================================================");
        if (errors == 0 && env.checker.n_ok > 0) begin
            $display("[TEST] RESULTADO: PASS (%0d paquetes correctos)", env.checker.n_ok);
        end else if (env.checker.n_ok == 0 && env.checker.n_unexpected == 0) begin
            $display("[TEST] RESULTADO: PASS (0 paquetes esperados, 0 recibidos: esperado para INVALID puro sin receptor)");
        end else begin
            $display("[TEST] RESULTADO: FAIL (%0d errores: inesperados=%0d, fuera de orden=%0d, perdidos=%0d)",
                     errors, env.checker.n_unexpected, env.checker.n_order, env.checker.n_missing);
        end
        $display("[TEST] ==================================================");
    endtask

endclass

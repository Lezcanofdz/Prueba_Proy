
// 1. Inclusión de archivos (El orden es crucial para que el compilador entienda las jerarquías)
`include "interface.sv"
`include "transaction.sv"
`include "generator.sv"
`include "driver.sv"
`include "agent.sv"
`include "monitor.sv"
`include "scoreboard.sv"
`include "checker.sv"

`include "env.sv"
`include "test.sv"

module testbench;

    // 2. Parámetros de la prueba base (16 bits, 4 dispositivos)
    parameter int p_width = 16;
    parameter int p_drvs  = 4;
    parameter int p_bits  = 1;

    // 3. Generación del Reloj Físico
    logic clk;
    initial begin
        clk = 0;
        // Cambia de estado cada 5 unidades de tiempo (Periodo de 10)
        forever #5 clk = ~clk; 
    end

    // 4. Instanciación de la Interfaz Física
    // Se conecta únicamente el reloj. El reset es interno a la interfaz, 
    // tal como lo definió tu compañero.
    dut_compl_if #(p_width, p_drvs, p_bits) vif (
        .clk(clk)
    );

    // 5. Instanciación del Diseño Bajo Prueba (RTL del profesor)
    bs_gnrtr_n_rbtr #(
        .bits(p_bits),
        .drvrs(p_drvs),
        .pckg_sz(p_width)
    ) dut (
        .clk(clk),
        .reset(vif.reset),
        .pndng(vif.pndng),
        .push(vif.push),
        .pop(vif.pop),
        .D_pop(vif.D_pop),
        .D_push(vif.D_push)
    );

    // 6. Declaración del bloque de Test de Software
    bus_test #(p_width, p_drvs) test;

    // 7. Bloque de Ejecución Principal
    initial begin
        // Configuración VCD: Indispensable para ver gráficas en EPWave (EDA Playground)
        $dumpfile("dump.vcd");
        $dumpvars(0, testbench);

        // A. Secuencia de Reset Física
        $display("[TOP] Aplicando reset de hardware al bus...");
        vif.reset = 1;
        #20; // Esperamos 20 unidades de tiempo
        vif.reset = 0;
        $display("[TOP] Reset liberado. Arrancando software de verificacion...");

        // B. Construcción del Test
        // Le inyectamos la interfaz física virtualizada al mundo del software
        test = new(vif);
        
        // C. Ejecución (Esto arranca el Env -> Agente -> Driver/Generator)
        test.run();

        // D. Cierre del simulador
        $finish;
    end

endmodule

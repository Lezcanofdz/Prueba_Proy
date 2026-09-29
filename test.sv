
class bus_test #(parameter int width = 16, parameter int drvs = 4);
    
    // 1. Declaración del Ambiente
    bus_env #(width, drvs) env;
    
    // Variable para controlar la cantidad de transacciones de esta prueba específica
    int num_transacciones;

    // 2. Constructor
    function new(virtual dut_compl_if vif_in);
        // Para esta prueba base (casos generales), definimos 50 paquetes
        this.num_transacciones = 50;
        
        // Construimos el ambiente pasándole la interfaz y la cantidad de paquetes
        this.env = new(vif_in, num_transacciones);
    endfunction

    // 3. Tarea principal de la prueba
    task run();
        $display("[TEST] ==================================================");
        $display("[TEST] INICIANDO PRUEBA BASE (BASE_TEST)");
        $display("[TEST] Generando %0d transacciones...", num_transacciones);
        $display("[TEST] ==================================================");

        // El Test le cede el control al Ambiente. 
        // Esta línea pausa el Test hasta que el Ambiente (y el Generador) terminen.
        env.run();

        $display("[TEST] ==================================================");
        $display("[TEST] PRUEBA FINALIZADA CORRECTAMENTE");
        $display("[TEST] ==================================================");
    endtask

endclass


class bus_env #(parameter int width = 16, parameter int drvs = 4);
    
    // ------------------------------------------------------------------------
    // 1. Declaración de Componentes (Activos y Pasivos)
    // ------------------------------------------------------------------------
    // Lado Activo (Persona A)
    generator  #(width)       gen;
    bus_agent  #(width, drvs) agent;
    
    // Lado Pasivo (Persona B)
    // Nota: Declaramos los componentes del compañero asumiendo nombres estándar
    bus_monitor    #(width, drvs) monitor;
    bus_scoreboard #(width)       sb;
    bus_checker    #(width)       checker;

    // ------------------------------------------------------------------------
    // 2. Declaración de Buzones (La tubería de comunicación)
    // ------------------------------------------------------------------------
    mailbox mbx_gen_agent; // Conecta Generador -> Agente
    mailbox mbx_agent_sb;  // Conecta Agente -> Scoreboard
    mailbox mbx_sb_chk;    // Conecta Scoreboard -> Checker (Predicciones)
    mailbox mbx_mon_chk;   // Conecta Monitor -> Checker (Observaciones)

    // Interfaz virtual de nivel superior
    virtual dut_compl_if vif;

    // ------------------------------------------------------------------------
    // 3. Constructor (Ensamblaje del entorno)
    // ------------------------------------------------------------------------
    function new(virtual dut_compl_if vif_in, int num_tx);
        this.vif = vif_in;

        // A. Instanciar los buzones físicos en memoria
        mbx_gen_agent = new();
        mbx_agent_sb  = new();
        mbx_sb_chk    = new();
        mbx_mon_chk   = new();

        // B. Instanciar componentes pasando los buzones y modports correspondientes
        
        // El Generador solo necesita su buzón de salida y la cantidad de paquetes
        gen = new(mbx_gen_agent, num_tx);
        
        // El Agente recibe la entrada del generador, la salida al scoreboard y el modport DRV
        agent = new(mbx_gen_agent, mbx_agent_sb, vif.DRV);
        
        // El Monitor recibe su buzón de salida hacia el checker y el modport MON
        monitor = new(mbx_mon_chk, vif.MON);
        
        // El Scoreboard conecta el agente con el checker
        sb = new(mbx_agent_sb, mbx_sb_chk);
        
        // El Checker recibe las expectativas (del SB) y la realidad (del Monitor)
        checker = new(mbx_sb_chk, mbx_mon_chk);
    endfunction

    // ------------------------------------------------------------------------
    // 4. Tarea Principal (Control de ejecución)
    // ------------------------------------------------------------------------
    task run();
        $display("[ENV] ==================================================");
        $display("[ENV] INICIANDO AMBIENTE DE VERIFICACION");
        $display("[ENV] ==================================================");

        // Iniciar todos los componentes reactivos en hilos paralelos (background)
        fork
            agent.run();
            monitor.run();
            sb.run();
            checker.run();
        join_none

        // Iniciar el generador en el hilo principal (es el que dicta el ritmo)
        gen.run();

        // Pausar el ambiente hasta que el generador avise que terminó de inyectar todo
        wait(gen.gen_completed.triggered);
        $display("[ENV] Generacion de estimulos completada. Esperando vaciado de FIFOs...");

        // Esperar un tiempo prudencial para que los últimos paquetes crucen el hardware
        #500; 
        
        // Llamar a la función del compañero para imprimir el resumen y cerrar el CSV
        checker.final_report();
        checker.write_csv();
        
        $display("[ENV] ==================================================");
        $display("[ENV] SIMULACION FINALIZADA");
        $display("[ENV] ==================================================");
    endtask

endclass

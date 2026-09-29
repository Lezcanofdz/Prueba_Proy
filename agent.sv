
class bus_agent #(parameter int width = 16, parameter int drvs = 4);

    // --------------------------------------------------------
    // 1. Buzones de comunicación (Mailboxes)
    // --------------------------------------------------------
    mailbox mbx_gen_agent;    // Buzón de entrada: Recibe del Generador
    mailbox mbx_agent_driver; // Buzón de salida 1: Envía al Driver
    mailbox mbx_agent_sb;     // Buzón de salida 2: Envía al Scoreboard

    // --------------------------------------------------------
    // 2. Componentes internos
    // --------------------------------------------------------
    // El Agente es el dueño del Driver, por lo que lo instancia aquí
    bus_driver #(width, drvs) driver;

    // Interfaz virtual para pasársela al Driver
    virtual dut_compl_if.DRV vif;

    // --------------------------------------------------------
    // 3. Constructor
    // --------------------------------------------------------
    // El ambiente superior (env) le pasará el buzón del generador, el del scoreboard y la interfaz
    function new(mailbox mbx_gen, mailbox mbx_sb, virtual dut_compl_if.DRV vif_in);
        this.mbx_gen_agent = mbx_gen;
        this.mbx_agent_sb  = mbx_sb;
        this.vif = vif_in;

        // Inicializamos el buzón interno que conectará al Agente con su Driver
        this.mbx_agent_driver = new();

        // Construimos el Driver entregándole su buzón y la interfaz física
        this.driver = new(mbx_agent_driver, vif);
    endfunction

    // --------------------------------------------------------
    // 4. Tarea Principal (Motor de enrutamiento)
    // --------------------------------------------------------
    task run();
        transaction #(width) pkt;
        transaction #(width) pkt_copia;

        // Encendemos el Driver en un hilo paralelo (background) para que 
        // empiece a escuchar su buzón inmediatamente
        fork
            driver.run();
        join_none

        $display("[AGENTE] Iniciando enrutamiento de paquetes...");

        // Ciclo infinito: El Agente siempre está esperando paquetes nuevos
        forever begin
            // A. Recibir del generador (Se queda pausado aquí hasta que llegue algo)
            mbx_gen_agent.get(pkt);

            // B. Crear una copia profunda (clon) para el Scoreboard.
            // Esto es vital: si el Driver modifica el tiempo de envío del paquete original,
            // no queremos alterar los datos que el Scoreboard usará para comparar.
            pkt_copia = new pkt; 

            // C. Enviar al Driver para su inyección física
            mbx_agent_driver.put(pkt);

            // D. Enviar la copia al Scoreboard para la verificación posterior
            mbx_agent_sb.put(pkt_copia);

            $display("[AGENTE] Paquete enrutado -> Driver & Scoreboard (Destino: %0d)", pkt.dst_addr);
        end
    endtask

endclass

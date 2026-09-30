// Class transaction.sv. The transaction class is responsible for describing
// one packet of the bus: the randomized fields that the generator produces,
// the bit-level format the DUT expects (destination in the 8 MSBs, payload
// in the remaining bits) and the timestamps used by the checker and the CSV.
class transaction #(parameter int width = 16, parameter int drvs = 4);

    // Randomized fields
    rand int unsigned delay;
    rand int unsigned src_terminal;
    rand bit [7:0] dst_addr;
    rand bit [width-9:0] payload;

    // Control and reporting fields (not randomized)
    int rx_terminal;
    // Timestamps in simulation time units, -1 means "not happened yet"
    real sent_time;
    real receive_time;

    // Idle cycles before the packet enters the source FIFO
    constraint c_delay {
        delay inside {[0:20]};
    }

    // The source must be one of the connected terminals
    constraint c_src {
        src_terminal inside {[0:drvs-1]};
    }

    // Destination mix: valid terminals, broadcast and non-existent terminals
    constraint c_dst_addr {
        dst_addr dist {
            [0:drvs-1] :/ 70,
            8'hFF := 15,
            [drvs:254] :/ 15
        };
    }

    // A terminal never receives its own packet (it holds the bus while
    // sending), so a packet addressed to itself would never be observed
    constraint c_no_self {
        dst_addr != src_terminal;
    }

    function new();
        this.rx_terminal = -1;
        this.sent_time = -1;
        this.receive_time = -1;
    endfunction

    // Builds the word that the DUT reads from D_pop
    function bit [width-1:0] pack();
        return {dst_addr, payload};
    endfunction

    // Rebuilds the fields from the word that the DUT writes on D_push
    function void unpack(bit [width-1:0] data);
        this.dst_addr = data[width-1:width-8];
        this.payload = data[width-9:0];
    endfunction

    function void print(string tag = "");
        $display("[%s] origen=%0d destino=%0d retardo=%0d dato=%h",
                 tag, src_terminal, dst_addr, delay, payload);
    endfunction

endclass

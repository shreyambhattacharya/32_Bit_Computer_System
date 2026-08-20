// One-outstanding-transaction Mini32 memory bus. A request is captured in
// IDLE, issued to synchronous memory in MEMORY, then completed in RESPONSE.
module system_bus #(
    parameter ROM_INIT_FILE = ""
) (
    input  logic                    clk,
    input  logic                    reset,
    input  logic                    retire_tick,
    input  logic [31:0]             gpio_input,
    input  logic                    request_valid,
    input  mini32_pkg::bus_access_t request_access,
    input  logic [31:0]             request_addr,
    input  logic [31:0]             request_wdata,
    output logic                    response_ready,
    output logic [31:0]             response_rdata,
    output mini32_pkg::bus_fault_t  response_fault,
    output logic                    uart_tx_valid,
    output logic [7:0]              uart_tx_data,
    output logic [31:0]             debug_value,
    output logic [31:0]             gpio_output,
    output logic [31:0]             gpio_direction,
    output logic [31:0]             timer_counter,
    output logic [31:0]             timer_compare,
    output logic [31:0]             timer_control
);
    import mini32_pkg::*;

    typedef enum logic [1:0] { BUS_IDLE, BUS_MEMORY, BUS_RESPONSE } bus_state_t;
    bus_state_t state;
    bus_access_t pending_access;
    logic [31:0] pending_addr, pending_wdata;
    logic pending_rom, pending_ram, pending_uart, pending_timer, pending_gpio, pending_debug;
    bus_fault_t pending_fault;
    logic rom_read_enable, ram_read_enable, ram_write_enable;
    logic uart_read_enable, uart_write_enable, timer_read_enable, timer_write_enable;
    logic gpio_read_enable, gpio_write_enable, debug_read_enable, debug_write_enable;
    logic [31:0] rom_read_data, ram_read_data, uart_read_data, timer_read_data, gpio_read_data, debug_read_data;
    logic pending_in_reserved_mmio;

    rom #(.INIT_FILE(ROM_INIT_FILE)) rom_instance (
        .clk(clk), .read_enable(rom_read_enable), .word_address(pending_addr[15:2]), .read_data(rom_read_data)
    );
    ram ram_instance (
        .clk(clk), .read_enable(ram_read_enable), .write_enable(ram_write_enable),
        .word_address(pending_addr[15:2]), .write_data(pending_wdata), .read_data(ram_read_data)
    );
    uart_mmio uart_instance (
        .clk(clk), .reset(reset), .read_enable(uart_read_enable), .write_enable(uart_write_enable),
        .register_offset(pending_addr[3:0]), .write_data(pending_wdata), .read_data(uart_read_data),
        .tx_valid(uart_tx_valid), .tx_data(uart_tx_data)
    );
    debug_mmio debug_instance (
        .clk(clk), .reset(reset), .read_enable(debug_read_enable), .write_enable(debug_write_enable),
        .register_offset(pending_addr[3:0]), .write_data(pending_wdata), .read_data(debug_read_data),
        .debug_value(debug_value)
    );
    timer_mmio timer_instance (
        .clk(clk), .reset(reset), .retire_tick(retire_tick), .read_enable(timer_read_enable),
        .write_enable(timer_write_enable), .register_offset(pending_addr[3:0]), .write_data(pending_wdata),
        .read_data(timer_read_data), .timer_counter(timer_counter), .timer_compare(timer_compare),
        .timer_control(timer_control)
    );
    gpio_mmio gpio_instance (
        .clk(clk), .reset(reset), .read_enable(gpio_read_enable), .write_enable(gpio_write_enable),
        .register_offset(pending_addr[3:0]), .write_data(pending_wdata), .gpio_input(gpio_input),
        .read_data(gpio_read_data), .gpio_output(gpio_output), .gpio_direction(gpio_direction)
    );

    always_comb begin
        pending_in_reserved_mmio = ((pending_addr >= STM32_BASE) && (pending_addr <= STM32_LAST));
        pending_rom = 1'b0;
        pending_ram = 1'b0;
        pending_uart = 1'b0;
        pending_timer = 1'b0;
        pending_gpio = 1'b0;
        pending_debug = 1'b0;
        pending_fault = BUS_FAULT_NONE;
        // Alignment is intentionally first, before range truncation/decode.
        if (pending_addr[1:0] != 2'b00) begin
            pending_fault = BUS_FAULT_MISALIGNED;
        end else if ((pending_addr >= ROM_BASE) && (pending_addr <= ROM_LAST)) begin
            pending_rom = 1'b1;
            if (pending_access == BUS_WRITE) pending_fault = BUS_FAULT_READ_ONLY;
        end else if ((pending_addr >= RAM_BASE) && (pending_addr <= RAM_LAST)) begin
            pending_ram = 1'b1;
            if (pending_access == BUS_FETCH) pending_fault = BUS_FAULT_NON_EXECUTABLE;
        end else if ((pending_addr >= UART_BASE) && (pending_addr <= UART_LAST)) begin
            pending_uart = 1'b1;
            if (pending_access == BUS_FETCH) pending_fault = BUS_FAULT_NON_EXECUTABLE;
        end else if ((pending_addr >= TIMER_BASE) && (pending_addr <= TIMER_LAST)) begin
            pending_timer = 1'b1;
            if (pending_access == BUS_FETCH) pending_fault = BUS_FAULT_NON_EXECUTABLE;
        end else if ((pending_addr >= GPIO_BASE) && (pending_addr <= GPIO_LAST)) begin
            pending_gpio = 1'b1;
            if (pending_access == BUS_FETCH) pending_fault = BUS_FAULT_NON_EXECUTABLE;
        end else if ((pending_addr >= DEBUG_BASE) && (pending_addr <= DEBUG_LAST)) begin
            pending_debug = 1'b1;
            if (pending_access == BUS_FETCH) pending_fault = BUS_FAULT_NON_EXECUTABLE;
        end else if ((pending_access == BUS_FETCH) && pending_in_reserved_mmio) begin
            pending_fault = BUS_FAULT_NON_EXECUTABLE;
        end else begin
            pending_fault = BUS_FAULT_UNMAPPED;
        end
    end

    always_comb begin
        rom_read_enable = (state == BUS_MEMORY) && pending_rom && (pending_fault == BUS_FAULT_NONE) &&
                          (pending_access != BUS_WRITE);
        ram_read_enable = (state == BUS_MEMORY) && pending_ram && (pending_fault == BUS_FAULT_NONE) &&
                          (pending_access == BUS_READ);
        ram_write_enable = (state == BUS_MEMORY) && pending_ram && (pending_fault == BUS_FAULT_NONE) &&
                           (pending_access == BUS_WRITE);
        uart_read_enable = (state == BUS_MEMORY) && pending_uart && (pending_fault == BUS_FAULT_NONE) &&
                           (pending_access == BUS_READ);
        uart_write_enable = (state == BUS_MEMORY) && pending_uart && (pending_fault == BUS_FAULT_NONE) &&
                            (pending_access == BUS_WRITE);
        timer_read_enable = (state == BUS_MEMORY) && pending_timer && (pending_fault == BUS_FAULT_NONE) &&
                            (pending_access == BUS_READ);
        timer_write_enable = (state == BUS_MEMORY) && pending_timer && (pending_fault == BUS_FAULT_NONE) &&
                             (pending_access == BUS_WRITE);
        gpio_read_enable = (state == BUS_MEMORY) && pending_gpio && (pending_fault == BUS_FAULT_NONE) &&
                           (pending_access == BUS_READ);
        gpio_write_enable = (state == BUS_MEMORY) && pending_gpio && (pending_fault == BUS_FAULT_NONE) &&
                            (pending_access == BUS_WRITE);
        debug_read_enable = (state == BUS_MEMORY) && pending_debug && (pending_fault == BUS_FAULT_NONE) &&
                            (pending_access == BUS_READ);
        debug_write_enable = (state == BUS_MEMORY) && pending_debug && (pending_fault == BUS_FAULT_NONE) &&
                             (pending_access == BUS_WRITE);
        response_ready = (state == BUS_RESPONSE);
        response_fault = BUS_FAULT_NONE;
        if (state == BUS_RESPONSE) response_fault = pending_fault;
        response_rdata = 32'h0000_0000;
        if (state == BUS_RESPONSE && pending_fault == BUS_FAULT_NONE) begin
            if (pending_rom) response_rdata = rom_read_data;
            else if (pending_ram) response_rdata = ram_read_data;
            else if (pending_uart) response_rdata = uart_read_data;
            else if (pending_timer) response_rdata = timer_read_data;
            else if (pending_gpio) response_rdata = gpio_read_data;
            else if (pending_debug) response_rdata = debug_read_data;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= BUS_IDLE;
            pending_access <= BUS_FETCH;
            pending_addr <= 32'h0000_0000;
            pending_wdata <= 32'h0000_0000;
        end else begin
            case (state)
                BUS_IDLE: begin
                    if (request_valid) begin
                        pending_access <= request_access;
                        pending_addr <= request_addr;
                        pending_wdata <= request_wdata;
                        state <= BUS_MEMORY;
                    end
                end
                BUS_MEMORY: state <= BUS_RESPONSE;
                BUS_RESPONSE: state <= BUS_IDLE;
                default: state <= BUS_IDLE;
            endcase
        end
    end
endmodule

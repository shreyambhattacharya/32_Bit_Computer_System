IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator
PYTHON ?= python
BUILD_DIR := build
GENERATED_DIR := $(BUILD_DIR)/generated

CORE_SOURCES := include/mini32_pkg.sv \
	core/alu.sv \
	core/register_file.sv \
	core/immediate_generator.sv \
	core/decoder.sv \
	core/control_unit.sv \
	core/cpu_core.sv
MEMORY_SOURCES := memory/rom.sv memory/ram.sv
PERIPHERAL_SOURCES := peripherals/uart_mmio.sv peripherals/timer_mmio.sv peripherals/gpio_mmio.sv peripherals/debug_mmio.sv
BUS_SOURCES := bus/system_bus.sv
PHY_SOURCES := phy/uart_tx_phy.sv
PLATFORM_SOURCES := platform/uart_tx_fifo.sv platform/reset_sync.sv
TOP_SOURCES := top/mini32_system.sv top/mini32_fpga_platform.sv
BOARD_SOURCES := ../fpga/tang_nano_20k/src/tang_nano_20k_top.sv
BOARD_ROM := ../fpga/tang_nano_20k/rom/fpga_bringup.memh
FPGA_ROM_CHECK := ../fpga/tang_nano_20k/tools/check_bringup_rom.py
BOARD_SIM_CHECK := ../fpga/tang_nano_20k/tools/check_board_simulator.py
RTL_SOURCES := $(CORE_SOURCES) $(MEMORY_SOURCES) $(PERIPHERAL_SOURCES) $(BUS_SOURCES) $(PHY_SOURCES) $(PLATFORM_SOURCES) $(TOP_SOURCES)
TESTBENCHES := tb_alu tb_register_file tb_immediate_generator tb_decoder tb_control_unit tb_cpu_core tb_rom tb_ram tb_uart_mmio tb_timer_mmio tb_gpio_mmio tb_debug_mmio tb_system_bus tb_mini32_system tb_uart_tx_phy tb_uart_tx_fifo tb_reset_sync tb_mini32_fpga_platform_uart tb_mini32_fpga_platform_gpio
BOARD_TESTBENCH := tb_tang_nano_20k_top
SYSTEM_IMAGES := $(GENERATED_DIR)/memory_roundtrip.memh $(GENERATED_DIR)/rtl_system_smoke.memh $(GENERATED_DIR)/rtl_system_fault.memh $(GENERATED_DIR)/hello_uart.memh $(GENERATED_DIR)/debug_demo.memh $(GENERATED_DIR)/peripheral_readback.memh $(GENERATED_DIR)/gpio_demo.memh $(GENERATED_DIR)/timer_demo.memh
SYSTEM_BINARIES := $(SYSTEM_IMAGES:.memh=.bin)

.PHONY: lint test clean test_converter check_fpga_rom board_test_status board_test_compat differential_trace $(TESTBENCHES) $(BOARD_TESTBENCH)
.SECONDARY: $(SYSTEM_BINARIES)

lint:
	$(VERILATOR) --lint-only -Wall --top-module mini32_fpga_platform $(RTL_SOURCES)

test: test_converter check_fpga_rom $(TESTBENCHES) board_test_status

test_converter:
	$(PYTHON) -m unittest discover -s tests -p "test_*.py"

check_fpga_rom:
	$(PYTHON) $(FPGA_ROM_CHECK)

board_test_status:
	$(PYTHON) $(BOARD_SIM_CHECK) $(IVERILOG)

board_test_compat:
	$(PYTHON) $(BOARD_SIM_CHECK) --require-supported $(IVERILOG)

# Build the generic runner; the external Python harness supplies ROM_INIT_FILE
# at elaboration time and consumes only its MINI32_TRACE JSONL records.
differential_trace: $(BUILD_DIR)/tb_differential_trace

$(BUILD_DIR)/tb_differential_trace: $(RTL_SOURCES) tb/tb_differential_trace.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_differential_trace -o $@ $(RTL_SOURCES) tb/tb_differential_trace.sv

$(TESTBENCHES): %: $(BUILD_DIR)/%
	$(VVP) $<

$(BOARD_TESTBENCH): %: $(BUILD_DIR)/%
	$(VVP) $<

$(BUILD_DIR)/tb_alu: $(RTL_SOURCES) tb/tb_alu.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_alu -o $@ $^

$(BUILD_DIR)/tb_register_file: $(RTL_SOURCES) tb/tb_register_file.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_register_file -o $@ $^

$(BUILD_DIR)/tb_immediate_generator: $(RTL_SOURCES) tb/tb_immediate_generator.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_immediate_generator -o $@ $^

$(BUILD_DIR)/tb_decoder: $(RTL_SOURCES) tb/tb_decoder.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_decoder -o $@ $^

$(BUILD_DIR)/tb_control_unit: $(RTL_SOURCES) tb/tb_control_unit.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_control_unit -o $@ $^

$(BUILD_DIR)/tb_cpu_core: $(RTL_SOURCES) tb/mini32_tb_pkg.sv tb/tb_cpu_core.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_cpu_core -o $@ $^

$(BUILD_DIR)/tb_rom: $(RTL_SOURCES) tb/tb_rom.sv $(GENERATED_DIR)/memory_roundtrip.memh | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_rom -o $@ $(RTL_SOURCES) tb/tb_rom.sv

$(BUILD_DIR)/tb_ram: $(RTL_SOURCES) tb/tb_ram.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_ram -o $@ $^

$(BUILD_DIR)/tb_uart_mmio: $(RTL_SOURCES) tb/tb_uart_mmio.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_uart_mmio -o $@ $^

$(BUILD_DIR)/tb_timer_mmio: $(RTL_SOURCES) tb/tb_timer_mmio.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_timer_mmio -o $@ $^

$(BUILD_DIR)/tb_gpio_mmio: $(RTL_SOURCES) tb/tb_gpio_mmio.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_gpio_mmio -o $@ $^

$(BUILD_DIR)/tb_debug_mmio: $(RTL_SOURCES) tb/tb_debug_mmio.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_debug_mmio -o $@ $^

$(BUILD_DIR)/tb_system_bus: $(RTL_SOURCES) tb/tb_system_bus.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_system_bus -o $@ $^

$(BUILD_DIR)/tb_mini32_system: $(RTL_SOURCES) tb/tb_mini32_system.sv $(SYSTEM_IMAGES) | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_mini32_system -o $@ $(RTL_SOURCES) tb/tb_mini32_system.sv

$(BUILD_DIR)/tb_uart_tx_phy: $(RTL_SOURCES) tb/tb_uart_tx_phy.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_uart_tx_phy -o $@ $(RTL_SOURCES) tb/tb_uart_tx_phy.sv

$(BUILD_DIR)/tb_uart_tx_fifo: $(RTL_SOURCES) tb/tb_uart_tx_fifo.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_uart_tx_fifo -o $@ $(RTL_SOURCES) tb/tb_uart_tx_fifo.sv

$(BUILD_DIR)/tb_reset_sync: $(RTL_SOURCES) tb/tb_reset_sync.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_reset_sync -o $@ $(RTL_SOURCES) tb/tb_reset_sync.sv

$(BUILD_DIR)/tb_mini32_fpga_platform_uart: $(RTL_SOURCES) tb/tb_mini32_fpga_platform_uart.sv $(GENERATED_DIR)/hello_uart.memh | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_mini32_fpga_platform_uart -o $@ $(RTL_SOURCES) tb/tb_mini32_fpga_platform_uart.sv

$(BUILD_DIR)/tb_mini32_fpga_platform_gpio: $(RTL_SOURCES) tb/tb_mini32_fpga_platform_gpio.sv $(GENERATED_DIR)/gpio_demo.memh | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_mini32_fpga_platform_gpio -o $@ $(RTL_SOURCES) tb/tb_mini32_fpga_platform_gpio.sv

$(BUILD_DIR)/tb_tang_nano_20k_top: $(RTL_SOURCES) $(BOARD_SOURCES) tb/tb_tang_nano_20k_top.sv $(BOARD_ROM) board_test_compat | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_tang_nano_20k_top -o $@ $(RTL_SOURCES) $(BOARD_SOURCES) tb/tb_tang_nano_20k_top.sv

$(BUILD_DIR):
	$(PYTHON) -c "from pathlib import Path; Path('$(BUILD_DIR)').mkdir(exist_ok=True)"

$(GENERATED_DIR): | $(BUILD_DIR)
	$(PYTHON) -c "from pathlib import Path; Path('$(GENERATED_DIR)').mkdir(parents=True, exist_ok=True)"

$(GENERATED_DIR)/%.bin: ../programs/%.asm | $(GENERATED_DIR)
	$(PYTHON) ../assembler/assembler.py $< -o $@

$(GENERATED_DIR)/%.memh: $(GENERATED_DIR)/%.bin tools/bin_to_mem.py
	$(PYTHON) tools/bin_to_mem.py $< $@

clean:
	$(PYTHON) -c "import shutil; shutil.rmtree('$(BUILD_DIR)', ignore_errors=True)"

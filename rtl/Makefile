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
BUS_SOURCES := bus/system_bus.sv
TOP_SOURCES := top/mini32_system.sv
RTL_SOURCES := $(CORE_SOURCES) $(MEMORY_SOURCES) $(BUS_SOURCES) $(TOP_SOURCES)
TESTBENCHES := tb_alu tb_register_file tb_immediate_generator tb_decoder tb_control_unit tb_cpu_core tb_rom tb_ram tb_system_bus tb_mini32_system
SYSTEM_IMAGES := $(GENERATED_DIR)/memory_roundtrip.memh $(GENERATED_DIR)/rtl_system_smoke.memh $(GENERATED_DIR)/rtl_system_fault.memh

.PHONY: lint test clean test_converter differential_trace $(TESTBENCHES)

lint:
	$(VERILATOR) --lint-only -Wall --top-module mini32_system $(RTL_SOURCES)

test: test_converter $(TESTBENCHES)

test_converter:
	$(PYTHON) -m unittest discover -s tests -p "test_*.py"

# Build the generic runner; the external Python harness supplies ROM_INIT_FILE
# at elaboration time and consumes only its MINI32_TRACE JSONL records.
differential_trace: $(BUILD_DIR)/tb_differential_trace

$(BUILD_DIR)/tb_differential_trace: $(RTL_SOURCES) tb/tb_differential_trace.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_differential_trace -o $@ $(RTL_SOURCES) tb/tb_differential_trace.sv

$(TESTBENCHES): %: $(BUILD_DIR)/%
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

$(BUILD_DIR)/tb_system_bus: $(RTL_SOURCES) tb/tb_system_bus.sv | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_system_bus -o $@ $^

$(BUILD_DIR)/tb_mini32_system: $(RTL_SOURCES) tb/tb_mini32_system.sv $(SYSTEM_IMAGES) | $(BUILD_DIR)
	$(IVERILOG) -g2012 -s tb_mini32_system -o $@ $(RTL_SOURCES) tb/tb_mini32_system.sv

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

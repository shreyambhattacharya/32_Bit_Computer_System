IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator
PYTHON ?= python
BUILD_DIR := build

RTL_SOURCES := include/mini32_pkg.sv \
	core/alu.sv \
	core/register_file.sv \
	core/immediate_generator.sv \
	core/decoder.sv \
	core/control_unit.sv \
	core/cpu_core.sv
TESTBENCHES := tb_alu tb_register_file tb_immediate_generator tb_decoder tb_control_unit tb_cpu_core

.PHONY: lint test clean $(TESTBENCHES)

lint:
	$(VERILATOR) --lint-only -Wall --top-module cpu_core $(RTL_SOURCES)

test: $(TESTBENCHES)

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

$(BUILD_DIR):
	$(PYTHON) -c "from pathlib import Path; Path('$(BUILD_DIR)').mkdir(exist_ok=True)"

clean:
	$(PYTHON) -c "import shutil; shutil.rmtree('$(BUILD_DIR)', ignore_errors=True)"

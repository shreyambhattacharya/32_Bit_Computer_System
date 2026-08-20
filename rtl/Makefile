IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator
BUILD_DIR := build

RTL_SOURCES := include/mini32_pkg.sv \
	core/alu.sv \
	core/register_file.sv \
	core/immediate_generator.sv \
	core/decoder.sv \
	core/control_unit.sv
TESTBENCHES := tb_alu tb_register_file tb_immediate_generator tb_decoder tb_control_unit

.PHONY: lint test clean $(TESTBENCHES)

lint:
	$(VERILATOR) --lint-only -Wall -Wno-fatal $(RTL_SOURCES)

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

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)

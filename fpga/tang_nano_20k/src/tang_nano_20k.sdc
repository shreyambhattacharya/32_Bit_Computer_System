# Sipeed Tang Nano 20K 27 MHz crystal clock.
create_clock -name clk_27M -period 37.037 -waveform {0 18.518} [get_ports {clk}]

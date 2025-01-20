# FPGA_BLDC_FOC

## General information

This repository contains a field-oriented control (FOC) for a 6-phase BLDC-motor. It uses the KDEE FPGA-board built by Christian Nöding in 2014.
It runs on an Altera/Intel Cyclone III FPGA, the EP3C40F484C6 under Quartus 13.1. Newer versions of Quartus do not support the Cyclone III.
Anyway, the VHDL-logic can be ported to newer models like the Cyclone 10LP without problems as it does not use any specific functions of the Cyclone III.

## Special information

#!/bin/bash
# Runs the testbench with the three packet widths and several random seeds.
# The packet width is a parameter of the DUT, so it can only change between
# compilations: this script recompiles for each width.
#
# Usage: ./run.sh [seeds_per_width] [plusargs...]
#   ./run.sh                      3 seeds for each width (16, 32, 64)
#   ./run.sh 5 +PCT_BCAST=100     5 seeds, broadcast only
#   WIDTHS="32" ./run.sh 1        only 32 bits
#   RANDOM_WIDTH=1 ./run.sh 1     one width picked at random

SEEDS=${1:-3}
shift
WIDTHS=${WIDTHS:-"16 32 64"}
if [ -n "$RANDOM_WIDTH" ]; then
    ALL=(16 32 64)
    WIDTHS=${ALL[$((RANDOM % 3))]}
fi

for W in $WIDTHS; do
    vcs -sverilog -full64 -timescale=1ns/1ps -pvalue+testbench.p_width=$W \
        testbench.sv -o simv_w$W -l comp_w$W.log > /dev/null || { echo "Error de compilacion con ancho $W (ver comp_w$W.log)"; exit 1; }
    for i in $(seq 1 $SEEDS); do
        SEED=$RANDOM
        ./simv_w$W +ntb_random_seed=$SEED "$@" -l run_w${W}_seed${SEED}.log > /dev/null
        echo "ancho=$W semilla=$SEED: $(grep '\[TEST\] \(APROBADO\|FALLIDO\)' run_w${W}_seed${SEED}.log)"
    done
done

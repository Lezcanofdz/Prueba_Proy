#!/bin/bash
# Compiles and runs the testbench following the 4 steps required by the
# course (incremental compile + coverage + Verdi), for the three packet
# widths and several random seeds. The packet width is a parameter of the
# DUT, so it can only change between compilations: this script recompiles
# (step 2) once per width, then runs (step 3) once per seed.
#
# Usage: ./run.sh [seeds_per_width] [plusargs...]
#   ./run.sh                      3 seeds for each width (16, 32, 64)
#   ./run.sh 5 +PCT_BCAST=100     5 seeds, broadcast only
#   WIDTHS="32" ./run.sh 1        only 32 bits
#   RANDOM_WIDTH=1 ./run.sh 1     one width picked at random
#   OPEN_VERDI=1 ./run.sh 1       also opens Verdi (step 4) after each width

SEEDS=${1:-3}
shift
WIDTHS=${WIDTHS:-"16 32 64"}
if [ -n "$RANDOM_WIDTH" ]; then
    ALL=(16 32 64)
    WIDTHS=${ALL[$((RANDOM % 3))]}
fi

# --- Paso 1: limpieza -------------------------------------------------
# Borra todo lo que no sea codigo fuente (.sv, .sh, .gp): ejecutables,
# logs, directorios de cobertura (*.vdb), csrc, DVEfiles, etc. de corridas
# anteriores, para que cada compilacion arranque limpia.
echo "[RUN] Limpiando artefactos de corridas anteriores..."
find . -maxdepth 1 -type f ! -name '*.sv' ! -name '*.sh' ! -name '*.gp' -delete
rm -rf csrc *.vdb *.daidir DVEfiles ucli.key vc_hdrs.h simv* salida* inter.vpd novas.* verdiLog *.fsdb

for W in $WIDTHS; do
    OUT="salida_w$W"

    # --- Paso 2: compilacion -------------------------------------------
    echo "[RUN] Compilando ancho=$W ..."
    vcs -Mupdate -sverilog -full64 -pvalue+testbench.p_width=$W \
        testbench.sv -o $OUT \
        -kdb -lca -debug_acc+all -debug_region+cell+encrypt \
        -l comp_w$W.log +lint=TFIPC-L \
        -cm line+tgl+cond+fsm+branch+assert \
        -P ${VERDI_HOME}/share/PLI/VCS/linux64/verdi.tab \
        > /dev/null \
        || { echo "Error de compilacion con ancho $W (ver comp_w$W.log)"; exit 1; }

    # --- Paso 3: simulacion (una corrida por semilla) -------------------
    for i in $(seq 1 $SEEDS); do
        SEED=$RANDOM
        ./$OUT -cm line+tgl+cond+fsm+branch+assert \
            +ntb_random_seed=$SEED "$@" \
            -l run_w${W}_seed${SEED}.log > /dev/null
        echo "ancho=$W semilla=$SEED: $(grep '\[TEST\] RESULTADO' run_w${W}_seed${SEED}.log)"
    done

    # --- Paso 4: cobertura en Verdi (opcional, interfaz grafica) --------
    if [ -n "$OPEN_VERDI" ]; then
        echo "[RUN] Abriendo Verdi con la cobertura de ancho=$W ..."
        verdi -cov -covdir ${OUT}.vdb &
    fi
done

echo "[RUN] Listo. Para ver la cobertura de un ancho especifico mas tarde:"
echo "      verdi -cov -covdir salida_w<ancho>.vdb &"

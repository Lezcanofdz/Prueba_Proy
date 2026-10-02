#!/bin/bash
# Compila UNA sola vez (el ancho del paquete y la cantidad de terminales se
# definen en testbench.sv: p_width / p_drvs) y corre los casos que dejes
# descomentados en la seccion de abajo.
#
# Semilla: por defecto se genera una al azar en cada ejecucion del script
# (misma semilla para todos los casos que corras esa vez, para poder
# compararlos). Si queres fijarla vos:
#   SEED=12345 ./run.sh

SEED=${SEED:-$RANDOM}

# --- Limpieza -----------------------------------------------------------
echo "[RUN] Limpiando artefactos de corridas anteriores..."
find . -maxdepth 1 -type f ! -name '*.sv' ! -name '*.sh' ! -name '*.gp' -delete
rm -rf csrc *.vdb *.daidir DVEfiles ucli.key vc_hdrs.h simv* salida* inter.vpd novas.* verdiLog *.fsdb

# --- Compilacion (una sola vez) ------------------------------------------
echo "[RUN] Compilando ..."
vcs -Mupdate -sverilog -full64 \
    testbench.sv -o salida \
    -kdb -lca -debug_acc+all -debug_region+cell+encrypt \
    -l comp.log +lint=TFIPC-L \
    -cm line+tgl+cond+fsm+branch+assert \
    -P ${VERDI_HOME}/share/PLI/VCS/linux64/verdi.tab \
    > /dev/null \
    || { echo "Error de compilacion (ver comp.log)"; exit 1; }

# --- Funcion que corre un caso -------------------------------------------
run_case () {
    local case_name=$1
    shift
    echo "[RUN] ---- Caso: $case_name (semilla=$SEED) ----"
    ./salida -cm line+tgl+cond+fsm+branch+assert \
        +ntb_random_seed=$SEED +TEST_CASE=$case_name "$@" \
        -l run_${case_name}_seed${SEED}.log > /dev/null
    grep '\[TEST\] RESULTADO' run_${case_name}_seed${SEED}.log
    if [ "$case_name" == "UNDERFLOW" ]; then
        if grep -q "FIFO vacia" run_${case_name}_seed${SEED}.log; then
            echo "         -> OJO: se detecto un intento de underflow real (ver log)"
        else
            echo "         -> OK: nunca se intento sacar un dato de una FIFO vacia"
        fi
    fi
}

# ==========================================================================
# Descomenta los casos que quieras correr en esta ejecucion
# ==========================================================================

 run_case GENERAL                 # Caso general: valores aleatorizados
 run_case BCAST                 # Caso de esquina 1: todo a broadcast
 run_case INVALID                # Caso de esquina 2: todo a direcciones invalidas
 run_case OVERFLOW               # Caso de esquina 3: overflow de la FIFO
 run_case UNDERFLOW              # Caso de esquina 4: underflow de la FIFO

echo "[RUN] Listo. Para ver la cobertura:"
echo "      verdi -cov -covdir salida.vdb &"

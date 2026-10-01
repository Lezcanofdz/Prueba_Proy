#!/bin/bash
# Compiles and runs the testbench following the 4 steps required by the
# course (clean + incremental compile with coverage + run + Verdi), and lets
# the user pick the test scenario from a menu. The packet width (and the
# broadcast ID) are parameters of the DUT, so they can only change between
# compilations: the script compiles once per width and reuses the executable
# for every scenario and seed.
#
# Usage:
#   ./run.sh                          interactive menu
#   ./run.sh 3                        runs scenario 3 directly (no menu)
#   ./run.sh 10                       runs every scenario (regression)
#   SEEDS=5 WIDTHS="32" ./run.sh 2    5 seeds, only 32 bits, scenario 2
#   RANDOM_WIDTH=1 ./run.sh 1         one width picked at random
#   OPEN_VERDI=1 ./run.sh 1           opens Verdi with the coverage at the end

# Scenario table: name, description, plusargs, broadcast ID for the DUT
# (empty = default 255) and expected result
NAME[1]="base";              DESC[1]="Base (valores por defecto)"
ARGS[1]="";                  BCAST[1]=""
EXPECT[1]="Mezcla ~70/15/15 en [SB], perdidos=0, APROBADO"

NAME[2]="solo_unicast";      DESC[2]="Solo unicast"
ARGS[2]="+PCT_BCAST=0 +PCT_INV=0"; BCAST[2]=""
EXPECT[2]="broadcast=0 invalidos=0, recepciones_esperadas = total de paquetes"

NAME[3]="solo_broadcast";    DESC[3]="Solo broadcast"
ARGS[3]="+PCT_BCAST=100 +PCT_INV=0"; BCAST[3]=""
EXPECT[3]="recepciones_esperadas = 3 x total de paquetes"

NAME[4]="solo_invalidos";    DESC[4]="Solo direcciones invalidas"
ARGS[4]="+PCT_BCAST=0 +PCT_INV=100"; BCAST[4]=""
EXPECT[4]="recepciones_esperadas=0, correctos=0, el bus no se traba, APROBADO"

NAME[5]="max_contencion";    DESC[5]="Maxima contencion (retardo 0)"
ARGS[5]="+DLY_MIN=0 +DLY_MAX=0"; BCAST[5]=""
EXPECT[5]="Retardo promedio cerca del maximo (~770 ns con 16 bits)"

NAME[6]="trafico_lento";     DESC[6]="Trafico lento (retardo 100..500)"
ARGS[6]="+DLY_MIN=100 +DLY_MAX=500"; BCAST[6]=""
EXPECT[6]="Retardos cerca del minimo (~190 ns con 16 bits)"

NAME[7]="misma_cantidad";    DESC[7]="Misma cantidad por terminal (10)"
ARGS[7]="+TX_MIN=10 +TX_MAX=10"; BCAST[7]=""
EXPECT[7]="Las cuatro terminales con 10 transacciones"

NAME[8]="terminales_vacias"; DESC[8]="Terminales sin trafico (0..3)"
ARGS[8]="+TX_MIN=0 +TX_MAX=3"; BCAST[8]=""
EXPECT[8]="Alguna terminal con 0 transacciones, el resto rota normal"

NAME[9]="defecto_broadcast"; DESC[9]="Defecto del broadcast (p_bcast=254)"
ARGS[9]="+PCT_BCAST=50";     BCAST[9]="254"
EXPECT[9]="FALLIDO: perdidos = 3 x broadcast. El DUT ignora el parametro y solo reconoce 255"

N_SCEN=9
OPT_ALL=10
OPT_CUSTOM=11

SEEDS=${SEEDS:-3}
WIDTHS=${WIDTHS:-"16 32 64"}
SUMMARY=()

show_menu() {
    echo
    echo "================ Pruebas del Proyecto I ================"
    for i in $(seq 1 $N_SCEN); do
        printf "  %2d) %s\n" $i "${DESC[$i]}"
    done
    printf "  %2d) %s\n" $OPT_ALL "Todas las anteriores (regresion)"
    printf "  %2d) %s\n" $OPT_CUSTOM "Personalizada (escribir plusargs)"
    printf "  %2d) %s\n" 0 "Salir"
    echo "========================================================"
}

# Compiles once for a width and broadcast ID; reuses the executable if it already exists
compile() {
    local W=$1 BC=$2
    OUT="salida_w$W${BC:+_bc$BC}"
    [ -x "$OUT" ] && return 0
    echo "[RUN] Compilando ancho=$W${BC:+ broadcast=$BC} ..."
    vcs -Mupdate -Mdir=csrc_$OUT -sverilog -full64 -pvalue+testbench.p_width=$W \
        ${BC:+-pvalue+testbench.p_bcast=$BC} \
        testbench.sv -o $OUT \
        -kdb -lca -debug_acc+all -debug_region+cell+encrypt \
        -l comp_$OUT.log +lint=TFIPC-L \
        -cm line+tgl+cond+fsm+branch+assert \
        ${VERDI_HOME}/share/PLI/VCS/linux64/verdi.tab \
        > /dev/null \
        || { echo "Error de compilacion de $OUT (ver comp_$OUT.log)"; exit 1; }
}

# Runs one scenario (index or custom) for every width and seed
run_scenario() {
    local IDX=$1 W SEED LOG CSV RES
    local NM=${NAME[$IDX]} PA=${ARGS[$IDX]} BC=${BCAST[$IDX]}
    echo
    echo "[RUN] Escenario: ${DESC[$IDX]}"
    echo "[RUN] Esperado:  ${EXPECT[$IDX]}"
    for W in $WIDTHS; do
        compile $W "$BC"
        for i in $(seq 1 $SEEDS); do
            SEED=$RANDOM
            LOG="run_${NM}_w${W}_seed${SEED}.log"
            ./$OUT -cm line+tgl+cond+fsm+branch+assert -cm_name ${NM}_w${W}_s${SEED} \
                +ntb_random_seed=$SEED $PA \
                -l $LOG > /dev/null
            # Each scenario keeps its own CSV, so runs do not overwrite each other
            CSV="reporte_w${W}_seed${SEED}.csv"
            if [ -f "$CSV" ]; then
                mv "$CSV" "${NM}_w${W}_seed${SEED}.csv"
                CSV="${NM}_w${W}_seed${SEED}.csv"
                if command -v gnuplot > /dev/null && [ -f histograma.gp ] && [ $(wc -l < "$CSV") -gt 1 ]; then
                    gnuplot -e "csv='$CSV'" histograma.gp > /dev/null 2>&1
                fi
            fi
            RES=$(grep -E '\[TEST\] (RESULTADO|APROBADO|FALLIDO)' $LOG | tail -1)
            echo "  ancho=$W semilla=$SEED: ${RES:-sin resultado (ver $LOG)}"
            echo "      $(grep '\[CHK\] correctos' $LOG | tail -1)"
            SUMMARY+=("$(printf '%-20s ancho=%-3s semilla=%-6s %s' "$NM" "$W" "$SEED" "${RES:-sin resultado}")")
        done
    done
}

# --- Seleccion del escenario ------------------------------------------
if [ -n "$1" ]; then
    OPT=$1
    shift
else
    show_menu
    read -p "Elija una opcion: " OPT
    [ "$OPT" = "0" ] && exit 0
    read -p "Anchos a probar [$WIDTHS]: " ANS; WIDTHS=${ANS:-$WIDTHS}
    read -p "Semillas por ancho [$SEEDS]: " ANS; SEEDS=${ANS:-$SEEDS}
fi

if [ -n "$RANDOM_WIDTH" ]; then
    ALL=(16 32 64)
    WIDTHS=${ALL[$((RANDOM % 3))]}
fi

if [ "$OPT" = "$OPT_CUSTOM" ]; then
    read -p "Plusargs (ej. +PCT_BCAST=100 +DLY_MAX=0): " CUSTOM
    NAME[$OPT_CUSTOM]="personalizada"; DESC[$OPT_CUSTOM]="Personalizada: $CUSTOM"
    ARGS[$OPT_CUSTOM]="$CUSTOM"; BCAST[$OPT_CUSTOM]=""
    EXPECT[$OPT_CUSTOM]="Revisar [SB] y [CHK] segun los plusargs elegidos"
elif ! [[ "$OPT" =~ ^[0-9]+$ ]] || [ "$OPT" -lt 1 ] || [ "$OPT" -gt $OPT_CUSTOM ]; then
    echo "Opcion invalida: $OPT"
    exit 1
fi

# --- Paso 1: limpieza -------------------------------------------------
# Borra los artefactos de corridas anteriores (ejecutables, logs, CSV,
# imagenes, directorios de cobertura). Conserva el codigo y los documentos.
echo "[RUN] Limpiando artefactos de corridas anteriores..."
find . -maxdepth 1 -type f ! -name '*.sv' ! -name '*.sh' ! -name '*.gp' \
    ! -name '*.py' ! -name '*.md' ! -name '*.tex' -delete
rm -rf csrc* *.vdb *.daidir DVEfiles ucli.key vc_hdrs.h simv* salida* inter.vpd novas.* verdiLog *.fsdb

# --- Pasos 2 y 3: compilacion y simulacion ----------------------------
if [ "$OPT" = "$OPT_ALL" ]; then
    for i in $(seq 1 $N_SCEN); do run_scenario $i; done
else
    run_scenario $OPT
fi

# --- Resumen ------------------------------------------------------------
echo
echo "======================== Resumen ========================"
for line in "${SUMMARY[@]}"; do echo "  $line"; done
echo "========================================================="

# --- Paso 4: cobertura en Verdi (opcional, interfaz grafica) --------
if [ -n "$OPEN_VERDI" ]; then
    for d in salida_w*.vdb; do
        [ -d "$d" ] && { echo "[RUN] Abriendo Verdi con $d ..."; verdi -cov -covdir "$d" & }
    done
fi

echo "[RUN] Listo. Para ver la cobertura de un ancho especifico mas tarde:"
echo "      verdi -cov -covdir salida_w<ancho>.vdb &"

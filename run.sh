#!/bin/bash
# Compila UNA sola vez y corre los casos sobre un ancho y una semilla.
#
# El ancho y la cantidad de terminales se pueden fijar desde aqui sin editar
# testbench.sv (CAMBIO 4: se mantiene una sola corrida por ancho, a proposito):
#   WIDTH=32 ./run.sh
#   DRVS=4   ./run.sh
#   SEED=12345 ./run.sh
#   CASES="GENERAL SELF" ./run.sh
#   SKIP_COMPILE=1 ./run.sh    (reusa el binario ya compilado)

SEED=${SEED:-$RANDOM}
WIDTH=${WIDTH:-16}
DRVS=${DRVS:-6}

# CAMBIO: se quito UNDERFLOW de la lista (las FIFOs son emuladas por el
# ambiente, asi que no hay condicion de underflow del DUT que verificar).
# CAMBIO 6: se agrego SELF.
CASES=${CASES:-"GENERAL BCAST INVALID SELF OVERFLOW"}

# --- Limpieza -------------------------------------------------------------
# CAMBIO 2: antes era
#   find . -maxdepth 1 -type f ! -name '*.sv' ! -name '*.sh' ! -name '*.gp' -delete
# Eso borra README.md, el .tex del reporte y cualquier archivo no commiteado
# si el script se corre desde la raiz del repo. Ahora es una lista explicita.
echo "[RUN] Limpiando artefactos de corridas anteriores..."
rm -f *.csv *.log *.png *.vpd ucli.key vc_hdrs.h
rm -rf csrc *.vdb *.daidir DVEfiles simv* salida* novas.* verdiLog *.fsdb

# --- Compilacion ----------------------------------------------------------
if [ -z "$SKIP_COMPILE" ]; then
    echo "[RUN] Compilando (p_width=$WIDTH, p_drvs=$DRVS) ..."
    vcs -Mupdate -sverilog -full64 \
        testbench.sv -o salida \
        -pvalue+testbench.p_width=$WIDTH \
        -pvalue+testbench.p_drvs=$DRVS \
        -kdb -lca -debug_acc+all -debug_region+cell+encrypt \
        -l comp.log +lint=TFIPC-L \
        -cm line+tgl+cond+fsm+branch+assert \
        -P ${VERDI_HOME}/share/PLI/VCS/linux64/verdi.tab \
        > /dev/null \
        || { echo "Error de compilacion (ver comp.log)"; exit 1; }
fi

# --- Funcion que corre un caso --------------------------------------------
run_case () {
    local case_name=$1
    shift

    local log="run_${case_name}_w${WIDTH}_seed${SEED}.log"

    printf "[RUN] %-10s " "$case_name"

    ./salida -cm line+tgl+cond+fsm+branch+assert \
        +ntb_random_seed=$SEED +TEST_CASE=$case_name "$@" \
        -l $log > /dev/null

    local res
    res=$(grep -o 'RESULTADO: [A-Z]*' $log | head -1)
    echo -n "${res:-SIN RESULTADO}"

    # CAMBIO 7: el checker ahora imprime los retardos, asi que se muestran
    # en el resumen de cada caso sin tener que abrir el CSV.
    local ret
    ret=$(grep -o 'retardo min=.*' $log | head -1)
    [ -n "$ret" ] && echo -n "  | $ret"
    echo

    if [ "$case_name" == "OVERFLOW" ]; then
        grep "ocupacion maxima" $log | sed 's/^/         -> /'
    fi
}

# --- Corridas -------------------------------------------------------------
echo "[RUN] ===== p_width=$WIDTH  p_drvs=$DRVS  semilla=$SEED ====="

for C in $CASES; do
    case $C in
        # CAMBIO 3: +NUM_TX=0 activa el modo por terminal del generador
        # (cada terminal sortea su cantidad entre tx_min y tx_max).
        # Sin esto la rama de tx_min/tx_max nunca se ejecuta.
        GENERAL)  run_case GENERAL  +NUM_TX=0 ;;
        BCAST)    run_case BCAST    +NUM_TX=0 ;;
        INVALID)  run_case INVALID  +NUM_TX=0 ;;
        SELF)     run_case SELF     +NUM_TX=0 ;;
        # OVERFLOW usa sus propios valores dirigidos (20 tx, depth 2)
        OVERFLOW) run_case OVERFLOW ;;
        *)        run_case $C ;;
    esac
done

# --- Histogramas ----------------------------------------------------------
# CAMBIO 1: se usa histograma.gp (el que ya funcionaba), no histograma.sh.
# El .gp calcula el ancho del bin con stats sobre los datos reales y lo
# redondea a multiplo de 10 ns (periodo del reloj), asi que sirve para
# cualquier ancho de paquete sin tocar nada.
echo "[RUN] Generando histogramas..."

for f in reporte_*_w${WIDTH}_seed${SEED}.csv; do
    [ -f "$f" ] || continue
    # Saltar los CSV sin datos (INVALID y SELF no tienen recepciones)
    [ "$(wc -l < "$f")" -gt 1 ] || { echo "[RUN] $f sin datos, se omite"; continue; }
    gnuplot -e "csvfile='$f'" histograma.gp
done

echo "[RUN] Listo (p_width=$WIDTH, semilla=$SEED)."
echo "      Logs:        run_<caso>_w${WIDTH}_seed${SEED}.log"
echo "      CSV:         reporte_<caso>_w${WIDTH}_seed${SEED}.csv"
echo "      Histogramas: reporte_<caso>_w${WIDTH}_seed${SEED}_histograma.png"
echo "      Cobertura:   verdi -cov -covdir salida.vdb &"

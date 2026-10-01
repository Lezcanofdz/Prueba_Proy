#!/bin/bash

# Archivo CSV original
CSV_FILE="reporte.csv"
PLOT_SCRIPT="grafico_histograma.gnuplot"
OUTPUT_IMAGE="histograma.png"

# Verificar si el archivo CSV existe
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: No se encontró el archivo $CSV_FILE"
    exit 1
fi

# Crear el archivo de script para GNUplot
cat <<EOL > $PLOT_SCRIPT
set terminal png size 800,600
set output '$OUTPUT_IMAGE'
set datafile separator ","

# Configuración del histograma
set style data histogram
set style fill solid 1.0 border -1  # Ajuste para un relleno sólido en el histograma
set boxwidth 5000  # Define el ancho del bin (intervalo) en 1000 microsegundos

# Ajustes para los ejes
set xlabel "Latencia"  # El eje X representa la latencia en microsegundos
set ylabel "Frecuencia"  # El eje Y representa la frecuencia

# Ajustar el rango del eje X para mostrar latencias entre 0 y 8000
set xrange [0:40000]

# Ajustar los tics del eje X para que coincidan con los intervalos
set xtics 5000  # Cambiar los intervalos del eje X a 1000 microsegundos

# Rotar los tics del eje X para que no se solapen
set xtics rotate by -45

# Ajustar los números en el eje Y
set format y "%.0f"    # Números sin decimales en el eje Y
set yrange [0:*]       # Asegurar que el eje Y empiece desde 0

set title "Histograma de Frecuencia vs Latencia"

# Graficar el histograma usando la columna de latencia (columna 7 en el CSV)
# Usamos la función 'bin' para agrupar las latencias en intervalos de 1000 microsegundos
binwidth = 5000
bin(x,width) = width * floor(x / width)
plot "$CSV_FILE" using (bin(\$7,binwidth)):(1.0) smooth freq with boxes title "Frecuencia por intervalo"
EOL

# Ejecutar GNUplot con el script generado
gnuplot $PLOT_SCRIPT

# Verificar si la imagen fue generada
if [ -f "$OUTPUT_IMAGE" ]; then
    echo "Histograma generado correctamente: $OUTPUT_IMAGE"
else
    echo "Error: No se pudo generar el histograma."
    exit 1
fi

# Limpiar archivos temporales si es necesario
rm -f $PLOT_SCRIPT

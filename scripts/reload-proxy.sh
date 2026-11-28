#!/bin/sh
# Hook de certbot: se ejecuta despues de cada renovacion exitosa.
#
# certbot reemplaza los archivos del certificado, pero nginx los lee una sola vez al arrancar, asi
# que seguiria sirviendo el viejo hasta que alguien lo reinicie. Un reload le hace releer la config
# y los certificados sin cortar ninguna conexion.
#
# Se instala en la VM, no lo usa el stack:
#   sudo cp scripts/reload-proxy.sh /etc/letsencrypt/renewal-hooks/deploy/reload-proxy.sh
#   sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-proxy.sh

set -e

container=$(docker ps -q -f name=snippet-searcher_proxy | head -n 1)

if [ -z "$container" ]; then
    echo "reload-proxy: no hay contenedor del proxy corriendo, no hay nada que recargar"
    exit 0
fi

docker exec "$container" nginx -s reload
echo "reload-proxy: nginx recargado"

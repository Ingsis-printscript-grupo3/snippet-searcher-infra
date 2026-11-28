# snippet-searcher-infra

Infraestructura de Snippet Searcher: cómo se despliega el sistema entero en las VMs de dev y prod con
Docker Swarm. El código de cada servicio vive en su propio repo; acá solo está lo que los junta.

## Servicios

| Servicio | Repo | Imagen |
| --- | --- | --- |
| snippet-service | `snippet-service` | `ghcr.io/ingsis-printscript-grupo3/snippet-service` |
| permission-service | `permission-service` | `ghcr.io/ingsis-printscript-grupo3/permission-service` |
| printscript-service | `printscript-service` | `ghcr.io/ingsis-printscript-grupo3/printscript-service` |
| asset-service (bucket) | de la cátedra | `ghcr.io/austral-ingsis/snippet-asset-service` |

`snippet-service` y `permission-service` tienen cada uno su Postgres. El asset-service guarda en Azurite.

Cada servicio publica su imagen en cada merge a `dev` o `prod` con dos tags: el nombre de la rama y el
sha del commit.

## Ambientes

| Ambiente | Rama | VM |
| --- | --- | --- |
| dev | `dev` | VM de dev (Azure) |
| prod | `prod` | VM de prod (Azure) |

## El reverse proxy

Todo el tráfico entra por `proxy` (nginx), el único servicio que publica puertos: el **80** y el
**443**. Los demás no publican ninguno y solo se alcanzan desde la red interna, por nombre.

El 80 sirve únicamente `/.well-known/acme-challenge/` (la validación de Let's Encrypt, también al
renovar) y redirige todo lo demás al 443 con un 301.

La configuración está en `nginx/templates/default.conf.template`. Es un **template** y no un `.conf`
porque la imagen oficial de nginx reemplaza `${DOMAIN}` al arrancar y escribe el resultado en
`/etc/nginx/conf.d/default.conf`. Solo toca las variables que existen en el entorno del contenedor,
así que `$host`, `$request_uri` y las nuestras quedan intactas. Gracias a eso el mismo archivo sirve
en dev y en prod, cada uno con su dominio y su certificado.

Se expone un `location` por servicio que el navegador tenga que poder tocar: hoy `/snippets` y
`/users`. `printscript-service`, `asset-service`, las bases y `/internal/permissions` no se exponen.

## Levantar una VM nueva

Suponiendo Docker instalado, Swarm iniciado (`docker swarm init`), los puertos 22, 80 y 443 abiertos
en el NSG de Azure y el dominio de DuckDNS apuntando a la IP de la VM:

```bash
git clone https://github.com/Ingsis-printscript-grupo3/snippet-searcher-infra.git
cd snippet-searcher-infra
cp .env.example .env.prod   # completalo: TAG, DOMAIN, INFRA_DIR y las credenciales de las bases
```

**El certificado va antes del primer deploy**, porque nginx no arranca si no existe. Como el stack
todavía no corre, el puerto 80 está libre y conviene `--standalone`:

```bash
sudo apt update && sudo apt install -y certbot
sudo certbot certonly --standalone -d <dominio> --agree-tos -m <mail> --no-eff-email
```

Ahora sí, el stack:

```bash
set -a && . ./.env.prod && set +a && docker stack deploy -c docker-stack.yml snippet-searcher
```

El timer de certbot renueva los archivos, pero nginx los lee una sola vez al arrancar. El hook le
avisa que los vuelva a leer, sin cortar conexiones:

```bash
sudo cp scripts/reload-proxy.sh /etc/letsencrypt/renewal-hooks/deploy/reload-proxy.sh
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-proxy.sh
```

Por último, pasá la renovación de `standalone` a `webroot`, para no tener que bajar nginx cada
90 días. Pide confirmación y emite un certificado nuevo:

```bash
sudo certbot certonly --webroot -w $PWD/certbot/www -d <dominio> --cert-name <dominio>
```

Verificación:

```bash
docker stack services snippet-searcher          # todos en 1/1
curl -i http://<dominio>/health                 # 301 a https
curl https://<dominio>/health                   # proxy ok, sin warnings de certificado
```

## Branching Strategy

Seguimos una estrategia basada en ramas cortas y dos ambientes principales:

- **Rama default (`prod`)**: Refleja lo que está desplegado en el ambiente de producción.
- **Rama de integración (`dev`)**: Integra los cambios continuos y se despliega en el ambiente de desarrollo.
- **Ramas de trabajo cortas** (`feat/`, `fix/`, `refactor/`): Salen de `dev` y entran a `dev` exclusivamente mediante Pull Request.
- **Releases a producción**: Se realizan mediante PRs desde `dev` hacia `prod`.
- **Criterios de Merge**:
  - Al menos 1 aprobación requerida (`Require approvals`).

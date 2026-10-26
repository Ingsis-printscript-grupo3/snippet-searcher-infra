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

## Branching Strategy

Seguimos una estrategia basada en ramas cortas y dos ambientes principales:

- **Rama default (`prod`)**: Refleja lo que está desplegado en el ambiente de producción.
- **Rama de integración (`dev`)**: Integra los cambios continuos y se despliega en el ambiente de desarrollo.
- **Ramas de trabajo cortas** (`feat/`, `fix/`, `refactor/`): Salen de `dev` y entran a `dev` exclusivamente mediante Pull Request.
- **Releases a producción**: Se realizan mediante PRs desde `dev` hacia `prod`.
- **Criterios de Merge**:
  - Al menos 1 aprobación requerida (`Require approvals`).

# crd-rs-cdi

Rust bindings for the KubeVirt [Containerized Data Importer](https://github.com/kubevirt/containerized-data-importer) (CDI) Custom Resource Definitions, auto-generated with [kopium](https://github.com/kube-rs/kopium).

Generated from upstream **`v1.65.0`** (see `crds/cdi/VERSION`).

## Kinds

| Module | Kind | API group |
|--------|------|-----------|
| `data_volume` | `DataVolume` | `cdi.kubevirt.io/v1beta1` |

The install-time operator-config CRDs (`CDI` / `CDIConfig`) are intentionally not
exposed.

## Usage

```toml
[dependencies]
crd-rs-cdi = "0.1"
k8s-openapi = { version = "0.27", features = ["v1_32"] }
```

```rust
use crd_rs_cdi::data_volume::DataVolume;
```

## How the schemas are obtained

CDI does not publish standalone per-resource CRD manifests; `cdi-operator`
generates them at install time. The vendored CRD in `crds/cdi/` is rendered
deterministically from the upstream generator function
(`pkg/operator/resources/cluster`) at the pinned tag. See
`scripts/update-cdi-crds.sh`.

## License

Apache-2.0

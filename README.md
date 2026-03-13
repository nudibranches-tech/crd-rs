# crd-rs

Rust bindings for Kubernetes Custom Resource Definitions (CRDs), auto-generated with [kopium](https://github.com/kube-rs/kopium).

## Crates

| Crate | Upstream | Source Version |
|-------|----------|----------------|
<!-- cnpg-version -->| `crd-rs-cnpg` | [CloudNativePG](https://github.com/cloudnative-pg/cloudnative-pg) | `v1.28.1` |
<!-- cilium-version -->| `crd-rs-cilium` | [Cilium](https://github.com/cilium/cilium) | `v1.19.1` |

## Usage

Add the crate you need as a dependency. You must also depend on `k8s-openapi` and enable a Kubernetes version feature:

```toml
[dependencies]
crd-rs-cnpg = "0.1"
crd-rs-cilium = "0.1"
k8s-openapi = { version = "0.27", features = ["v1_32"] }
```

```rust
use crd_rs_cnpg::cluster::Cluster;
use crd_rs_cilium::network_policy::CiliumNetworkPolicy;
```

## Updating CRDs

CRDs are regenerated weekly via CI from the latest upstream releases. To update manually:

```sh
# Uses latest release by default
bash scripts/update-crds.sh
bash scripts/update-cilium-crds.sh

# Or pin to a specific version
CNPG_REF=v1.28.1 bash scripts/update-crds.sh
CILIUM_REF=v1.19.1 bash scripts/update-cilium-crds.sh
```

Requires [kopium](https://github.com/kube-rs/kopium) and the [GitHub CLI](https://cli.github.com/).

## Local development

The `.cargo/config.toml` sets `K8S_OPENAPI_ENABLED_VERSION=1.32` so standard commands work without extra env vars:

```sh
cargo check --workspace
cargo clippy --workspace -- -D warnings
cargo fmt --all -- --check
```

## License

Apache-2.0

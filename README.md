# crd-rs

Rust bindings for Kubernetes Custom Resource Definitions (CRDs), auto-generated with [kopium](https://github.com/kube-rs/kopium).

## Crates

| Crate | Upstream | Source Version |
|-------|----------|----------------|
| `crd-rs-cnpg` | [CloudNativePG](https://github.com/cloudnative-pg/cloudnative-pg) | `v1.29.0` |
| `crd-rs-cilium` | [Cilium](https://github.com/cilium/cilium) | `v1.19.1` |
| `crd-rs-barman-cloud` | [Plugin Barman Cloud](https://github.com/cloudnative-pg/plugin-barman-cloud) | `v0.12.0` |
| `crd-rs-kubevirt` | [KubeVirt](https://github.com/kubevirt/kubevirt) | `v1.8.4` |
| `crd-rs-cdi` | [Containerized Data Importer](https://github.com/kubevirt/containerized-data-importer) | `v1.65.0` |

## Usage

Add the crate you need as a dependency. You must also depend on `k8s-openapi`:

```toml
[dependencies]
crd-rs-cnpg = "0.3"
crd-rs-cilium = "0.3"
crd-rs-barman-cloud = "0.2"
crd-rs-kubevirt = "0.2"
crd-rs-cdi = "0.2"
k8s-openapi = { version = "0.28", features = ["v1_36"] } # or another version as stated in k8s-openapi
```

```rust
use crd_rs_cnpg::cluster::Cluster;
use crd_rs_cilium::network_policy::CiliumNetworkPolicy;
use crd_rs_barman_cloud::object_store::ObjectStore;
use crd_rs_kubevirt::virtual_machine::VirtualMachine;
use crd_rs_cdi::data_volume::DataVolume;
```

## Updating CRDs

CRDs are regenerated weekly via CI from the latest upstream releases. To update manually:

```sh
# Uses latest release by default
bash scripts/update-crds.sh
bash scripts/update-cilium-crds.sh
bash scripts/update-barman-cloud-crds.sh
bash scripts/update-kubevirt-crds.sh
bash scripts/update-cdi-crds.sh

# Or pin to a specific version
CNPG_REF=v1.28.1 bash scripts/update-crds.sh
CILIUM_REF=v1.19.1 bash scripts/update-cilium-crds.sh
BARMAN_CLOUD_REF=v0.12.0 bash scripts/update-barman-cloud-crds.sh
KUBEVIRT_REF=v1.8.4 bash scripts/update-kubevirt-crds.sh
CDI_REF=v1.65.0 bash scripts/update-cdi-crds.sh
```

Requires [kopium](https://github.com/kube-rs/kopium), [Go](https://go.dev/) (KubeVirt and
CDI CRD schemas are rendered from their upstream generators), and the
[GitHub CLI](https://cli.github.com/).

## Local development

The `.cargo/config.toml` sets `K8S_OPENAPI_ENABLED_VERSION=1.32` so standard commands work without extra env vars:

```sh
cargo check --workspace --all-targets
cargo clippy --workspace --all-targets -- -D warnings
cargo fmt --all -- --check
```

## License

Apache-2.0

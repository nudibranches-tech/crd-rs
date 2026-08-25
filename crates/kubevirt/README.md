# crd-rs-kubevirt

Rust bindings for [KubeVirt](https://github.com/kubevirt/kubevirt) Custom Resource Definitions, auto-generated with [kopium](https://github.com/kube-rs/kopium).

Generated from upstream **`v1.8.4`** (see `crds/kubevirt/VERSION`).

## Kinds

| Module | Kind | API group |
|--------|------|-----------|
| `virtual_machine` | `VirtualMachine` | `kubevirt.io/v1` |
| `virtual_machine_instance` | `VirtualMachineInstance` | `kubevirt.io/v1` |

## Usage

```toml
[dependencies]
crd-rs-kubevirt = "0.1"
k8s-openapi = { version = "0.28", features = ["v1_32"] }
```

```rust
use crd_rs_kubevirt::virtual_machine::VirtualMachine;
use crd_rs_kubevirt::virtual_machine_instance::VirtualMachineInstance;
```

## How the schemas are obtained

KubeVirt does not publish standalone per-resource CRD manifests; `virt-operator`
generates them at install time. The vendored CRDs in `crds/kubevirt/` are rendered
deterministically from the upstream generator functions
(`pkg/virt-operator/resource/generate/components`) at the pinned tag. See
`scripts/update-kubevirt-crds.sh`.

## License

Apache-2.0

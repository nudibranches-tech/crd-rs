#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CRDS_DIR="$ROOT_DIR/crds/cdi"
CRDS_REL_DIR="crds/cdi"
CRATE_DIR="$ROOT_DIR/crates/cdi"
SRC_DIR="$CRATE_DIR/src"

if [ -z "${CDI_REF:-}" ]; then
    CDI_REF="$(gh release view --repo kubevirt/containerized-data-importer --json tagName -q '.tagName')"
    echo "==> Resolved latest CDI release: $CDI_REF"
fi

# CDI does not publish standalone CRD manifests: the DataVolume CRD is generated
# by cdi-operator at install time. We reproduce it deterministically by rendering
# the upstream generator functions from a checkout pinned at $CDI_REF.

# CRD file -> module name mapping
declare -A CRDS=(
    ["datavolumes.cdi.kubevirt.io.yaml"]="data_volume"
)

mkdir -p "$CRDS_DIR" "$SRC_DIR"

echo "$CDI_REF" > "$CRDS_DIR/VERSION"
sed -i "s#^| \`crd-rs-cdi\` |.*#| \`crd-rs-cdi\` | [Containerized Data Importer](https://github.com/kubevirt/containerized-data-importer) | \`${CDI_REF}\` |#" "$ROOT_DIR/README.md"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "==> Cloning kubevirt/containerized-data-importer@${CDI_REF}..."
git clone --depth 1 --branch "$CDI_REF" https://github.com/kubevirt/containerized-data-importer.git "$WORK_DIR/cdi" >/dev/null 2>&1

DUMP_DIR="$WORK_DIR/cdi/tools/dump-crds-crdrs"
mkdir -p "$DUMP_DIR"
cat > "$DUMP_DIR/main.go" <<'EOF'
package main

import (
	"fmt"
	"os"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"sigs.k8s.io/yaml"

	"kubevirt.io/containerized-data-importer/pkg/operator/resources/cluster"
)

func main() {
	outDir := os.Args[1]

	crd := cluster.NewDataVolumeCrd()
	crd.TypeMeta = metav1.TypeMeta{
		APIVersion: "apiextensions.k8s.io/v1",
		Kind:       "CustomResourceDefinition",
	}
	out, err := yaml.Marshal(crd)
	if err != nil {
		panic(err)
	}
	path := outDir + "/datavolumes.cdi.kubevirt.io.yaml"
	if err := os.WriteFile(path, out, 0o644); err != nil {
		panic(err)
	}
	fmt.Printf("  wrote %s (%d bytes)\n", path, len(out))
}
EOF

echo "==> Rendering CRD schemas from upstream generators..."
(cd "$WORK_DIR/cdi" && GOFLAGS=-mod=vendor go run ./tools/dump-crds-crdrs "$CRDS_DIR")

echo "==> Generating Rust code with kopium..."

LIB_RS=""

for crd_file in "${!CRDS[@]}"; do
    mod_name="${CRDS[$crd_file]}"
    echo "  Generating module ${mod_name}..."
    # Generate without prelude, then prepend the crate-level prelude import
    (cd "$ROOT_DIR" && kopium -f "${CRDS_REL_DIR}/${crd_file}" --schema=derived -d --hide-prelude) > "${SRC_DIR}/${mod_name}.rs.tmp"
    {
        echo "use crate::prelude::*;"
        echo ""
        cat "${SRC_DIR}/${mod_name}.rs.tmp"
    } > "${SRC_DIR}/${mod_name}.rs"
    rm "${SRC_DIR}/${mod_name}.rs.tmp"
    LIB_RS="${LIB_RS}pub mod ${mod_name};\n"
done

# Write lib.rs with shared prelude and module declarations
cat > "${SRC_DIR}/lib.rs" <<'EOF'
#![allow(clippy::all)]

#[allow(unused_imports)]
mod prelude {
    pub use kube_derive::CustomResource;
    pub use schemars::JsonSchema;
    pub use serde::{Deserialize, Serialize};
    pub use std::collections::BTreeMap;
    pub use k8s_openapi::apimachinery::pkg::apis::meta::v1::Condition;
    pub use k8s_openapi::apimachinery::pkg::util::intstr::IntOrString;
}

EOF

echo -e "$LIB_RS" >> "${SRC_DIR}/lib.rs"

# Create Cargo.toml only if missing, so manual version bumps survive regeneration
if [ ! -f "${CRATE_DIR}/Cargo.toml" ]; then
    cat > "${CRATE_DIR}/Cargo.toml" <<'EOF'
[package]
name = "crd-rs-cdi"
version = "0.1.0"
edition = "2021"
license = "Apache-2.0"
description = "Kubernetes CRD bindings for KubeVirt Containerized Data Importer (CDI)"

[dependencies]
k8s-openapi = { workspace = true, features = ["schemars"] }
kube = { workspace = true, default-features = false, features = [] }
kube-core = { workspace = true, features = ["schema"] }
kube-derive.workspace = true
schemars.workspace = true
serde.workspace = true
serde_json.workspace = true

[dev-dependencies]
k8s-openapi = { workspace = true, features = ["latest", "schemars"] }
kube = { workspace = true, features = ["client", "rustls-tls"] }

[package.metadata.docs.rs]
features = ["k8s-openapi/latest"]
EOF
fi

echo "==> Formatting..."
cd "$ROOT_DIR"
cargo fmt -p crd-rs-cdi

echo "==> Running cargo check..."
K8S_OPENAPI_ENABLED_VERSION=1.32 cargo check -p crd-rs-cdi
echo "==> CDI crate compiles successfully."

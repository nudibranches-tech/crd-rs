#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CRDS_DIR="$ROOT_DIR/crds/barman-cloud"
CRATE_DIR="$ROOT_DIR/crates/barman-cloud"
SRC_DIR="$CRATE_DIR/src"

if [ -z "${BARMAN_CLOUD_REF:-}" ]; then
    BARMAN_CLOUD_REF="$(gh release view --repo cloudnative-pg/plugin-barman-cloud --json tagName -q '.tagName')"
    echo "==> Resolved latest plugin-barman-cloud release: $BARMAN_CLOUD_REF"
fi
BARMAN_CLOUD_BASE_URL="https://raw.githubusercontent.com/cloudnative-pg/plugin-barman-cloud/${BARMAN_CLOUD_REF}/config/crd/bases"

mkdir -p "$CRDS_DIR" "$SRC_DIR"

echo "$BARMAN_CLOUD_REF" > "$CRDS_DIR/VERSION"
sed -i "s#<!-- barman-cloud-version -->.*#<!-- barman-cloud-version -->| \`crd-rs-barman-cloud\` | [Plugin Barman Cloud](https://github.com/cloudnative-pg/plugin-barman-cloud) | \`${BARMAN_CLOUD_REF}\` |#" "$ROOT_DIR/README.md"

# CRD file -> module name mapping
declare -A CRDS=(
    ["barmancloud.cnpg.io_objectstores.yaml"]="object_store"
)

echo "==> Downloading plugin-barman-cloud CRDs (ref: $BARMAN_CLOUD_REF)..."

for crd_file in "${!CRDS[@]}"; do
    echo "  Downloading $crd_file..."
    curl -sSfL "${BARMAN_CLOUD_BASE_URL}/${crd_file}" -o "${CRDS_DIR}/${crd_file}"
done

echo "==> Generating Rust code with kopium..."

LIB_RS=""

for crd_file in "${!CRDS[@]}"; do
    mod_name="${CRDS[$crd_file]}"
    echo "  Generating module ${mod_name}..."
    # Generate without prelude, then prepend the crate-level prelude import
    kopium -f "${CRDS_DIR}/${crd_file}" --schema=derived -d --hide-prelude > "${SRC_DIR}/${mod_name}.rs.tmp"
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
name = "crd-rs-barman-cloud"
version = "0.1.0"
edition = "2021"
license = "Apache-2.0"
description = "Kubernetes CRD bindings for CloudNativePG Plugin Barman Cloud"

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
cargo fmt -p crd-rs-barman-cloud

echo "==> Running cargo check..."
K8S_OPENAPI_ENABLED_VERSION=1.32 cargo check -p crd-rs-barman-cloud
echo "==> Plugin Barman Cloud crate compiles successfully."

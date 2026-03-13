#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CRDS_DIR="$ROOT_DIR/crds/cnpg"
CRATE_DIR="$ROOT_DIR/crates/cnpg"
SRC_DIR="$CRATE_DIR/src"

if [ -z "${CNPG_REF:-}" ]; then
    CNPG_REF="$(gh release view --repo cloudnative-pg/cloudnative-pg --json tagName -q '.tagName')"
    echo "==> Resolved latest CNPG release: $CNPG_REF"
fi
CNPG_BASE_URL="https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/${CNPG_REF}/config/crd/bases"

echo "$CNPG_REF" > "$ROOT_DIR/crds/cnpg/VERSION"

# CRD file -> module name mapping
declare -A CRDS=(
    ["postgresql.cnpg.io_backups.yaml"]="backup"
    ["postgresql.cnpg.io_clusters.yaml"]="cluster"
    ["postgresql.cnpg.io_clusterimagecatalogs.yaml"]="cluster_image_catalog"
    ["postgresql.cnpg.io_databases.yaml"]="database"
    ["postgresql.cnpg.io_failoverquorums.yaml"]="failover_quorum"
    ["postgresql.cnpg.io_imagecatalogs.yaml"]="image_catalog"
    ["postgresql.cnpg.io_poolers.yaml"]="pooler"
    ["postgresql.cnpg.io_publications.yaml"]="publication"
    ["postgresql.cnpg.io_scheduledbackups.yaml"]="scheduled_backup"
    ["postgresql.cnpg.io_subscriptions.yaml"]="subscription"
)

mkdir -p "$CRDS_DIR" "$SRC_DIR"

echo "==> Downloading CNPG CRDs (ref: $CNPG_REF)..."

for crd_file in "${!CRDS[@]}"; do
    echo "  Downloading $crd_file..."
    curl -sSfL "${CNPG_BASE_URL}/${crd_file}" -o "${CRDS_DIR}/${crd_file}"
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

# Create Cargo.toml
cat > "${CRATE_DIR}/Cargo.toml" <<'EOF'
[package]
name = "cnpg"
version = "0.1.0"
edition = "2021"

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

echo "==> Formatting..."
cd "$ROOT_DIR"
cargo fmt -p cnpg

echo "==> Running cargo check..."
K8S_OPENAPI_ENABLED_VERSION=1.32 cargo check -p cnpg
echo "==> CNPG crate compiles successfully."

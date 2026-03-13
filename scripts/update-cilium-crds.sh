#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CRDS_DIR="$ROOT_DIR/crds/cilium"
CRATE_DIR="$ROOT_DIR/crates/cilium"
SRC_DIR="$CRATE_DIR/src"

if [ -z "${CILIUM_REF:-}" ]; then
    CILIUM_REF="$(gh release view --repo cilium/cilium --json tagName -q '.tagName')"
    echo "==> Resolved latest Cilium release: $CILIUM_REF"
fi
CILIUM_BASE_URL="https://raw.githubusercontent.com/cilium/cilium/${CILIUM_REF}/pkg/k8s/apis/cilium.io/client/crds"

echo "$CILIUM_REF" > "$ROOT_DIR/crds/cilium/VERSION"
sed -i "s#<!-- cilium-version -->.*#<!-- cilium-version -->| \`crd-rs-cilium\` | [Cilium](https://github.com/cilium/cilium) | \`${CILIUM_REF}\` |#" "$ROOT_DIR/README.md"

# version/filename -> module name
declare -A CRDS=(
    ["v2/ciliumbgpadvertisements.yaml"]="bgp_advertisement"
    ["v2/ciliumbgpclusterconfigs.yaml"]="bgp_cluster_config"
    ["v2/ciliumbgpnodeconfigoverrides.yaml"]="bgp_node_config_override"
    ["v2/ciliumbgpnodeconfigs.yaml"]="bgp_node_config"
    ["v2/ciliumbgppeerconfigs.yaml"]="bgp_peer_config"
    ["v2/ciliumcidrgroups.yaml"]="cidr_group"
    ["v2/ciliumclusterwideenvoyconfigs.yaml"]="clusterwide_envoy_config"
    ["v2/ciliumclusterwidenetworkpolicies.yaml"]="clusterwide_network_policy"
    ["v2/ciliumegressgatewaypolicies.yaml"]="egress_gateway_policy"
    ["v2/ciliumendpoints.yaml"]="endpoint"
    ["v2/ciliumenvoyconfigs.yaml"]="envoy_config"
    # ciliumidentities has no spec — kopium cannot generate code for it
    # ["v2/ciliumidentities.yaml"]="identity"
    ["v2/ciliumloadbalancerippools.yaml"]="load_balancer_ip_pool"
    ["v2/ciliumlocalredirectpolicies.yaml"]="local_redirect_policy"
    ["v2/ciliumnetworkpolicies.yaml"]="network_policy"
    ["v2/ciliumnodeconfigs.yaml"]="node_config"
    ["v2/ciliumnodes.yaml"]="node"
    ["v2alpha1/ciliumendpointslices.yaml"]="endpoint_slice"
    ["v2alpha1/ciliumgatewayclassconfigs.yaml"]="gateway_class_config"
    ["v2alpha1/ciliuml2announcementpolicies.yaml"]="l2_announcement_policy"
    ["v2alpha1/ciliumpodippools.yaml"]="pod_ip_pool"
)

mkdir -p "$CRDS_DIR/v2" "$CRDS_DIR/v2alpha1" "$SRC_DIR"

echo "==> Downloading Cilium CRDs (ref: $CILIUM_REF)..."

for crd_path in "${!CRDS[@]}"; do
    echo "  Downloading $crd_path..."
    curl -sSfL "${CILIUM_BASE_URL}/${crd_path}" -o "${CRDS_DIR}/${crd_path}"
done

echo "==> Generating Rust code with kopium..."

LIB_RS=""

for crd_path in "${!CRDS[@]}"; do
    mod_name="${CRDS[$crd_path]}"
    echo "  Generating module ${mod_name}..."
    kopium -f "${CRDS_DIR}/${crd_path}" --schema=derived -d --hide-prelude > "${SRC_DIR}/${mod_name}.rs.tmp"
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
name = "crd-rs-cilium"
version = "0.1.0"
edition = "2021"
license = "Apache-2.0"
description = "Kubernetes CRD bindings for Cilium"

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
cargo fmt -p crd-rs-cilium

echo "==> Running cargo check..."
K8S_OPENAPI_ENABLED_VERSION=1.32 cargo check -p crd-rs-cilium
echo "==> Cilium crate compiles successfully."

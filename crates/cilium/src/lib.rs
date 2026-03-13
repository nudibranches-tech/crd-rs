#![allow(clippy::all)]

#[allow(unused_imports)]
mod prelude {
    pub use k8s_openapi::apimachinery::pkg::apis::meta::v1::Condition;
    pub use k8s_openapi::apimachinery::pkg::util::intstr::IntOrString;
    pub use kube_derive::CustomResource;
    pub use schemars::JsonSchema;
    pub use serde::{Deserialize, Serialize};
    pub use std::collections::BTreeMap;
}

pub mod bgp_advertisement;
pub mod bgp_cluster_config;
pub mod bgp_node_config;
pub mod bgp_node_config_override;
pub mod bgp_peer_config;
pub mod cidr_group;
pub mod clusterwide_envoy_config;
pub mod clusterwide_network_policy;
pub mod egress_gateway_policy;
pub mod endpoint;
pub mod endpoint_slice;
pub mod envoy_config;
pub mod gateway_class_config;
pub mod l2_announcement_policy;
pub mod load_balancer_ip_pool;
pub mod local_redirect_policy;
pub mod network_policy;
pub mod node;
pub mod node_config;
pub mod pod_ip_pool;

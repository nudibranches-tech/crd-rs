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

pub mod backup;
pub mod cluster;
pub mod cluster_image_catalog;
pub mod database;
pub mod failover_quorum;
pub mod image_catalog;
pub mod pooler;
pub mod publication;
pub mod scheduled_backup;
pub mod subscription;

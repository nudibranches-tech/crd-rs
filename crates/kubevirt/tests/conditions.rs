//! KubeVirt conditions are not `meta/v1.Condition`: the API server sends
//! `lastProbeTime` / `lastTransitionTime` as `null` while a VMI is still being
//! scheduled. These tests pin that the generated types accept that shape.

use crd_rs_kubevirt::virtual_machine::VirtualMachineStatus;
use crd_rs_kubevirt::virtual_machine_instance::VirtualMachineInstanceStatus;

#[test]
fn virtual_machine_condition_accepts_null_timestamps() {
    let status: VirtualMachineStatus = serde_json::from_value(serde_json::json!({
        "conditions": [{
            "lastProbeTime": null,
            "lastTransitionTime": null,
            "message": "Not all of the VMI's DVs are ready",
            "reason": "NotAllDVsReady",
            "status": "False",
            "type": "DataVolumesReady"
        }]
    }))
    .expect("a condition with null timestamps deserializes");

    let condition = &status.conditions.expect("conditions present")[0];
    assert_eq!(condition.r#type, "DataVolumesReady");
    assert!(condition.last_transition_time.is_none());
}

#[test]
fn virtual_machine_instance_condition_accepts_missing_reason() {
    let status: VirtualMachineInstanceStatus = serde_json::from_value(serde_json::json!({
        "conditions": [{
            "lastProbeTime": null,
            "lastTransitionTime": "2026-09-30T11:57:32Z",
            "status": "True",
            "type": "AgentConnected"
        }]
    }))
    .expect("a condition without reason or message deserializes");

    let condition = &status.conditions.expect("conditions present")[0];
    assert_eq!(condition.r#type, "AgentConnected");
    assert!(condition.reason.is_none());
}

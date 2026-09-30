//! CDI conditions are not `meta/v1.Condition`: they carry `lastHeartbeatTime`
//! and may omit `reason` / `message`. This pins that the generated type accepts
//! the shape the API server actually returns.

use crd_rs_kubevirt_cdi::data_volume::DataVolumeStatus;

#[test]
fn data_volume_condition_accepts_null_and_missing_fields() {
    let status: DataVolumeStatus = serde_json::from_value(serde_json::json!({
        "conditions": [{
            "lastHeartbeatTime": "2026-09-30T11:57:32Z",
            "lastTransitionTime": null,
            "status": "True",
            "type": "Bound"
        }]
    }))
    .expect("a condition with a null timestamp and no reason deserializes");

    let condition = &status.conditions.expect("conditions present")[0];
    assert_eq!(condition.r#type, "Bound");
    assert!(condition.last_transition_time.is_none());
    assert!(condition.reason.is_none());
}

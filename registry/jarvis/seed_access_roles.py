"""Seed the ACL role catalog Jarvis needs before it can register agents or MCP servers.

The chart does not create these rows. Without remoteAgent_owner (permBits 15),
POST /api/v1/agents fails with "No role found for resource_type=remoteAgent".
The backend loads this catalog once at startup, so a process that is already
running must be restarted after the first seed.
"""

import os
from datetime import UTC, datetime

from pymongo import MongoClient

ROLES = [
    ("federation_viewer", "federation", "com_ui_federation_role_viewer", "com_ui_federation_viewer_desc", 1),
    ("federation_editor", "federation", "com_ui_federation_role_editor", "com_ui_federation_editor_desc", 3),
    ("federation_owner", "federation", "com_ui_federation_role_owner", "com_ui_federation_owner_desc", 15),
    ("workflow_viewer", "workflow", "com_ui_workflow_role_viewer", "com_ui_workflow_viewer_desc", 1),
    ("workflow_editor", "workflow", "com_ui_workflow_role_editor", "com_ui_workflow_editor_desc", 3),
    ("workflow_owner", "workflow", "com_ui_workflow_role_owner", "com_ui_workflow_owner_desc", 15),
    ("workflow_schedule_viewer", "workflowSchedule", "com_ui_workflow_schedule_role_viewer", "com_ui_workflow_schedule_viewer_desc", 1),
    ("workflow_schedule_editor", "workflowSchedule", "com_ui_workflow_schedule_role_editor", "com_ui_workflow_schedule_editor_desc", 3),
    ("workflow_schedule_owner", "workflowSchedule", "com_ui_workflow_schedule_role_owner", "com_ui_workflow_schedule_owner_desc", 15),
    ("skill_viewer", "skill", "com_ui_skill_role_viewer", "com_ui_skill_viewer_desc", 1),
    ("skill_editor", "skill", "com_ui_skill_role_editor", "com_ui_skill_editor_desc", 3),
    ("skill_owner", "skill", "com_ui_skill_role_owner", "com_ui_skill_owner_desc", 15),
    ("skill_sync_source_viewer", "skillSyncSource", "com_ui_skill_sync_source_role_viewer", "com_ui_skill_sync_source_viewer_desc", 1),
    ("skill_sync_source_editor", "skillSyncSource", "com_ui_skill_sync_source_role_editor", "com_ui_skill_sync_source_editor_desc", 3),
    ("skill_sync_source_owner", "skillSyncSource", "com_ui_skill_sync_source_role_owner", "com_ui_skill_sync_source_owner_desc", 15),
    ("mcpServer_viewer", "mcpServer", "com_ui_mcp_server_role_viewer", "com_ui_mcp_server_role_viewer_desc", 1),
    ("mcpServer_editor", "mcpServer", "com_ui_mcp_server_role_editor", "com_ui_mcp_server_role_editor_desc", 3),
    ("mcpServer_owner", "mcpServer", "com_ui_mcp_server_role_owner", "com_ui_mcp_server_role_owner_desc", 15),
    ("remoteAgent_viewer", "remoteAgent", "com_ui_remote_agent_role_viewer", "com_ui_remote_agent_role_viewer_desc", 1),
    ("remoteAgent_editor", "remoteAgent", "com_ui_remote_agent_role_editor", "com_ui_remote_agent_role_editor_desc", 3),
    ("remoteAgent_owner", "remoteAgent", "com_ui_remote_agent_role_owner", "com_ui_remote_agent_role_owner_desc", 15),
]


def main() -> None:
    now = datetime.now(UTC)
    client = MongoClient(os.environ["MONGO_URI"], serverSelectionTimeoutMS=10000)
    collection = client.get_default_database()["accessroles"]
    inserted = 0
    for access_role_id, resource_type, name, description, perm_bits in ROLES:
        result = collection.update_one(
            {"accessRoleId": access_role_id},
            {
                "$setOnInsert": {
                    "accessRoleId": access_role_id,
                    "resourceType": resource_type,
                    "name": name,
                    "description": description,
                    "permBits": perm_bits,
                    "createdAt": now,
                    "updatedAt": now,
                    "__v": 0,
                }
            },
            upsert=True,
        )
        if result.upserted_id is not None:
            inserted += 1
    print(f"INSERTED={inserted}")


if __name__ == "__main__":
    main()

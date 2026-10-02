# /// script
# requires-python = ">=3.12"
# dependencies = ["httpx>=0.27", "mcp==1.28.1"]
# ///
"""Discover and execute A2A agents through the Jarvis MCP gateway."""

# pyright: reportMissingImports=false

import argparse
import asyncio
import json
import os
from typing import Any

import httpx
from mcp import ClientSession
from mcp.client.streamable_http import streamable_http_client

DEFAULT_URL = "http://127.0.0.1:17860/proxy/mcpgw/mcp"


def print_result(result: Any) -> None:
    structured = getattr(result, "structuredContent", None)
    if structured is not None:
        print(json.dumps(structured, indent=2))
        return

    for item in result.content:
        text = getattr(item, "text", None)
        print(text if text is not None else item.model_dump_json(indent=2))


async def call_tool(name: str, arguments: dict[str, Any]) -> None:
    token = os.environ.get("JARVIS_TOKEN")
    if not token:
        raise SystemExit("Set JARVIS_TOKEN to a managed-agent Bearer token.")

    url = os.environ.get("JARVIS_MCP_URL", DEFAULT_URL)
    async with (
        httpx.AsyncClient(
            headers={"Authorization": f"Bearer {token}"},
            timeout=httpx.Timeout(30, read=300),
            follow_redirects=True,
        ) as http_client,
        streamable_http_client(url, http_client=http_client, terminate_on_close=False) as (
            read,
            write,
            _,
        ),
        ClientSession(read, write) as session,
    ):
        await session.initialize()
        result = await session.call_tool(name, arguments)
        print_result(result)
        if result.isError:
            raise SystemExit(1)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)

    list_command = commands.add_parser("list", help="List or search accessible agents")
    list_command.add_argument("--query", default="", help="Capability search; empty lists the catalog")
    list_command.add_argument("--top-n", type=int, default=20, choices=range(1, 51))

    execute_command = commands.add_parser("execute", help="Execute a discovered agent")
    execute_command.add_argument("agent_id", help="agent_id returned by the list command")
    execute_command.add_argument("message", help="Task to send to the agent")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if args.command == "list":
        asyncio.run(
            call_tool(
                "discover_agents",
                {"query": args.query, "top_n": args.top_n, "type_list": ["agent"]},
            )
        )
    else:
        asyncio.run(
            call_tool(
                "execute_agent",
                {
                    "agent_id": args.agent_id,
                    "message": {"parts": [{"kind": "text", "text": args.message}]},
                },
            )
        )


if __name__ == "__main__":
    main()

from __future__ import annotations

from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field

type OnCommandsChanged = Callable[[], Awaitable[None]]


@dataclass(frozen=True)
class AcpCommand:
    """Command advertised to ACP clients via available_commands_update."""

    name: str
    description: str
    handler: str
    input_hint: str | None = None


@dataclass
class AcpCommandRegistry:
    """Registry of ACP commands. Notifies listeners when commands change."""

    _commands: dict[str, AcpCommand] = field(default_factory=dict)
    _on_changed: OnCommandsChanged | None = None

    def __post_init__(self) -> None:
        if not self._commands:
            self._commands = _build_commands()

    def set_on_changed(self, callback: OnCommandsChanged) -> None:
        self._on_changed = callback

    @property
    def commands(self) -> dict[str, AcpCommand]:
        return self._commands

    def get(self, name: str) -> AcpCommand | None:
        return self._commands.get(name)

    async def notify_changed(self) -> None:
        if self._on_changed is not None:
            await self._on_changed()


def _build_commands() -> dict[str, AcpCommand]:
    return {
        "help": AcpCommand(
            name="help",
            description="Show available commands and keyboard shortcuts",
            handler="_handle_help",
        ),
        "config": AcpCommand(
            name="config",
            description="Edit config settings",
            handler="_handle_config",
        ),
        "model": AcpCommand(
            name="model",
            description="Select active model",
            handler="_handle_config",
        ),
        "thinking": AcpCommand(
            name="thinking",
            description="Select thinking level",
            handler="_handle_config",
        ),
        "compact": AcpCommand(
            name="compact",
            description="Compact conversation history by summarizing. Optionally pass instructions to guide the summary",
            handler="_handle_compact",
            input_hint="Optional instructions to guide the compaction summary",
        ),
        "clear": AcpCommand(
            name="clear",
            description="Clear conversation history",
            handler="_handle_client_side_command",
        ),
        "copy": AcpCommand(
            name="copy",
            description="Copy the last agent message to the clipboard",
            handler="_handle_client_side_command",
        ),
        "debug": AcpCommand(
            name="debug",
            description="Toggle debug console",
            handler="_handle_client_side_command",
        ),
        "exit": AcpCommand(
            name="exit",
            description="Exit the application",
            handler="_handle_client_side_command",
        ),
        "status": AcpCommand(
            name="status",
            description="Display agent statistics",
            handler="_handle_status",
        ),
        "reload": AcpCommand(
            name="reload",
            description="Reload configuration, agent instructions, and skills from disk",
            handler="_handle_reload",
        ),
        "log": AcpCommand(
            name="log",
            description="Show path to current session log directory",
            handler="_handle_log",
        ),
        "proxy-setup": AcpCommand(
            name="proxy-setup",
            description="Configure proxy and SSL certificate settings",
            handler="_handle_proxy_setup",
            input_hint="KEY value to set, KEY to unset, or empty for help",
        ),
        "resume": AcpCommand(
            name="resume",
            description="Browse and resume past sessions",
            handler="_handle_resume",
        ),
        "continue": AcpCommand(
            name="continue",
            description="Resume the last or selected past session",
            handler="_handle_resume",
        ),
        "mcp": AcpCommand(
            name="mcp",
            description="Display available MCP servers and connectors. Pass a name to list its tools",
            handler="_handle_mcp",
            input_hint="Optional server name",
        ),
        "voice": AcpCommand(
            name="voice",
            description="Configure voice settings",
            handler="_handle_voice",
        ),
        "leanstall": AcpCommand(
            name="leanstall",
            description="Install the Lean 4 agent (leanstral)",
            handler="_handle_leanstall",
        ),
        "unleanstall": AcpCommand(
            name="unleanstall",
            description="Uninstall the Lean 4 agent",
            handler="_handle_unleanstall",
        ),
        "data-retention": AcpCommand(
            name="data-retention",
            description="Show data retention information",
            handler="_handle_data_retention",
        ),
        "rewind": AcpCommand(
            name="rewind",
            description="Rewind to a previous message",
            handler="_handle_rewind",
        ),
    }

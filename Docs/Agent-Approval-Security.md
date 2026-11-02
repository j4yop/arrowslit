# Agent approval security review

**Scope:** Claude Code, Codex, Copilot CLI, Antigravity, Cursor and OpenCode permission requests answered from the Arrowslit notch.

## Trust boundary

- The bridge listens on a Unix domain socket in `~/Library/Application Support/Arrowslit/agent-arrowslit.sock`, created with mode `0600`.
- The server accepts only connections whose peer UID is the current user (`getpeereid`).
- CLI hooks run Arrowslit's own executable with `--agent-hook`; the hook authenticates the app it connects to using the peer audit token and pins the app's code hash (`cdhash`). A different binary or a replaced app fails closed.
- OpenCode is different: its plugin is a user-owned JavaScript file under `~/.config/opencode/plugins/arrowslit-approval.js`. It talks to the same user-only socket, but the plugin is not code-signed by Arrowslit. Same-user processes are inside the trust boundary. A user who can write the plugin can already run commands as that user.

## Failure behaviour

- If Arrowslit is not running, the socket connection fails and the assistant keeps its own prompt.
- If no answer arrives, the hook/plugin returns "ask" before the assistant's timeout; nothing is auto-allowed.
- Closing the alert or pressing **Ask in …** returns the request to the assistant.
- The bridge answers waiting requests with `ask` when it stops.
- Allow is a one-time reply. Deny is a denial; OpenCode rejects pending permissions in that session through its own API.

## Hook installation

- CLI hooks are added to the assistant's existing JSON without dropping unrelated settings.
- Writes resolve symlinks so dotfiles links keep working, and the file's permissions are preserved.
- Uninstall removes only entries containing Arrowslit's `--agent-hook` flag.
- OpenCode's plugin file is written only when the OpenCode switch is on and is deleted when it is turned off.
- The current command is rewritten when the app moves.

## OpenCode adapter

- Listens for both `permission.asked` and `permission.v2.asked`.
- Sends action, resources, metadata and command/path to Arrowslit.
- Replies through `client.permission.reply` (or the session-scoped fallback) with `once` or `reject`.
- Any error, missing client method or timeout leaves the request unanswered so OpenCode's own prompt remains.

## Residual risks

- The OpenCode plugin is not signed. Verify the file path and contents before enabling it on a shared Mac.
- Assistant versions can change event names or reply APIs. A failed adapter fails closed but may stop showing approvals until updated.
- The socket is same-user, not same-process. Malware already running as the user is outside this boundary.

## Pre-release checks

- [x] Verify the socket is `0600` and peer UID is enforced (unit test).
- [ ] Verify a second local user cannot connect.
- [ ] Verify a replaced/mismatched Arrowslit binary is rejected by the CLI hook.
- [ ] Verify Allow, Deny and Ask for each of the six assistants.
- [x] Verify uninstall leaves valid JSON and removes only Arrowslit's entries (unit test).
- [ ] Verify OpenCode `permission.asked` and `permission.v2.asked` on the current release.

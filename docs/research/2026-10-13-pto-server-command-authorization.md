# PTO command event: server authority and remote driver authorization

Date: 2026-10-13. Scope: **PTO V1.5 PR #39**, mirrored into **V1.6 PR #45**. Source review and simulated-event regression are complete; a **real dedicated-server test is not yet complete**.

## Why this patch is necessary

Previously, `PTOStateEvent:run(connection)` accepted every client-sent `NetworkUtil.readNodeObject()` reference as long as `Control:setPowerTakeOffState(mode,throttle,true,false)` approved its gear/engagement rules. Those checks do not identify the actual sender. In a multi-user session a modified client could hypothetically request a different tractor's PTO mode/hand throttle. This is a source-level **missing authorization check**, not evidence of exploitation.

FS25's authoritative `VehicleEnterRequestEvent:run(connection)` calls `vehicle:setOwnerConnection(connection)`, assigns `vehicle.controllerUserId` from `mission.userManager:getUserIdByConnection(connection)`, and sets `vehicle.controllerFarmId`. The engine only grants entry for a synchronized, available vehicle and validates its remote ghost object. Source: [GIANTS GDN VehicleEnterRequestEvent](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=30&class=374&version=script).

## Exact server-side contract

For a **client -> server PTOStateEvent** request, before any setter:
1. The event is running on an actual server with `vehicle.isServer==true`; a missing API never allows a remote command.
2. The referenced vehicle is synchronized on the authoritative server.
3. `vehicle:getOwnerConnection()` is **exactly** the sender's `connection`. Farm ownership or a generic sell/hire permission alone is insufficient; a farm colleague may not change the PTO mode of a tractor another person currently operates.
4. If available, `g_server:hasGhostObject(connection,vehicle)` confirms that the client has this synchronized object.
5. The server resolves `userManager:getUserIdByConnection(connection)` and compares it to `vehicle.controllerUserId`. No user/farm identifier is accepted from the client payload.
6. After authorization, `Control:setPowerTakeOffState` STILL validates selected gear capability, current shaft engagement, and AI activity.
7. Only the accepted server state is replicated to other clients, excluding the original sender.

If any of these authoritative checks fails or throws, the request is rejected without mutating or broadcasting the PTO state. The event's `getDiagnostics()` records accepted/rejected counts and rejection categories without disclosing user IDs; no per-frame polling or new network fields are introduced.

**Unchanged paths:** Host/AI changes use `PTOStateEvent.send` directly from the server, and trusted server-to-client replication continues without subjecting the server to remote-driver checks. The existing saved hand-throttle/gear fields and RC/MR/RMS motor owner boundaries are untouched.

## Separate specialization stream entry points

A follow-up review identified another untrusted path: `Control:onReadUpdateStream` previously called `self:setPowerTakeOffState(...,true,true)` regardless of connection direction, bypassing the authorization in `PTOStateEvent`. Initial `onReadStream` also directly accepted network fields without a source check. **Both are now server-to-client only**: the initial `onReadStream` consumes the fixed stream fields but refuses non-authoritative sources. The update stream follows the **exact GIANTS ForageWagon convention**: when `connection:getIsServer()` is false (server->client), `onWriteUpdateStream` sends its presence bit and optional state and `onReadUpdateStream` consumes them; when true (client->server), **neither handler writes nor reads any PTO update bits**. This replaces an intermediate and incorrect approach that emitted a stray `false` presence bit towards the server. `PTOStateEvent` remains the **only** accepted client-to-server PTO state mutation path. No event schema or field order changed in the authorized direction.

The `tests/pto_control_harness.lua` suite now verifies all of these cases using engine-shaped stubs, including stream alignment, client injection refusal, authoritative server replication and correct presence-bit writes. Source precedent: the GIANTS FS25 `ForageWagon:onReadUpdateStream` / `Vehicle:readUpdateStream` use `connection:getIsServer()` to distinguish the authoritative network direction. (https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=676&version=script; https://gdn.giants-software.com/documentation_scripting_fs25.php?category=91&class=888&version=script).

## Testing performed

Automated regression in `tests/pto_state_event_harness.lua` covers:
- Real current-driver request accepted and broadcast.
- Different client refused even if on the same farm; missing owner connection refused.
- Stale controller user ID, unknown sender user, missing userManager, or owner API exception refused.
- Missing synchronization or ghost visibility refused.
- Server context absent, rejected operator gear/engagement state, and driver handoff.
- Server-to-client replication still works and dedicated-server host broadcast does not require `g_client`.

The harness uses stub connections and is **not a live multiplayer simulation**. CI validates Lua syntax, harnesses and build package, not GIANTS native connection timing. The next appropriate release check is a minimal two-client dedicated/co-op test: driver A controls tractor A, B cannot change it remotely while merely co-present; handoff A->B, disconnected/reconnected clients, late joining client observes accepted state, admin/same-farm driver works as intended. Avoid re-running Horsch/Berthoud/Krone physical tests solely because this event changed.

## Release guidance

This closes the **source-level missing authorization check** but does **not** by itself grant a public-MP readiness claim or unblock unconditional merge to `main`. Keep #39/#45 as draft until CI plus a representative real MP test or an explicit release-scope decision (document that MP is unverified). No new game ZIP is needed for the previously completed singleplayer PTO physics tests; build a new ZIP only if remote MP validation is actually planned.

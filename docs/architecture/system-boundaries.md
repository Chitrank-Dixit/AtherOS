# System boundaries

## Product layer

Aether Studio, profile definitions, AI integrations, and user-facing workflows should call stable product capabilities rather than distribution commands.

## Operating-system adapter

A future adapter may expose distribution detection, package query/install, system update, and system information. This interface is illustrative; Sprint 0 does not implement it.

## Privileged operations

System changes require a future controlled broker with narrow operations, validation, authorization, and auditability. UI processes must not execute arbitrary root commands.

## Desktop boundary

The Studio and product services must not require a specific desktop. Desktop session configuration is isolated by profile; user configuration is not overwritten as a side effect of switching sessions.

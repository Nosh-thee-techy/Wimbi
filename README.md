# Wimbi | Nairobi Flood Watch

Wimbi is a Jac/Jaseci-first flood-warning coordination demo. It presents one fictional flood event through five views backed by one shared Jac graph. Every person, place, measurement, warning, and report is **sample data**, not live safety information.

## Shared event and graph

`services/wimbi.jac` defines persistent Jac graph nodes for `Area`, `River`, `Road`, `DrainagePoint`, `Person`, `Report`, and `EventEntry`. Typed edges connect downstream areas (`FlowsTo`), areas to rivers/roads/drains, people through weighted `Trusts` relationships, and reports to their areas.

The demo seeds eight Nairobi neighbourhoods, two rivers, twelve people, their roles/languages/vulnerability, and trust links. Server endpoints mutate this shared graph; the dashboard polls it every five seconds so open views can refresh after other actions. A graph-backed event log records actions for the audit view.

## Five views

Use the dashboard selector to change the view. The **Acting as** person selector is shared with Resident and Leader actions.

1. **Responder Command** — adjust rainfall to run downstream risk propagation and warning relay, review area risk/ETA, reports, and suggested resources; use **Fast-forward 10 min** for the silence-escalation demo.
2. **Community Leader** — review people in the trust circle, their acknowledgement and visit status, then relay or confirm a visit.
3. **Resident** — view a role-specific warning, acknowledge safety, and submit an area report with its verification verdict.
4. **Accountability** — see reach, acknowledgements, escalations, and verified-report totals from the graph.
5. **SMS-USSD** — enter `ACK|Name`, `REPORT|Area|Message`, or `STATUS|Area` to use the same server actions without a smartphone UI.

The persistent event log is newest-first and can be opened from the dashboard. Actions display a brief “what changed” message. Risk thresholds are Watch (30+), High (55+), and Critical (80+), with simulated ETAs.

## Jac agents and actions

- `RiskPropagator` visits downstream `FlowsTo` links to update each area’s simulated risk and ETA.
- `WarningRelay` traverses trust links from the ward officer and saves role/language-tailored warning text on people.
- `SilenceEscalator` traverses trusted links and flags silent vulnerable residents as needing a visit.
- `ReportVerifier` visits reports linked to areas, assigns Confirmed/Plausible status and a short reason, and increases risk for confirmed observations.
- Resident acknowledgement, visit confirmation, rainfall changes, acting-as changes, report submissions, and SMS commands write to the same graph state.

Client Jac calls server functions through `sv import` and `await`; the dashboard and service logic are Jac. There is no Next.js, Supabase, or external database service.

## Claude warnings and resource suggestions

Jac `by llm()` uses Anthropic Claude Sonnet 4.6 (`claude-sonnet-4-6`) for personalized warnings and response-resource suggestions. Provider failures use deterministic fallback templates so the sample demo remains usable. Configure a workspace-compatible Anthropic key through JacHammer Settings → Environment as `ANTHROPIC_API_KEY`, then restart the preview. The current warning says this endpoint may require an Anthropic workspace-scoped key or workspace header; if Claude rejects the credential, use a workspace-scoped API key. The app only displays key-presence status and never displays the secret.

## Run and demo

Install project dependencies with `jac install`. The managed preview runs the Jac web app from `main.jac`.

Suggested demo path:

1. In Responder Command, raise rainfall and observe area risk/ETA, warnings, and resource suggestions.
2. Change **Acting as** to a resident and switch to Resident; acknowledge safety and observe the shared status/event log.
3. Switch to Community Leader and confirm a visit for a flagged neighbour.
4. Submit a resident report and inspect its verdict in the responder and resident views.
5. Use SMS-USSD with `ACK|Kevin Mwangi` or `STATUS|Dandora`, then review the shared graph and event log.

This is a demo only. Do not use it for emergency response, dispatch decisions, or real-world flood warnings. All people, places, and reports are fictional sample data.
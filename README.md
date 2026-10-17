# Wimbi | Nairobi Flood Watch

Wimbi is a Jac/Jaseci-first flood-coordination demo: **one sample flood event, one shared server graph, five views**. Residents, areas, warnings, acknowledgements, reports, and audit events are sample data. This is not a live warning or emergency-response service.

## Shared state

`services/wimbi.jac` stores the event as Jac graph nodes and typed edges. The service owns rainfall, area risk and ETAs, people and trust relationships, reports and verdicts, acknowledgements, visit flags, and graph-backed `EventEntry` audit records. Dashboard actions call public Jac endpoints through client `sv import`; views refresh the graph snapshot periodically so a change can appear in other views and browser tabs.

The shared **Acting as** controls select one person in the server graph. The selected person drives the Resident view and SMS acknowledgement actions. Every major action should add an entry to the newest-first event log and show a short confirmation message.

## Five views

1. **Responder Command** — set rainfall, review neighbourhood risk/ETA and reports, inspect resource suggestions, and fast-forward time to simulate silence escalation.
2. **Community Leader** — review the trust circle, acknowledgement and visit status, relay warnings, and confirm completed visits.
3. **Resident** — view role/language-aware warning guidance, acknowledge safety, and submit a report with a verification verdict.
4. **Accountability** — inspect reach, acknowledgement, escalation and report-verification totals from the shared graph.
5. **SMS-USSD** — simulate feature-phone commands against the same server state: `ACK|Name`, `REPORT|Area|Message`, and `STATUS|Area`.

Risk levels in the demo are Watch (30+), High (55+), and Critical (80+), with simulated ETAs. These thresholds and readings are fictional.

## Jac agents

- `RiskPropagator` traverses `FlowsTo` links and updates area risk/ETA.
- `WarningRelay` walks trust edges from the ward officer and stores personalized warnings.
- `SilenceEscalator` flags unacknowledged vulnerable people for a visit.
- `ReportVerifier` traverses area-linked reports, assigns Confirmed/Plausible status with a reason, and raises area risk for confirmed reports.
- Jac `by llm()` provides Claude warning/resource generation; deterministic fallback messages keep the demo usable when Claude is unavailable.

## Claude configuration

The configured model is Anthropic Claude Sonnet 4.6 (`claude-sonnet-4-6`) and Jac reads `ANTHROPIC_API_KEY`. Add a valid workspace-scoped key in JacHammer Settings → Environment, then restart the preview. The previously configured key was rejected by Anthropic because it was not workspace-scoped; the app does not display the secret. Fallback behavior remains active on provider failure.

## Preview and demo path

The managed Jac preview runs `main.jac`; the client is written in Jac and calls the Jac backend, with no Next.js or Supabase.

1. Raise rainfall in Responder Command and observe the shared risk/ETA and warning counts.
2. Change Acting as, then switch to Resident or Community Leader to see the selected person's record.
3. Acknowledge safety or confirm a visit and inspect the event log/accountability view.
4. Submit a report and review the verdict in the responder/resident views.
5. Send `ACK|Kevin Mwangi` or `STATUS|Dandora` from SMS-USSD and inspect the shared event log.

All people, places, warnings and reports are fictional sample data. Do not use this demo for real-world safety decisions.
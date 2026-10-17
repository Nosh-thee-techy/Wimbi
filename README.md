# Wimbi | Nairobi Flood Watch

Wimbi is a Jac/Jaseci-first flood-warning coordination demo. Every person, location, measurement, warning, and report shown is **Sample data**, not live safety information.

## Jac graph and agent walkers

- `services/wimbi.jac` models `Area`, `River`, `DrainagePoint`, `Road`, `Person`, and `Report` nodes connected by typed `FlowsTo`, `NearRiver`, `Connects`, `HasDrainage`, `Trusts`, and `ReportsIn` edges.
- Seed data includes eight Nairobi neighbourhoods, two rivers, twelve people with role/language/vulnerability attributes, and weighted trust links. Seed initialization avoids creating another set of areas when the graph already exists.
- `RiskPropagator` visits downstream `FlowsTo` edges and calculates risk and ETA. `WarningRelay` traverses the trust network from the ward officer and generates role- and language-tailored messages. `SilenceEscalator` follows trusted links and marks unacknowledged vulnerable residents for a visit. `ReportVerifier` traverses areas and linked reports to set verification status.
- `set_rainfall` invokes risk propagation and warning relay. `run_demo_flow` demonstrates warning relay, silence escalation, and report verification.
- `submit_resident_report(area_name, message)` validates a resident observation, attaches it to its Area, invokes verification, and returns updated graph data.
- Warnings use Jac `by llm()` with `gpt-4o-mini`. Provider errors, missing credentials, and generation failures fall back to conservative role-aware templates. To try live generation, add `OPENAI_API_KEY` in JacHammer Settings → Environment and restart the preview. The demo remains usable without it.
- The client is Jac and reaches typed server endpoints via `sv import` and `await`; no Next.js, Supabase, or external database service is used.

## Demo

1. Adjust the rainfall slider to update downstream risk.
2. Choose Resident, Community Leader, Responder Command, or Accountability.
3. In Resident, submit a water observation for a named area.
4. Select **Fast-forward 10 min** to demonstrate silence escalation and verification.

This is a demo only. Do not rely on it for emergency response or real-world flood warnings. Existing sample data created before idempotent seeding may include duplicate sample records.

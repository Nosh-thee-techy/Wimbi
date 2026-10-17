# Wimbi | Nairobi Flood Watch

Wimbi is a Jac/Jaseci-first demo for coordinating flood warnings around who needs to hear, from whom, and what neighbours confirm. All names, places, readings, alerts and reports in this demo are **Sample data** and are not live safety information.

## Jac and Jaseci

- `services/wimbi.jac` defines persistent Jac graph nodes for `Area`, `River`, `DrainagePoint`, `Road`, `Person` and `Report`, plus typed `FlowsTo`, `NearRiver`, `Connects`, `HasDrainage`, `Trusts` and `ReportsIn` edges.
- The seeded Nairobi graph contains eight areas, two rivers, twelve people with roles and languages, weighted trust links, and a connected waterway sequence.
- `set_rainfall` updates area risk/ETA and prepares tailored warning text. `run_demo_flow` simulates silence escalation, flags a vulnerable neighbour for a visit, confirms a resident report, and feeds it back into area risk.
- The endpoints are Jac `def:pub` functions, called asynchronously by the Jac client component through `sv import`.
- Graph nodes and relationships use Jac's Object-Spatial Programming model and are persistent in the server graph. Client UI and state are also written in Jac; no separate React, Next.js or database service is used.

The requested agent actions are represented by Jac graph operations in this deterministic offline demo. `by llm()` copy generation and external messaging are not enabled so the demo runs without credentials; add an LLM provider key through JacHammer Settings before enabling any live LLM-backed warning workflow. Never use this sample interface as an operational warning service.

## Demo

1. Use the rainfall slider to change mm/hr and update neighbourhood risk.
2. Choose Resident, Community Leader, Responder Command or Accountability.
3. Select **Fast-forward 10 min** to simulate escalation and a corroborated report.
4. Review the updated area risk, neighbour report and reach metrics.

## Run

Install dependencies with `jac install` and run the Jac web app with `jac start --dev main.jac`.

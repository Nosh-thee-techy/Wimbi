import os;
import from jaclang.byllm.lib { Model }

node Area { has name: str = ""; has river: str = ""; has risk: int = 0; has eta: str = "Monitoring"; }
node River { has name: str = ""; }
node DrainagePoint { has name: str = ""; has condition: str = "Clear"; }
node Road { has name: str = ""; has area_name: str = ""; }
node Person { has name: str = ""; has role: str = "resident"; has language: str = "English"; has area: str = ""; has vulnerable: bool = False; has acknowledged: bool = False; has warning: str = ""; has needs_visit: bool = False; }
node Report { has message: str = ""; has area: str = ""; has status: str = "Unverified"; has reasoning: str = "Awaiting neighbour reports"; }
edge FlowsTo: Area --> Area { has strength: int = 1; }
edge NearRiver: Area --> River {}
edge Connects: Area --> Road {}
edge HasDrainage: Area --> DrainagePoint {}
edge Trusts: Person --> Person { has weight: int = 1; }
edge ReportsIn: Area --> Report {}
glob seeded: bool = False;
glob rain: int = 18;
glob elapsed: bool = False;
glob llm_model: Model = Model(model_name="claude-sonnet-4-6");

obj ResourceSuggestion { has items: list[str]; }
sem ResourceSuggestion.items = "List the necessary emergency resources selected from shelter, boat, medic, and drain crew. Keep suggestions concise.";
def suggest_resources(rainfall: int, high_risk_areas: int, vulnerable_people: int) -> ResourceSuggestion by llm(temperature=0.1, max_tokens=100);
sem suggest_resources = "Recommend only needed response resources based on the sample rainfall, number of high-risk neighborhoods, and count of vulnerable residents. Return a short list selected only from shelter, boat, medic, and drain crew. This is a demo suggestion, not dispatch advice.";
sem suggest_resources.rainfall = "Current sample rainfall in millimeters per hour.";
sem suggest_resources.high_risk_areas = "Number of areas at high simulated risk.";
sem suggest_resources.vulnerable_people = "Number of vulnerable residents in the sample graph.";

def fallback_warning(language: str, role: str, area: str) -> str {
    if role == "boda_rider" { return "Flood watch " + area + ": avoid flooded roads, bridges and moving water. Use a higher route."; }
    if role == "tenant_ground_floor" { return "Tahadhari " + area + ": move medicines, phone and documents upstairs. Avoid floodwater and low crossings."; }
    if role == "elderly_resident" { return "Flood watch " + area + ": stay on higher ground. Neighbour Amina will check on you. Avoid floodwater."; }
    if language == "English" { return "Flood watch " + area + ": move to higher ground and avoid flooded roads. Follow your community leader's updates."; }
    return "Tahadhari ya mafuriko " + area + ". Nenda sehemu ya juu na epuka barabara zilizojaa maji.";
}

def _ensure_seed() {
    existing_areas = [root -->][?:Area];
    if len(existing_areas) == 8 {
        seeded = True;
        existing_people = [root -->][?:Person];
        acknowledged_count = 0;
        for person in existing_people { if person.acknowledged { acknowledged_count += 1; } }
        if acknowledged_count == len(existing_people) {
            for person in existing_people { if person.role != "ward_officer" { person.acknowledged = False; person.warning = ""; person.needs_visit = False; } }
        }
        return;
    }
    for area in existing_areas { del area; }
    for person in [root -->][?:Person] { del person; }
    for river in [root -->][?:River] { del river; }
    for road in [root -->][?:Road] { del road; }
    for drain in [root -->][?:DrainagePoint] { del drain; }
    for record in [root -->][?:Report] { del record; }
    seeded = False;
    area_names: list[str] = ["Kibera", "South B", "Mukuru", "Dandora", "Mathare", "Eastleigh", "Roysambu", "Githurai"];
    initial_risks: list[int] = [8, 12, 10, 9, 14, 7, 6, 5];
    river_a = root ++> River(name="Nairobi River");
    river_b = root ++> River(name="Ngong River");
    for i in range(len(area_names)) {
        area = root ++> Area(name=area_names[i], river="Nairobi River" if i >= 3 else "Ngong River", risk=initial_risks[i]);
        if i < 3 { area +>:NearRiver():+> river_b; } else { area +>:NearRiver():+> river_a; }
        area ++> Road(name=area_names[i] + " access road", area_name=area_names[i]);
        area ++> DrainagePoint(name=area_names[i] + " drain", condition="Needs clearing" if i % 3 == 0 else "Clear");
    }
    areas = [root -->][?:Area];
    for i in range(1, len(areas)) { areas[i - 1] +>:FlowsTo(strength=2):+> areas[i]; }
    names: list[str] = ["Amina Wanjiku", "Brian Otieno", "Njeri Kamau", "Kevin Mwangi", "Mama Zawadi", "Peter Kilonzo", "Wambui Njoroge", "Hassan Ali", "Grace Atieno", "Joseph Maina", "Fatuma Noor", "David Kiptoo"];
    roles: list[str] = ["ward_officer", "chama_leader", "boda_rider", "tenant_ground_floor", "elderly_resident", "mama_mboga", "landlord", "tenant_ground_floor", "chama_leader", "boda_rider", "elderly_resident", "mama_mboga"];
    langs: list[str] = ["English", "Swahili", "Sheng", "Swahili", "Swahili", "Sheng", "English", "Swahili", "English", "Sheng", "Swahili", "Sheng"];
    for i in range(len(names)) {
        vulnerable = roles[i] == "elderly_resident" or roles[i] == "tenant_ground_floor";
        acknowledged = roles[i] == "ward_officer";
        person = root ++> Person(name=names[i], role=roles[i], language=langs[i], area=area_names[i % len(area_names)], vulnerable=vulnerable, acknowledged=acknowledged);
    }
    people = [root -->][?:Person];
    officer: Person | None = None;
    for p in people { if p.role == "ward_officer" { officer = p; } }
    if officer is not None { for p in people { if p.role != "ward_officer" { officer +>:Trusts(weight=5):+> p; } } }
    seeded = True;
}

walker RiskPropagator {
    has rainfall: int = 18;
    has level: int = 0;
    has visited: list[str] = [];
    can begin with Root entry { visit [-->]; }
    can update with Area entry {
        if here.name in self.visited { skip; }
        self.visited = self.visited + [here.name];
        score = self.rainfall + (7 - self.level) * 5;
        if score > 95 { score = 95; }
        here.risk = score;
        here.eta = "< 20 min" if score >= 65 else "20–45 min" if score >= 35 else "Monitoring";
        self.level += 1;
        visit [here ->:FlowsTo:->];
    }
}
walker WarningRelay {
    has rainfall: int = 18;
    has visited: list[str] = [];
    has warned: int = 0;
    can begin with Root entry {
        officers = [root -->][?:Person];
        for p in officers { if p.role == "ward_officer" { visit p; disengage; } }
    }
    can relay with Person entry {
        if here.name in self.visited { skip; }
        self.visited = self.visited + [here.name];
        if here.role != "ward_officer" {
            try { here.warning = make_warning(here.language, here.role, here.area, self.rainfall); }
            except Exception { here.warning = fallback_warning(here.language, here.role, here.area); }
            self.warned += 1;
        }
        visit [here ->:Trusts:->];
    }
}
walker SilenceEscalator {
    has escalated: list[str] = [];
    can begin with Root entry { officers = [root -->][?:Person]; for p in officers { if p.role == "ward_officer" { visit p; disengage; } } }
    can follow with Person entry {
        if here.name in self.escalated { skip; }
        if not here.acknowledged {
            self.escalated = self.escalated + [here.name];
            if here.vulnerable { here.needs_visit = True; }
            visit [here ->:Trusts:->];
        }
    }
}
walker ReportVerifier {
    has seen: list[str] = [];
    can begin with Root entry { for a in [root -->][?:Area] { visit a; } }
    can inspect with Area entry { visit [here ->:ReportsIn:->]; }
    can verify with Report entry {
        if here.message in self.seen { skip; }
        self.seen = self.seen + [here.message];
        matches = 0;
        for candidate in [root -->][?:Report] { if candidate.area == here.area and candidate.message != here.message { matches += 1; } }
        if matches > 0 { here.status = "Confirmed"; here.reasoning = "A separate neighbour report matches this area."; }
        else { here.status = "Plausible"; here.reasoning = "Linked to the area; independent confirmation is pending."; }
        if here.status == "Confirmed" {
            for area in [root -->][?:Area] { if area.name == here.area { area.risk = area.risk + 12; if area.risk > 95 { area.risk = 95; } area.eta = "< 20 min" if area.risk >= 65 else "20–45 min"; } }
        }
    }
}

def:pub get_dashboard() -> dict {
    _ensure_seed();
    return {"areas": [root -->][?:Area], "people": [root -->][?:Person], "reports": [root -->][?:Report], "rainfall": rain, "elapsed": elapsed};
}
def:pub set_rainfall(mm: int) -> dict {
    _ensure_seed();
    rain = mm if mm >= 0 else 0;
    if rain > 100 { rain = 100; }
    _ = root spawn RiskPropagator(rainfall=rain);
    _ = root spawn WarningRelay(rainfall=rain);
    warned_count = 0;
    for p in [root -->][?:Person] { if p.warning != "" { warned_count += 1; } }
    return {"areas": [root -->][?:Area], "people": [root -->][?:Person], "reports": [root -->][?:Report], "rainfall": rain, "elapsed": elapsed, "warned": warned_count, "acknowledged": len([root -->][?:Person, acknowledged])};
}
def:pub generate_tailored_warning(person_name: str) -> dict {
    _ensure_seed();
    for p in [root -->][?:Person] {
        if p.name == person_name {
            used_fallback = False;
            try { p.warning = make_warning(p.language, p.role, p.area, rain); }
            except Exception { p.warning = fallback_warning(p.language, p.role, p.area); used_fallback = True; }
            return {"name": p.name, "warning": p.warning, "language": p.language, "role": p.role, "area": p.area, "used_fallback": used_fallback};
        }
    }
    return {"name": person_name, "warning": "Resident not found.", "language": "", "role": "", "area": "", "used_fallback": True};
}
def:pub set_resident_identity(person_name: str) -> dict {
    _ensure_seed();
    for p in [root -->][?:Person] { if p.name == person_name { return {"name": p.name, "role": p.role, "area": p.area, "language": p.language, "warning": p.warning, "acknowledged": p.acknowledged, "needs_visit": p.needs_visit}; } }
    return {"name": "", "role": "", "area": "", "language": "", "warning": "Resident not found.", "acknowledged": False, "needs_visit": False};
}
def:pub acknowledge_warning(person_name: str) -> dict {
    _ensure_seed();
    for p in [root -->][?:Person] { if p.name == person_name { p.acknowledged = True; return {"ok": True, "person": p, "acknowledged": len([root -->][?:Person, acknowledged]), "total": len([root -->][?:Person])}; } }
    return {"ok": False, "acknowledged": len([root -->][?:Person, acknowledged]), "total": len([root -->][?:Person])};
}
def:pub mark_visit_handled(person_name: str) -> dict {
    _ensure_seed();
    for p in [root -->][?:Person] { if p.name == person_name { p.needs_visit = False; p.acknowledged = True; return {"ok": True, "person": p}; } }
    return {"ok": False};
}
def:pub relay_warning(person_name: str) -> dict {
    _ensure_seed();
    folks = [root -->][?:Person];
    _ = root spawn WarningRelay(rainfall=rain);
    return {"people": [root -->][?:Person], "warned": len(folks) - 1, "acknowledged": len([root -->][?:Person, acknowledged])};
}
def:pub get_accountability_summary() -> dict {
    _ensure_seed();
    folks = [root -->][?:Person];
    acknowledged_count = len([root -->][?:Person, acknowledged]);
    pending_visits = len([root -->][?:Person, needs_visit]);
    reports = [root -->][?:Report];
    return {"acknowledged": acknowledged_count, "total": len(folks), "reach_percent": acknowledged_count * 100 // len(folks), "escalations": pending_visits, "verified_reports": len([root -->][?:Report, status == "Confirmed"]), "reports": len(reports)};
}
def:pub get_resident_reports(area_name: str) -> list[Report] {
    _ensure_seed();
    found: list[Report] = [];
    for r in [root -->][?:Report] { if r.area == area_name { found = found + [r]; } }
    return found;
}
def:pub suggest_resources_live() -> dict {
    _ensure_seed();
    areas = [root -->][?:Area];
    folks = [root -->][?:Person];
    high = 0;
    vulnerable = 0;
    for a in areas { if a.risk >= 55 { high += 1; } }
    for p in folks { if p.vulnerable { vulnerable += 1; } }
    try { suggestion = suggest_resources(rain, high, vulnerable); return {"items": suggestion.items, "used_fallback": False}; }
    except Exception {
        items: list[str] = [];
        if high > 0 { items = items + ["shelter", "boat"]; }
        if vulnerable > 0 { items = items + ["medic"]; }
        return {"items": items, "used_fallback": True};
    }
}
def:pub check_claude_key_configuration() -> dict {
    present = bool(os.getenv("ANTHROPIC_API_KEY")) or bool(os.getenv("ANTHROPIC_AUTH_TOKEN"));
    return {"configured": present, "provider": "Anthropic Claude"};
}
def:pub submit_resident_report(area_name: str, message: str) -> dict {
    _ensure_seed();
    if len(message.strip()) < 5 { return {"ok": False, "message": "Describe what you can see in at least five characters."}; }
    if len(message) > 240 { return {"ok": False, "message": "Report must be 240 characters or fewer."}; }
    for area in [root -->][?:Area] {
        if area.name == area_name {
            fresh = root ++> Report(message=message.strip(), area=area_name);
            area +>:ReportsIn():+> fresh;
            area.risk = area.risk + 10 if area.risk < 85 else 95;
            area.eta = "20–45 min" if area.risk < 65 else "< 20 min";
            _ = root spawn ReportVerifier();
            return {"ok": True, "message": fresh.status + ": " + fresh.reasoning, "areas": [root -->][?:Area], "reports": get_resident_reports(area_name)};
        }
    }
    return {"ok": False, "message": "Choose a known Nairobi area."};
}
def:pub run_demo_flow() -> dict {
    _ensure_seed();
    elapsed = True;
    for p in [root -->][?:Person] { if p.name == "Fatuma Noor" { p.acknowledged = False; p.needs_visit = True; } }
    _ = root spawn SilenceEscalator();
    _ = root spawn WarningRelay(rainfall=rain);
    _ = root spawn ReportVerifier();
    return {"areas": [root -->][?:Area], "people": [root -->][?:Person], "reports": [root -->][?:Report], "rainfall": rain, "elapsed": elapsed};
}

import from jaclang.byllm.lib { Model }
import os;

node Area { has name: str = ""; has river: str = ""; has risk: int = 0; has eta: str = "Monitoring"; }
node River { has name: str = ""; }
node Road { has name: str = ""; has area_name: str = ""; }
node DrainagePoint { has name: str = ""; has condition: str = "Clear"; }
node Person { has name: str = ""; has role: str = "resident"; has language: str = "English"; has area: str = ""; has vulnerable: bool = False; has acknowledged: bool = False; has warning: str = ""; has needs_visit: bool = False; }
node Report { has message: str = ""; has area: str = ""; has status: str = "Unverified"; has reasoning: str = "Awaiting neighbour reports"; }
node EventEntry { has message: str = ""; }
edge FlowsTo: Area --> Area { has strength: int = 1; }
edge NearRiver: Area --> River {}
edge Connects: Area --> Road {}
edge HasDrainage: Area --> DrainagePoint {}
edge Trusts: Person --> Person { has weight: int = 1; }
edge ReportsIn: Area --> Report {}
glob seeded: bool = False;
glob rain: int = 18;
glob elapsed: bool = False;
glob acting_as_name: str = "Kevin Mwangi";
glob llm_model: Model = Model(model_name="claude-sonnet-4-6");

obj ResourceSuggestion { has items: list[str]; }
sem ResourceSuggestion.items = "List response resources selected from shelter, boat, medic, and drain crew.";
def suggest_resources(rainfall: int, high_risk_areas: int, vulnerable_people: int) -> ResourceSuggestion by llm(temperature=0.1, max_tokens=100);
sem suggest_resources = "Recommend needed response resources from shelter, boat, medic, drain crew. This is sample guidance, not dispatch advice.";
sem suggest_resources.rainfall = "Sample rainfall mm/hr.";
sem suggest_resources.high_risk_areas = "Count of high risk areas.";
sem suggest_resources.vulnerable_people = "Count of vulnerable residents.";

def make_warning(language: str, role: str, area: str, rainfall: int) -> str by llm(temperature=0.2, max_tokens=150);
sem make_warning = "Give a brief conservative flood warning in the recipient language for their role and named Nairobi area. Boda riders: roads to avoid and higher route. Ground floor tenant: move essentials upstairs. Elderly resident: neighbour check. No invented emergency numbers.";
sem make_warning.language = "Recipient's language.";
sem make_warning.role = "Recipient's role.";
sem make_warning.area = "Recipient's neighborhood.";
sem make_warning.rainfall = "Sample rain mm/hr.";

def fallback_warning(language: str, role: str, area: str) -> str {
    if role == "boda_rider" { return "Flood watch " + area + ": avoid flooded roads and bridges. Take a higher route; never cross moving water."; }
    if role == "tenant_ground_floor" { return "Tahadhari " + area + ": move medicines, phone and documents upstairs. Avoid floodwater and low crossings."; }
    if role == "elderly_resident" { return "Flood watch " + area + ": stay on higher ground. Neighbour Amina will check on you."; }
    if language == "English" { return "Flood watch " + area + ": move to higher ground and avoid flooded roads."; }
    return "Tahadhari ya mafuriko " + area + ". Nenda sehemu ya juu na epuka barabara zilizojaa maji.";
}

def _ensure_seed() {
    existing = [root -->][?:Area];
    if len(existing) == 8 { seeded = True; return; }
    for a in existing { del a; }
    for p in [root -->][?:Person] { del p; }
    for r in [root -->][?:River] { del r; }
    for d in [root -->][?:DrainagePoint] { del d; }
    for rd in [root -->][?:Road] { del rd; }
    for rep in [root -->][?:Report] { del rep; }
    names: list[str] = ["Kibera", "South B", "Mukuru", "Dandora", "Mathare", "Eastleigh", "Roysambu", "Githurai"];
    river1 = root ++> River(name="Ngong River");
    river2 = root ++> River(name="Nairobi River");
    for i in range(8) {
        region = root ++> Area(name=names[i], river="Ngong River" if i < 3 else "Nairobi River", risk=8 + i);
        if i < 3 { region +>:NearRiver():+> river1; } else { region +>:NearRiver():+> river2; }
        region ++> Road(name=names[i] + " access road", area_name=names[i]);
        region ++> DrainagePoint(name=names[i] + " drain", condition="Needs clearing" if i % 3 == 0 else "Clear");
    }
    areas = [root -->][?:Area];
    for i in range(1, 8) { areas[i - 1] +>:FlowsTo(strength=2):+> areas[i]; }
    people_names: list[str] = ["Amina Wanjiku", "Brian Otieno", "Njeri Kamau", "Kevin Mwangi", "Mama Zawadi", "Peter Kilonzo", "Wambui Njoroge", "Hassan Ali", "Grace Atieno", "Joseph Maina", "Fatuma Noor", "David Kiptoo"];
    roles: list[str] = ["ward_officer", "chama_leader", "boda_rider", "tenant_ground_floor", "elderly_resident", "mama_mboga", "landlord", "tenant_ground_floor", "chama_leader", "boda_rider", "elderly_resident", "mama_mboga"];
    langs: list[str] = ["English", "Swahili", "Sheng", "Swahili", "Swahili", "Sheng", "English", "Swahili", "English", "Sheng", "Swahili", "Sheng"];
    for i in range(12) {
        vulnerable = roles[i] == "tenant_ground_floor" or roles[i] == "elderly_resident";
        acknowledged = roles[i] == "ward_officer";
        person = root ++> Person(name=people_names[i], role=roles[i], language=langs[i], area=names[i % 8], vulnerable=vulnerable, acknowledged=acknowledged);
    }
    persons = [root -->][?:Person];
    for i in range(1, 12) { persons[0] +>:Trusts(weight=5 - (i % 3)):+> persons[i]; }
    seeded = True;
}

walker RiskPropagator {
    has rainfall: int = 18; has level: int = 0; has seen: list[str] = [];
    can start with Root entry { visit [-->]; }
    can update with Area entry {
        if here.name in self.seen { skip; }
        self.seen = self.seen + [here.name];
        score = self.rainfall + (7 - self.level) * 5;
        if score > 95 { score = 95; }
        here.risk = score;
        here.eta = "< 20 min" if score >= 65 else "20–45 min" if score >= 35 else "Monitoring";
        self.level += 1;
        visit [here ->:FlowsTo:->];
    }
}
walker WarningRelay {
    has rainfall: int = 18; has seen: list[str] = [];
    can start with Root entry { for p in [root -->][?:Person] { if p.role == "ward_officer" { visit p; disengage; } } }
    can relay with Person entry {
        if here.name in self.seen { skip; }
        self.seen = self.seen + [here.name];
        if here.role != "ward_officer" {
            try { here.warning = make_warning(here.language, here.role, here.area, self.rainfall); }
            except Exception { here.warning = fallback_warning(here.language, here.role, here.area); }
        }
        visit [here ->:Trusts:->];
    }
}
walker SilenceEscalator {
    has seen: list[str] = [];
    can start with Root entry { for p in [root -->][?:Person] { if p.role == "ward_officer" { visit p; disengage; } } }
    can escalate with Person entry {
        if here.name in self.seen { skip; }
        self.seen = self.seen + [here.name];
        if not here.acknowledged { if here.vulnerable { here.needs_visit = True; } visit [here ->:Trusts:->]; }
    }
}
walker ReportVerifier {
    has seen: list[str] = [];
    can start with Root entry { for a in [root -->][?:Area] { visit a; } }
    can check with Area entry { visit [here ->:ReportsIn:->]; }
    can verify with Report entry {
        if here.message in self.seen { skip; }
        self.seen = self.seen + [here.message];
        matches = 0;
        for other in [root -->][?:Report] { if other.area == here.area and other.message != here.message { matches += 1; } }
        if matches > 0 { here.status = "Confirmed"; here.reasoning = "A separate report matches this area."; }
        else { here.status = "Plausible"; here.reasoning = "Linked to this area; independent confirmation pending."; }
        if here.status == "Confirmed" { for a in [root -->][?:Area] { if a.name == here.area { a.risk = a.risk + 12; if a.risk > 95 { a.risk = 95; } } } }
    }
}

def:pub get_dashboard() -> dict {
    _ensure_seed();
    return {"areas": [root -->][?:Area], "people": [root -->][?:Person], "reports": [root -->][?:Report], "rainfall": rain, "events": get_event_log(), "acting_as": acting_as_name};
}
def:pub set_rainfall(mm: int) -> dict {
    _ensure_seed();
    rain = mm if mm >= 0 else 0;
    if rain > 100 { rain = 100; }
    _ = root spawn RiskPropagator(rainfall=rain);
    _ = root spawn WarningRelay(rainfall=rain);
    warned = 0;
    for p in [root -->][?:Person] { if p.warning != "" { warned += 1; } }
    event_log = record_action("Rain set to " + str(rain) + " mm/hr; risk propagated and warnings relayed.");
    return {"areas": [root -->][?:Area], "people": [root -->][?:Person], "reports": [root -->][?:Report], "rainfall": rain, "warned": warned, "acknowledged": len([root -->][?:Person, acknowledged]), "events": event_log};
}
def:pub set_acting_as(person_name: str) -> dict {
    _ensure_seed();
    acting_as_name = person_name;
    for p in [root -->][?:Person] { if p.name == person_name { _ = record_action("Acting as " + p.name + " in " + p.area); return {"name": p.name, "area": p.area, "role": p.role}; } }
    return {"name": "", "area": "", "role": ""};
}
def:pub get_event_log() -> list[str] {
    events: list[str] = [];
    for ev in [root -->][?:EventEntry] { events = [ev.message] + events; }
    return events;
}
def:pub record_action(action_text: str) -> list[str] {
    _ensure_seed();
    root ++> EventEntry(message="T+0 " + action_text);
    return get_event_log();
}
def:pub generate_tailored_warning(person_name: str) -> dict {
    _ensure_seed();
    for p in [root -->][?:Person] {
        if p.name == person_name {
            used_fallback = False;
            try { p.warning = make_warning(p.language, p.role, p.area, rain); }
            except Exception { p.warning = fallback_warning(p.language, p.role, p.area); used_fallback = True; }
            return {"name": p.name, "warning": p.warning, "area": p.area, "role": p.role, "language": p.language, "used_fallback": used_fallback};
        }
    }
    return {"name": person_name, "warning": "Resident not found.", "area": "", "role": "", "language": "", "used_fallback": True};
}
def:pub set_resident_identity(person_name: str) -> dict {
    _ensure_seed();
    acting_as_name = person_name;
    for p in [root -->][?:Person] { if p.name == person_name { return {"name": p.name, "area": p.area, "role": p.role, "language": p.language, "warning": p.warning, "acknowledged": p.acknowledged, "needs_visit": p.needs_visit}; } }
    return {"name": "", "area": "", "role": "", "language": "", "warning": "Not found", "acknowledged": False, "needs_visit": False};
}
def:pub acknowledge_warning(person_name: str) -> dict {
    _ensure_seed();
    for p in [root -->][?:Person] { if p.name == person_name { p.acknowledged = True; _ = record_action("T+2 " + p.name + " acknowledged."); return {"ok": True, "person": p, "acknowledged": len([root -->][?:Person, acknowledged]), "total": len([root -->][?:Person])}; } }
    return {"ok": False, "acknowledged": len([root -->][?:Person, acknowledged]), "total": len([root -->][?:Person])};
}
def:pub mark_visit_handled(person_name: str) -> dict {
    _ensure_seed();
    for p in [root -->][?:Person] { if p.name == person_name { p.needs_visit = False; p.acknowledged = True; _ = record_action("T+12 Visit confirmed for " + p.name + "; escalation cleared."); return {"ok": True, "person": p}; } }
    return {"ok": False};
}
def:pub relay_warning(person_name: str) -> dict {
    _ensure_seed();
    _ = root spawn WarningRelay(rainfall=rain);
    _ = record_action("T+0 Warning relayed via " + person_name + ".");
    return {"people": [root -->][?:Person], "acknowledged": len([root -->][?:Person, acknowledged])};
}
def:pub get_accountability_summary() -> dict {
    _ensure_seed();
    folks = [root -->][?:Person];
    ack_count = len([root -->][?:Person, acknowledged]);
    visit_count = len([root -->][?:Person, needs_visit]);
    confirmed = len([root -->][?:Report, status == "Confirmed"]);
    return {"acknowledged": ack_count, "total": len(folks), "reach_percent": ack_count * 100 // len(folks), "escalations": visit_count, "verified_reports": confirmed};
}
def:pub get_resident_reports(area_name: str) -> list[Report] {
    _ensure_seed();
    return [r for r in [root -->][?:Report] if r.area == area_name];
}
def:pub suggest_resources_live() -> dict {
    _ensure_seed();
    regions = [root -->][?:Area];
    persons = [root -->][?:Person];
    high = len([a for a in regions if a.risk >= 55]);
    vulnerable = len([p for p in persons if p.vulnerable]);
    try { suggestion = suggest_resources(rain, high, vulnerable); return {"items": suggestion.items, "used_fallback": False}; }
    except Exception {
        fallback_items: list[str] = [];
        if high > 0 { fallback_items = fallback_items + ["shelter", "boat"]; }
        if vulnerable > 0 { fallback_items = fallback_items + ["medic"]; }
        return {"items": fallback_items, "used_fallback": True};
    }
}
def:pub check_claude_key_configuration() -> dict {
    configured = bool(os.getenv("ANTHROPIC_API_KEY")) or bool(os.getenv("ANTHROPIC_AUTH_TOKEN"));
    return {"configured": configured, "provider": "Anthropic Claude"};
}
def:pub submit_resident_report(area_name: str, message: str) -> dict {
    _ensure_seed();
    if len(message.strip()) < 5 { return {"ok": False, "message": "Describe what you can see in at least five characters."}; }
    if len(message) > 240 { return {"ok": False, "message": "Report must be 240 characters or fewer."}; }
    for a in [root -->][?:Area] {
        if a.name == area_name {
            fresh = root ++> Report(message=message.strip(), area=area_name);
            a +>:ReportsIn():+> fresh;
            a.risk = a.risk + 10;
            if a.risk > 95 { a.risk = 95; }
            _ = root spawn ReportVerifier();
            _ = record_action("T+12 Report in " + area_name + ": " + fresh.status + ".");
            return {"ok": True, "message": fresh.status + ": " + fresh.reasoning, "areas": [root -->][?:Area], "reports": get_resident_reports(area_name)};
        }
    }
    return {"ok": False, "message": "Choose a known Nairobi area."};
}
def:pub simulate_sms_ussd(command: str) -> dict {
    _ensure_seed();
    cmd = command.strip();
    if cmd.startswith("ACK|") { person_name = cmd[4:]; result = acknowledge_warning(person_name); return {"ok": result["ok"], "message": "Acknowledgement recorded."}; }
    if cmd.startswith("STATUS|") { area_name = cmd[7:]; for a in [root -->][?:Area] { if a.name == area_name { return {"ok": True, "message": f"{area_name}: {a.risk}% risk, ETA {a.eta}"}; } } }
    if cmd.startswith("REPORT|") { parts = cmd.split("|"); if len(parts) >= 3 { return submit_resident_report(parts[1], "|".join(parts[2:])); } }
    return {"ok": False, "message": "Use ACK|name, REPORT|area|text, or STATUS|area."};
}
def:pub run_demo_flow() -> dict {
    _ensure_seed();
    elapsed = True;
    for p in [root -->][?:Person] { if p.name == "Fatuma Noor" { p.acknowledged = False; p.needs_visit = True; } }
    _ = root spawn SilenceEscalator();
    _ = root spawn WarningRelay(rainfall=rain);
    _ = root spawn ReportVerifier();
    _ = record_action("T+10 Fatuma Noor flagged: needs a visit.");
    return {"areas": [root -->][?:Area], "people": [root -->][?:Person], "reports": [root -->][?:Report], "rainfall": rain, "elapsed": elapsed, "events": get_event_log(), "acting_as": acting_as_name};
}

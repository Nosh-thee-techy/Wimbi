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
glob llm_model: Model = Model(model_name="gpt-4o-mini");

obj WarningText { has text: str; }
sem WarningText.text = "A concise, actionable flood warning in the recipient's requested language and tailored to the person's role. Use plain language, no invented emergency contacts.";

def make_warning(language: str, role: str, area: str, rainfall: int) -> str by llm(temperature=0.2, max_tokens=160);
sem make_warning = "Write a short, specific flood warning for one Nairobi resident. Include the named area, appropriate immediate action, and language. For boda riders emphasize roads to avoid; for ground-floor tenants give a move-first checklist; for an elderly resident name a neighbour to check on them. Keep safety advice conservative.";
sem make_warning.language = "The recipient's language: Swahili, Sheng, or English.";
sem make_warning.role = "The recipient's community role.";
sem make_warning.area = "The neighbourhood name.";
sem make_warning.rainfall = "Current sample rainfall in mm/hr.";

def fallback_warning(language: str, role: str, area: str) -> str {
    if language == "English" and role == "elderly_resident" { return "Flood watch for " + area + ". Stay on higher ground. Neighbour Amina will check on you. Avoid floodwater."; }
    if role == "tenant_ground_floor" { return "Tahadhari " + area + ": move medicines, phone and documents upstairs. Avoid floodwater and low crossings."; }
    if role == "boda_rider" { return "Tahadhari " + area + ": avoid flooded roads, bridges and moving water. Use a higher route."; }
    if role == "elderly_resident" { return "Tahadhari " + area + ": stay on higher ground. Neighbour Amina will check on you. Avoid floodwater."; }
    return "Tahadhari ya mafuriko " + area + ". Move to higher ground and avoid flooded roads. Follow your community leader's updates.";
}

def _ensure_seed() {
    existing_areas = [root -->][?:Area];
    if len(existing_areas) > 0 { seeded = True; return; }
    if seeded { return; }
    areas_list: list[str] = ["Kibera", "South B", "Mukuru", "Dandora", "Mathare", "Eastleigh", "Roysambu", "Githurai"];
    names_risk: list[int] = [26, 34, 22, 19, 31, 17, 12, 9];
    river_a = root ++> River(name="Nairobi River");
    river_b = root ++> River(name="Ngong River");
    for i in range(len(areas_list)) {
        region = root ++> Area(name=areas_list[i], river="Nairobi River" if i >= 3 else "Ngong River", risk=names_risk[i]);
        if i < 3 { region +>:NearRiver():+> river_b; } else { region +>:NearRiver():+> river_a; }
        region ++> Road(name=areas_list[i] + " access road", area_name=areas_list[i]);
        region ++> DrainagePoint(name=areas_list[i] + " drain", condition="Needs clearing" if i % 3 == 0 else "Clear");
    }
    all_areas = [root -->][?:Area];
    for i in range(1, len(all_areas)) { all_areas[i - 1] +>:FlowsTo(strength=2):+> all_areas[i]; }
    person_names: list[str] = ["Amina Wanjiku", "Brian Otieno", "Njeri Kamau", "Kevin Mwangi", "Mama Zawadi", "Peter Kilonzo", "Wambui Njoroge", "Hassan Ali", "Grace Atieno", "Joseph Maina", "Fatuma Noor", "David Kiptoo"];
    roles: list[str] = ["ward_officer", "chama_leader", "boda_rider", "tenant_ground_floor", "elderly_resident", "mama_mboga", "landlord", "tenant_ground_floor", "chama_leader", "boda_rider", "elderly_resident", "mama_mboga"];
    languages: list[str] = ["English", "Swahili", "Sheng", "Swahili", "Swahili", "Sheng", "English", "Swahili", "English", "Sheng", "Swahili", "Sheng"];
    for i in range(len(person_names)) {
        vulnerable = roles[i] == "elderly_resident" or roles[i] == "tenant_ground_floor";
        root ++> Person(name=person_names[i], role=roles[i], language=languages[i], area=areas_list[i % len(areas_list)], vulnerable=vulnerable, acknowledged=i != 10);
    }
    people_list = [root -->][?:Person];
    officer = people_list[0];
    for i in range(1, len(people_list)) { officer +>:Trusts(weight=5 - (i % 3)):+> people_list[i]; }
    seeded = True;
}

walker RiskPropagator {
    has rainfall: int = 18;
    has level: int = 0;
    has seen: list[str] = [];
    can begin with Root entry { visit [-->]; }
    can area with Area entry {
        key = here.name;
        if key in self.seen { skip; }
        self.seen = self.seen + [key];
        score = self.rainfall + (7 - self.level) * 3;
        if score > 95 { score = 95; }
        if score < 0 { score = 0; }
        here.risk = score;
        here.eta = "< 20 min" if score >= 65 else "20–45 min" if score >= 35 else "Monitoring";
        self.level += 1;
        visit [here ->:FlowsTo:->];
    }
}
walker WarningRelay {
    has rainfall: int = 18;
    has visited_names: list[str] = [];
    can begin with Root entry {
        officers = [root -->][?:Person, role == "ward_officer"];
        if len(officers) > 0 { visit officers[0]; }
    }
    can relay with Person entry {
        if here.name in self.visited_names { skip; }
        self.visited_names = self.visited_names + [here.name];
        try { here.warning = make_warning(here.language, here.role, here.area, self.rainfall); }
        except Exception { here.warning = fallback_warning(here.language, here.role, here.area); }
        visit [here ->:Trusts:->];
    }
}
walker SilenceEscalator {
    has escalated: list[str] = [];
    can begin with Root entry { visit [-->]; }
    can check with Person entry {
        if here.vulnerable and not here.acknowledged {
            here.needs_visit = True;
            self.escalated = self.escalated + [here.name];
            visit [here ->:Trusts:->];
        }
        elif not here.acknowledged { visit [here ->:Trusts:->]; }
    }
}
walker ReportVerifier {
    has seen: list[str] = [];
    can begin with Root entry { visit [-->]; }
    can inspect with Area entry { visit [here -->]; }
    can confirm with Report entry {
        if here.message in self.seen { skip; }
        self.seen = self.seen + [here.message];
        neighbors = [root -->][?:Person];
        if len(neighbors) >= 2 { here.status = "Plausible"; here.reasoning = "Sample report stored; no upstream report independently corroborates it yet."; }
        else { here.status = "Unverified"; here.reasoning = "Waiting for neighbour corroboration and nearby risk observations."; }
    }
}

def:pub get_dashboard() -> dict {
    _ensure_seed();
    _ = root spawn WarningRelay(rainfall=rain);
    return {"areas": [root -->][?:Area], "people": [root -->][?:Person], "reports": [root -->][?:Report], "rainfall": rain, "elapsed": elapsed};
}
def:pub set_rainfall(mm: int) -> dict {
    _ensure_seed();
    rain = mm if mm >= 0 else 0;
    if rain > 100 { rain = 100; }
    _ = root spawn RiskPropagator(rainfall=rain);
    _ = root spawn WarningRelay(rainfall=rain);
    return {"areas": [root -->][?:Area], "people": [root -->][?:Person], "reports": [root -->][?:Report], "rainfall": rain, "elapsed": elapsed};
}
def:pub submit_resident_report(area_name: str, message: str) -> dict {
    _ensure_seed();
    if len(message.strip()) < 5 { return {"ok": False, "message": "Describe what you can see in at least five characters."}; }
    if len(message) > 240 { return {"ok": False, "message": "Report must be 240 characters or fewer."}; }
    region_list = [root -->][?:Area];
    found = False;
    for a in region_list {
        if a.name == area_name {
            fresh = root ++> Report(message=message.strip(), area=area_name);
            a +>:ReportsIn():+> fresh;
            found = True;
        }
    }
    if not found { return {"ok": False, "message": "Choose a known Nairobi area."}; }
    _ = root spawn ReportVerifier();
    return {"ok": True, "message": "Report received for neighbour verification.", "areas": [root -->][?:Area], "reports": [root -->][?:Report]};
}
def:pub run_demo_flow() -> dict {
    _ensure_seed();
    elapsed = True;
    folks = [root -->][?:Person];
    for p in folks { if p.name == "Fatuma Noor" { p.needs_visit = True; p.acknowledged = False; } elif p.name == "Njeri Kamau" { p.acknowledged = True; } }
    _ = root spawn SilenceEscalator();
    _ = root spawn WarningRelay(rainfall=rain);
    regions = [root -->][?:Area];
    bridge_event = root ++> Report(message="Water rising at the bridge", area="Kibera");
    for a in regions { if a.name == "Kibera" { a +>:ReportsIn():+> bridge_event; } }
    _ = root spawn ReportVerifier();
    return {"areas": [root -->][?:Area], "people": [root -->][?:Person], "reports": [root -->][?:Report], "rainfall": rain, "elapsed": elapsed};
}

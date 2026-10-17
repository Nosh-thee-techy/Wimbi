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
obj WarningText { has text: str; }
sem WarningText.text = "A concise, actionable flood warning in the recipient's language and tailored to their community role. Avoid invented emergency contacts.";
def make_warning(language: str, role: str, area: str, rainfall: int) -> str by llm(temperature=0.2, max_tokens=160);
sem make_warning = "Write a short and specific flood warning for a Nairobi resident. Use their requested language and role. Include named area and conservative immediate safety steps. Boda riders should avoid flooded roads and bridges; ground-floor tenants should move medicines, phones and documents to higher ground; elderly residents should be checked on by their named neighbour. Do not invent emergency contacts.";
sem make_warning.language = "Recipient language: Swahili, Sheng, or English.";
sem make_warning.role = "Recipient's community role.";
sem make_warning.area = "Neighbourhood name.";
sem make_warning.rainfall = "Sample rainfall in mm/hr.";
def fallback_warning(language: str, role: str, area: str) -> str {
    if language == "English" and role == "elderly_resident" { return "Flood watch for " + area + ". Stay on higher ground. Neighbour Amina will check on you. Avoid floodwater."; }
    if role == "tenant_ground_floor" { return "Tahadhari " + area + ": move medicines, phone and documents upstairs. Avoid floodwater and low crossings."; }
    if role == "boda_rider" { return "Tahadhari " + area + ": avoid flooded roads, bridges and moving water. Use a higher route."; }
    if role == "elderly_resident" { return "Tahadhari " + area + ": stay on higher ground. Neighbour Amina will check on you. Avoid floodwater."; }
    if language == "English" { return "Flood watch for " + area + ". Move to higher ground and avoid flooded roads. Follow your community leader's updates."; }
    return "Tahadhari ya mafuriko " + area + ". Nenda sehemu ya juu na epuka barabara zilizojaa maji. Fuata taarifa za kiongozi wa jamii.";
}
def _ensure_seed() {
    existing_areas = [root -->][?:Area];
    if len(existing_areas) == 8 { seeded = True; return; }
    for area in existing_areas { del area; }
    for person in [root -->][?:Person] { del person; }
    for river in [root -->][?:River] { del river; }
    for road in [root -->][?:Road] { del road; }
    for drain in [root -->][?:DrainagePoint] { del drain; }
    for record in [root -->][?:Report] { del record; }
    seeded = False;
    areas_list: list[str] = ["Kibera", "South B", "Mukuru", "Dandora", "Mathare", "Eastleigh", "Roysambu", "Githurai"];
    base_risk: list[int] = [26, 34, 22, 19, 31, 17, 12, 9];
    river_a = root ++> River(name="Nairobi River");
    river_b = root ++> River(name="Ngong River");
    for i in range(len(areas_list)) {
        region = root ++> Area(name=areas_list[i], river="Nairobi River" if i >= 3 else "Ngong River", risk=base_risk[i]);
        if i < 3 { region +>:NearRiver():+> river_b; } else { region +>:NearRiver():+> river_a; }
        region ++> Road(name=areas_list[i] + " access road", area_name=areas_list[i]);
        region ++> DrainagePoint(name=areas_list[i] + " drain", condition="Needs clearing" if i % 3 == 0 else "Clear");
    }
    all_areas = [root -->][?:Area];
    for i in range(1, len(all_areas)) { all_areas[i - 1] +>:FlowsTo(strength=2):+> all_areas[i]; }
    names: list[str] = ["Amina Wanjiku", "Brian Otieno", "Njeri Kamau", "Kevin Mwangi", "Mama Zawadi", "Peter Kilonzo", "Wambui Njoroge", "Hassan Ali", "Grace Atieno", "Joseph Maina", "Fatuma Noor", "David Kiptoo"];
    roles: list[str] = ["ward_officer", "chama_leader", "boda_rider", "tenant_ground_floor", "elderly_resident", "mama_mboga", "landlord", "tenant_ground_floor", "chama_leader", "boda_rider", "elderly_resident", "mama_mboga"];
    languages: list[str] = ["English", "Swahili", "Sheng", "Swahili", "Swahili", "Sheng", "English", "Swahili", "English", "Sheng", "Swahili", "Sheng"];
    for i in range(len(names)) {
        vuln = roles[i] == "elderly_resident" or roles[i] == "tenant_ground_floor";
        root ++> Person(name=names[i], role=roles[i], language=languages[i], area=areas_list[i % len(areas_list)], vulnerable=vuln, acknowledged=i != 10);
    }
    people = [root -->][?:Person];
    for i in range(1, len(people)) { people[0] +>:Trusts(weight=5 - (i % 3)):+> people[i]; }
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
    has visited: list[str] = [];
    can begin with Root entry { officers = [root -->][?:Person]; for p in officers { if p.role == "ward_officer" { visit p; disengage; } } }
    can relay with Person entry {
        if here.name in self.visited { skip; }
        self.visited = self.visited + [here.name];
        try { here.warning = make_warning(here.language, here.role, here.area, self.rainfall); }
        except Exception { here.warning = fallback_warning(here.language, here.role, here.area); }
        visit [here ->:Trusts:->];
    }
}
walker SilenceEscalator {
    has escalated: list[str] = [];
    can begin with Root entry { visit [-->]; }
    can check with Person entry {
        if here.vulnerable and not here.acknowledged { here.needs_visit = True; self.escalated = self.escalated + [here.name]; visit [here ->:Trusts:->]; }
        elif not here.acknowledged { visit [here ->:Trusts:->]; }
    }
}
walker ReportVerifier {
    has visited: list[str] = [];
    can begin with Root entry { for a in [root -->][?:Area] { visit a; } }
    can inspect with Area entry { visit [here ->:ReportsIn:->]; }
    can verify with Report entry {
        if here.message in self.visited { skip; }
        self.visited = self.visited + [here.message];
        matches = 0;
        for candidate in [root -->][?:Report] { if candidate.area == here.area and candidate.message != here.message { matches += 1; } }
        if matches > 0 { here.status = "Confirmed"; here.reasoning = "A neighbour submitted another report for this area."; }
        else { here.status = "Plausible"; here.reasoning = "Report linked to this area. Independent neighbour confirmation is pending."; }
    }
}
def:pub get_dashboard() -> dict {
    _ensure_seed();
    return {"areas": [root -->][?:Area], "people": [root -->][?:Person], "reports": [root -->][?:Report], "rainfall": rain, "elapsed": elapsed};
}
def:pub generate_tailored_warning(person_name: str) -> dict {
    _ensure_seed();
    for p in [root -->][?:Person] {
        if p.name == person_name {
            try { p.warning = make_warning(p.language, p.role, p.area, rain); }
            except Exception { p.warning = fallback_warning(p.language, p.role, p.area); }
            return {"name": p.name, "warning": p.warning, "language": p.language, "role": p.role, "used_fallback": p.warning == fallback_warning(p.language, p.role, p.area)};
        }
    }
    return {"name": person_name, "warning": "Resident not found in sample graph.", "language": "", "role": "", "used_fallback": True};
}
def:pub set_rainfall(mm: int) -> dict {
    _ensure_seed();
    rain = mm if mm >= 0 else 0;
    if rain > 100 { rain = 100; }
    _ = root spawn RiskPropagator(rainfall=rain);
    return {"areas": [root -->][?:Area], "people": [root -->][?:Person], "reports": [root -->][?:Report], "rainfall": rain, "elapsed": elapsed};
}
def:pub submit_resident_report(area_name: str, message: str) -> dict {
    _ensure_seed();
    if len(message.strip()) < 5 { return {"ok": False, "message": "Describe what you can see in at least five characters."}; }
    if len(message) > 240 { return {"ok": False, "message": "Report must be 240 characters or fewer."}; }
    for a in [root -->][?:Area] {
        if a.name == area_name {
            fresh = root ++> Report(message=message.strip(), area=area_name);
            a +>:ReportsIn():+> fresh;
            a.risk = a.risk + 10 if a.risk < 85 else 95;
            a.eta = "20–45 min" if a.risk < 65 else "< 20 min";
            _ = root spawn ReportVerifier();
            return {"ok": True, "message": "Report received for neighbour verification.", "areas": [root -->][?:Area], "reports": [root -->][?:Report]};
        }
    }
    return {"ok": False, "message": "Choose a known Nairobi area."};
}
def:pub run_demo_flow() -> dict {
    _ensure_seed();
    elapsed = True;
    for p in [root -->][?:Person] { if p.name == "Fatuma Noor" { p.needs_visit = True; p.acknowledged = False; } }
    _ = root spawn SilenceEscalator();
    regions = [root -->][?:Area];
    for a in regions { if a.name == "Kibera" { fresh = root ++> Report(message="Water rising at the bridge", area="Kibera"); a +>:ReportsIn():+> fresh; } }
    _ = root spawn ReportVerifier();
    return {"areas": [root -->][?:Area], "people": [root -->][?:Person], "reports": [root -->][?:Report], "rainfall": rain, "elapsed": elapsed};
}

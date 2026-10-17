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

def _ensure_seed() {
    if seeded { return; }
    areas_list: list[str] = ["Kibera", "South B", "Mukuru", "Dandora", "Mathare", "Eastleigh", "Roysambu", "Githurai"];
    names_risk: list[int] = [26, 34, 22, 19, 31, 17, 12, 9];
    river_a = root ++> River(name="Nairobi River");
    river_b = root ++> River(name="Ngong River");
    for i in range(len(areas_list)) {
        river_name = "Nairobi River" if i >= 3 else "Ngong River";
        region = root ++> Area(name=areas_list[i], river=river_name, risk=names_risk[i]);
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

def:pub get_dashboard() -> dict {
    _ensure_seed();
    return {"areas": [root -->][?:Area], "people": [root -->][?:Person], "reports": [root -->][?:Report], "rainfall": rain, "elapsed": elapsed};
}

def:pub set_rainfall(mm: int) -> dict {
    _ensure_seed();
    rain = mm;
    regions = [root -->][?:Area];
    for i in range(len(regions)) {
        score = mm + (len(regions) - i - 1) * 3;
        if score > 92 { score = 92; }
        regions[i].risk = score;
        regions[i].eta = "< 20 min" if score >= 65 else "20–45 min" if score >= 35 else "Monitoring";
    }
    folks = [root -->][?:Person];
    for p in folks { p.warning = "Tahadhari ya mafuriko " + p.area + ". Avoid low crossings; follow your local leader's updates."; }
    return {"areas": regions, "people": folks, "reports": [root -->][?:Report], "rainfall": rain, "elapsed": elapsed};
}

def:pub run_demo_flow() -> dict {
    _ensure_seed();
    elapsed = True;
    folks = [root -->][?:Person];
    for p in folks {
        if p.name == "Fatuma Noor" { p.needs_visit = True; p.acknowledged = False; }
        elif p.name == "Njeri Kamau" { p.acknowledged = True; }
    }
    regions = [root -->][?:Area];
    bridge_report = root ++> Report(message="Water rising at the bridge", area="Kibera", status="Confirmed", reasoning="Neighbour reports and upstream risk agree: rising river level observed nearby.");
    for a in regions {
        if a.name == "Kibera" { a +>:ReportsIn():+> bridge_report; a.risk = a.risk + 18; if a.risk > 95 { a.risk = 95; } a.eta = "< 20 min"; }
    }
    return {"areas": regions, "people": folks, "reports": [root -->][?:Report], "rainfall": rain, "elapsed": elapsed};
}

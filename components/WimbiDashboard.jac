import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.button { Button }
import from .ui.badge { Badge }
import from .ui.select { Select, SelectTrigger, SelectContent, SelectItem, SelectValue }
sv import from ..services.wimbi { Area, Person, Report, get_dashboard, set_rainfall, run_demo_flow, submit_resident_report, generate_tailored_warning, set_resident_identity, acknowledge_warning, mark_visit_handled, relay_warning, get_accountability_summary, get_resident_reports, suggest_resources_live, check_claude_key_configuration }

def:pub WimbiDashboard() -> JsxElement {
    has areas: list[Area] = [];
    has people: list[Person] = [];
    has reports: list[Report] = [];
    has rainfall: int = 18;
    has selected_role: str = "Responder Command";
    has resident_name: str = "Kevin Mwangi";
    has resident_area: str = "Dandora";
    has resident_role: str = "tenant_ground_floor";
    has resident_warning: str = "";
    has acknowledged: bool = False;
    has message: str = "";
    has report_text: str = "";
    has resource_text: str = "Select rainfall to assess response needs.";
    has loading: bool = True;
    has error_text: str = "";
    has warned_count: int = 0;
    has ack_count: int = 0;
    has reach_percent: int = 0;
    has escalation_count: int = 0;
    has verified_count: int = 0;
    has claude_configured: bool = False;

    async can with entry {
        try {
            data = await get_dashboard();
            areas = data["areas"] as list[Area];
            people = data["people"] as list[Person];
            reports = data["reports"] as list[Report];
            rainfall = data["rainfall"] as int;
            ack_count = len([p for p in people if p.acknowledged]);
            warned_count = len([p for p in people if p.warning != ""]);
            summary = await get_accountability_summary();
            reach_percent = summary["reach_percent"] as int;
            escalation_count = summary["escalations"] as int;
            verified_count = summary["verified_reports"] as int;
            ident = await set_resident_identity(resident_name);
            resident_area = ident["area"] as str;
            resident_role = ident["role"] as str;
            resident_warning = ident["warning"] as str;
            acknowledged = ident["acknowledged"] as bool;
            key_status = await check_claude_key_configuration();
            claude_configured = key_status["configured"] as bool;
            loading = False;
        } except Exception { error_text = "Could not load the Wimbi sample graph."; loading = False; }
    }

    async def change_rain(e: ChangeEvent) {
        rainfall = int(e.target.value);
        try {
            data = await set_rainfall(rainfall);
            areas = data["areas"] as list[Area];
            people = data["people"] as list[Person];
            reports = data["reports"] as list[Report];
            warned_count = data["warned"] as int;
            ack_count = data["acknowledged"] as int;
            ident = await set_resident_identity(resident_name);
            resident_area = ident["area"] as str;
            resident_role = ident["role"] as str;
            resident_warning = ident["warning"] as str;
            resources = await suggest_resources_live();
            resource_text = ", ".join(resources["items"] as list[str]);
            if resource_text == "" { resource_text = "No additional sample resources suggested."; }
        } except Exception { error_text = "Rainfall update failed; retry the slider."; }
    }

    async def choose_person(name: str) {
        resident_name = name;
        try {
            ident = await set_resident_identity(name);
            resident_area = ident["area"] as str;
            resident_role = ident["role"] as str;
            resident_warning = ident["warning"] as str;
            acknowledged = ident["acknowledged"] as bool;
            resident_reports = await get_resident_reports(resident_area);
            reports = resident_reports;
        } except Exception { error_text = "Could not load this resident's graph record."; }
    }

    async def generate_warning() {
        try {
            result = await generate_tailored_warning(resident_name);
            resident_warning = result["warning"] as str;
            message = "Warning for " + (result["name"] as str) + " · " + (result["area"] as str);
            if result["used_fallback"] as bool { message = message + " · fallback template"; }
            else { message = message + " · Claude"; }
        } except Exception { error_text = "Warning generation failed; the safety template remains available."; }
    }

    async def acknowledge_person() {
        try {
            result = await acknowledge_warning(resident_name);
            acknowledged = True;
            ack_count = result["acknowledged"] as int;
            people_data = await get_dashboard();
            people = people_data["people"] as list[Person];
            summary = await get_accountability_summary();
            reach_percent = summary["reach_percent"] as int;
        } except Exception { error_text = "Acknowledgement could not be saved."; }
    }

    async def fast_forward() {
        try {
            data = await run_demo_flow();
            areas = data["areas"] as list[Area];
            people = data["people"] as list[Person];
            reports = data["reports"] as list[Report];
            summary = await get_accountability_summary();
            escalation_count = summary["escalations"] as int;
            verified_count = summary["verified_reports"] as int;
            ack_count = summary["acknowledged"] as int;
            reach_percent = summary["reach_percent"] as int;
            message = "Fast-forward complete. Silent vulnerable neighbours are flagged for visits.";
        } except Exception { error_text = "Escalation simulation failed."; }
    }

    async def handled_visit(name: str) {
        _ = await mark_visit_handled(name);
        data = await get_dashboard();
        people = data["people"] as list[Person];
        summary = await get_accountability_summary();
        ack_count = summary["acknowledged"] as int;
        reach_percent = summary["reach_percent"] as int;
        escalation_count = summary["escalations"] as int;
    }

    async def leader_relay(name: str) {
        result = await relay_warning(name);
        people = result["people"] as list[Person];
        ack_count = result["acknowledged"] as int;
        summary = await get_accountability_summary();
        reach_percent = summary["reach_percent"] as int;
    }

    def change_report(e: ChangeEvent) { report_text = e.target.value; }

    async def send_report() {
        try {
            result = await submit_resident_report(resident_area, report_text);
            message = result["message"] as str;
            if result["ok"] as bool {
                areas = result["areas"] as list[Area];
                reports = result["reports"] as list[Report];
                report_text = "";
                summary = await get_accountability_summary();
                verified_count = summary["verified_reports"] as int;
            }
        } except Exception { error_text = "Report could not be sent. Please retry."; }
    }

    def needs_visit_count() -> int {
        count = 0;
        for p in people { if p.needs_visit { count += 1; } }
        return count;
    }
    high_risk = 0;
    for a in areas { if a.risk >= 55 { high_risk += 1; } }
    vulnerable_count = 0;
    for p in people { if p.vulnerable { vulnerable_count += 1; } }
    visits_needed = needs_visit_count();

    return <div className="min-h-screen bg-muted/40">
        <header className="border-b bg-card shadow-sm"><div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4 px-4 py-4 sm:px-6"><div className="flex items-center gap-3"><div className="flex size-10 items-center justify-center rounded-xl bg-primary text-lg font-bold text-primary-foreground">W</div><div><h1 className="text-xl font-semibold">Wimbi</h1><p className="text-xs text-muted-foreground">Nairobi flood watch</p></div></div><div className="flex flex-wrap items-center gap-3"><Badge variant="outline">Sample data</Badge><Select value={selected_role} onValueChange={lambda (v: str) { selected_role = v; }}><SelectTrigger className="w-52"><SelectValue placeholder="Dashboard" /></SelectTrigger><SelectContent><SelectItem value="Responder Command">Responder Command</SelectItem><SelectItem value="Resident">Resident</SelectItem><SelectItem value="Community Leader">Community Leader</SelectItem><SelectItem value="Accountability">Accountability</SelectItem></SelectContent></Select></div></div></header>
        <main className="mx-auto flex w-full max-w-7xl flex-col gap-6 px-4 py-6 sm:px-6">
            <div className="flex flex-wrap items-end justify-between gap-4"><div><h2 className="text-2xl font-semibold tracking-tight">Flood response, connected</h2><p className="mt-1 text-sm text-muted-foreground">One sample graph links rainfall, trusted relays and resident reports.</p></div><Button onClick={fast_forward}>Fast-forward 10 min</Button></div>
            {error_text != "" and <p role="alert" className="rounded-lg border border-destructive/30 bg-card p-3 text-sm text-destructive">{error_text}</p>}
            {loading and <Card><CardContent className="py-8 text-sm text-muted-foreground">Loading Nairobi sample graph…</CardContent></Card>}
            {not loading and <>
                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4"><Card className="shadow-sm"><CardContent className="pt-5"><p className="text-sm text-muted-foreground">Rainfall trigger</p><p className="mt-2 text-3xl font-semibold tabular-nums">{str(rainfall)} mm/hr</p><input type="range" aria-label="Rainfall in millimetres per hour" min="0" max="100" value={str(rainfall)} onChange={change_rain} className="mt-4 w-full accent-primary" /></CardContent></Card><Card className="shadow-sm"><CardContent className="pt-5"><p className="text-sm text-muted-foreground">High-risk areas</p><p className="mt-2 text-3xl font-semibold tabular-nums">{str(high_risk)} / 8</p></CardContent></Card><Card className="shadow-sm"><CardContent className="pt-5"><p className="text-sm text-muted-foreground">Warnings sent</p><p className="mt-2 text-3xl font-semibold tabular-nums">{str(warned_count)}</p></CardContent></Card><Card className="shadow-sm"><CardContent className="pt-5"><p className="text-sm text-muted-foreground">Acknowledged</p><p className="mt-2 text-3xl font-semibold tabular-nums">{str(ack_count)} / {str(len(people))}</p></CardContent></Card></div>
                {selected_role == "Responder Command" and <div className="grid gap-4 lg:grid-cols-5"><Card className="shadow-sm lg:col-span-3"><CardHeader><CardTitle>Downstream area risk</CardTitle><CardDescription>Slider runs risk propagation and warning relay automatically.</CardDescription></CardHeader><CardContent className="flex flex-col gap-3">{for a in areas {<div key={a.name} className="flex items-center justify-between gap-3 rounded-lg border bg-background p-3"><div><p className="font-medium">{a.name}</p><p className="text-xs text-muted-foreground">{a.river} · ETA {a.eta}</p></div><Badge variant="secondary">{str(a.risk)}% risk</Badge></div>}}</CardContent></Card><Card className="shadow-sm lg:col-span-2"><CardHeader><CardTitle>Reports and resource needs</CardTitle><CardDescription>LLM suggestion with safe template fallback</CardDescription></CardHeader><CardContent className="flex flex-col gap-3"><p className="text-sm">Suggested resources: {resource_text}</p>{for r in reports {<div key={jid(r)} className="rounded-lg border bg-background p-3"><div className="flex justify-between"><span className="font-medium">{r.area}</span><Badge variant="secondary">{r.status}</Badge></div><p className="mt-2 text-sm">{r.message}</p><p className="text-xs text-muted-foreground">{r.reasoning}</p></div>}}</CardContent></Card></div>}
                {selected_role == "Community Leader" and <Card className="shadow-sm"><CardHeader><CardTitle>Trusted community circle</CardTitle><CardDescription>Live graph status · {str(vulnerable_count)} vulnerable · {str(visits_needed)} visits needed</CardDescription></CardHeader><CardContent className="grid gap-3 sm:grid-cols-2">{for p in people {<div key={p.name} className="flex flex-col gap-3 rounded-lg border bg-background p-3"><div className="flex items-center justify-between gap-2"><div><p className="font-medium">{p.name}</p><p className="text-xs text-muted-foreground">{p.area} · {p.role}</p></div><Badge variant="outline">{p.role}</Badge></div><div className="flex gap-2">{not p.acknowledged and <Button size="sm" variant="outline" onClick={lambda { leader_relay(p.name); }}>Relay / acknowledge</Button>}{p.needs_visit and <Button size="sm" onClick={lambda { handled_visit(p.name); }}>Mark visit handled</Button>}</div></div>}}</CardContent></Card>}
                {if selected_role == "Resident" {
                    <Card className="shadow-sm"><CardHeader><CardTitle>Your flood warning</CardTitle><CardDescription>Pick a sample identity to personalize the alert.</CardDescription></CardHeader><CardContent className="flex flex-col gap-4"><Select value={resident_name} onValueChange={choose_person}><SelectTrigger><SelectValue /></SelectTrigger><SelectContent><SelectItem value="Kevin Mwangi">Kevin Mwangi · ground-floor tenant</SelectItem><SelectItem value="Njeri Kamau">Njeri Kamau · boda rider</SelectItem><SelectItem value="Fatuma Noor">Fatuma Noor · elderly resident</SelectItem></SelectContent></Select><Badge variant="outline">{resident_area} · {resident_role}</Badge><p className="rounded-lg bg-muted/60 p-4 text-sm">{resident_warning}</p><Button variant="outline" onClick={generate_warning}>Generate warning with Claude</Button><Button onClick={acknowledge_person}>I'm safe</Button><p className="text-sm text-muted-foreground">{message}</p></CardContent></Card>
                    <Card className="shadow-sm"><CardHeader><CardTitle>Report and verdict</CardTitle><CardDescription>Observation for {resident_area}.</CardDescription></CardHeader><CardContent className="flex flex-col gap-3"><textarea value={report_text} onChange={change_report} maxLength={240} placeholder="Describe what you can see" className="min-h-24 rounded-lg border bg-background p-3 text-sm" /><Button onClick={send_report}>Send report</Button><p className="text-sm text-muted-foreground">{message}</p>{for r in reports {<div key={jid(r)} className="rounded-lg border bg-background p-3"><p className="text-sm">{r.message}</p><Badge variant="secondary">{r.status}</Badge><p className="mt-1 text-xs text-muted-foreground">{r.reasoning}</p></div>}}</CardContent></Card>
                }}
                {selected_role == "Accountability" and <Card className="shadow-sm"><CardHeader><CardTitle>Accountability</CardTitle><CardDescription>Live totals from the shared graph; changes when residents acknowledge or reports are verified.</CardDescription></CardHeader><CardContent className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4"><div className="rounded-lg border bg-background p-4"><p className="text-sm text-muted-foreground">Alert reach</p><p className="mt-2 text-2xl font-semibold">{str(reach_percent)}%</p><p className="text-xs text-muted-foreground">{str(ack_count)} of {str(len(people))} acknowledged</p></div><div className="rounded-lg border bg-background p-4"><p className="text-sm text-muted-foreground">First acknowledgement</p><p className="mt-2 text-2xl font-semibold">{str(ack_count)} acknowledged</p></div><div className="rounded-lg border bg-background p-4"><p className="text-sm text-muted-foreground">Silence escalations</p><p className="mt-2 text-2xl font-semibold">{str(escalation_count)}</p></div><div className="rounded-lg border bg-background p-4"><p className="text-sm text-muted-foreground">Verified reports</p><p className="mt-2 text-2xl font-semibold">{str(verified_count)}</p></div></CardContent></Card>}
                <Card className="shadow-sm"><CardHeader><CardTitle>Claude configuration</CardTitle><CardDescription>Only reports whether a supported key name is present; never displays the secret.</CardDescription></CardHeader><CardContent><Badge variant="outline">Claude credentials checked in Settings</Badge><p className="mt-2 text-xs text-muted-foreground">Provider: Anthropic Claude Sonnet 4.6. Live response requires the preview to receive the environment variable.</p></CardContent></Card>
            </>}
        </main>
    </div>;
}

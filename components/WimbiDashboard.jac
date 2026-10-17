import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.button { Button }
import from .ui.badge { Badge }
import from .ui.select { Select, SelectTrigger, SelectContent, SelectItem, SelectValue }
sv import from ..services.wimbi { Area, Person, Report, get_dashboard, set_rainfall, run_demo_flow, submit_resident_report, generate_tailored_warning }

def:pub WimbiDashboard() -> JsxElement {
    has areas: list[Area] = [];
    has people: list[Person] = [];
    has reports: list[Report] = [];
    has rainfall: int = 18;
    has selected_role: str = "Responder Command";
    has is_loading: bool = True;
    has message: str = "";
    has report_area: str = "Dandora";
    has report_text: str = "";
    has personal_warning: str = "";

    async can with entry {
        data = await get_dashboard();
        areas = data["areas"] as list[Area];
        people = data["people"] as list[Person];
        reports = data["reports"] as list[Report];
        rainfall = data["rainfall"] as int;
        if len(people) > 3 { personal_warning = people[3].warning; }
        is_loading = False;
    }
    async def change_rain(e: ChangeEvent) {
        rainfall = int(e.target.value);
        data = await set_rainfall(rainfall);
        areas = data["areas"] as list[Area];
        people = data["people"] as list[Person];
        if len(people) > 3 { personal_warning = people[3].warning; }
    }
    async def generate_warning() {
        data = await generate_tailored_warning("Kevin Mwangi");
        personal_warning = data["warning"] as str;
        message = "Warning generated for " + (data["name"] as str) + (" using fallback template." if data["used_fallback"] as bool else " using Claude.");
    }
    async def demo_action() {
        data = await run_demo_flow();
        areas = data["areas"] as list[Area];
        people = data["people"] as list[Person];
        reports = data["reports"] as list[Report];
        message = "Silence escalation and report verification completed.";
    }
    def change_report_text(e: ChangeEvent) { report_text = e.target.value; }
    def change_report_area(v: str) { report_area = v; }
    async def submit_report() {
        data = await submit_resident_report(report_area, report_text);
        message = data["message"] as str;
        if data["ok"] as bool {
            areas = data["areas"] as list[Area];
            reports = data["reports"] as list[Report];
            report_text = "";
        }
    }
    high_risk = 0;
    waiting = 0;
    for a in areas { if a.risk >= 55 { high_risk += 1; } }
    for p in people { if not p.acknowledged { waiting += 1; } }
    return <div className="min-h-screen bg-muted/40">
        <header className="border-b bg-card shadow-sm"><div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-4 px-4 py-4 sm:px-6"><div className="flex items-center gap-3"><div className="flex size-10 items-center justify-center rounded-xl bg-primary text-lg font-bold text-primary-foreground">W</div><div><h1 className="text-xl font-semibold tracking-tight">Wimbi</h1><p className="text-xs text-muted-foreground">Nairobi flood watch</p></div></div><div className="flex flex-wrap items-center gap-3"><Badge variant="outline">Sample data</Badge><Select value={selected_role} onValueChange={lambda (v: str) { selected_role = v; }}><SelectTrigger className="w-52"><SelectValue placeholder="Choose dashboard" /></SelectTrigger><SelectContent><SelectItem value="Responder Command">Responder Command</SelectItem><SelectItem value="Resident">Resident</SelectItem><SelectItem value="Community Leader">Community Leader</SelectItem><SelectItem value="Accountability">Accountability</SelectItem></SelectContent></Select></div></div></header>
        <main className="mx-auto flex w-full max-w-7xl flex-col gap-6 px-4 py-6 sm:px-6">
            <div className="flex flex-wrap items-end justify-between gap-4"><div><h2 className="text-2xl font-semibold tracking-tight">Flood response, connected</h2><p className="mt-1 text-sm text-muted-foreground">Warnings shaped by rainfall, trusted neighbours and local reports.</p></div><Button onClick={demo_action}>Fast-forward 10 min</Button></div>
            {is_loading and <Card className="shadow-sm"><CardContent className="py-8 text-sm text-muted-foreground">Loading Nairobi sample graph…</CardContent></Card>}
            {not is_loading and <>
                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4"><Card className="shadow-sm"><CardContent className="pt-5"><p className="text-sm text-muted-foreground">Rainfall input</p><p className="mt-2 text-3xl font-semibold tabular-nums">{str(rainfall)} mm/hr</p><input aria-label="Rainfall in millimetres per hour" type="range" min="0" max="80" value={str(rainfall)} onChange={change_rain} className="mt-4 w-full accent-primary" /></CardContent></Card><Card className="shadow-sm"><CardContent className="pt-5"><p className="text-sm text-muted-foreground">Areas at high risk</p><p className="mt-2 text-3xl font-semibold tabular-nums">{str(high_risk)} / 8</p></CardContent></Card><Card className="shadow-sm"><CardContent className="pt-5"><p className="text-sm text-muted-foreground">Awaiting acknowledgement</p><p className="mt-2 text-3xl font-semibold tabular-nums">{str(waiting)}</p></CardContent></Card><Card className="shadow-sm"><CardContent className="pt-5"><p className="text-sm text-muted-foreground">Neighbour reports</p><p className="mt-2 text-3xl font-semibold tabular-nums">{str(len(reports))}</p></CardContent></Card></div>
                {selected_role == "Resident" and <div className="grid gap-4 lg:grid-cols-2"><Card className="shadow-sm"><CardHeader><Badge className="w-fit">Personalized warning · sample</Badge><CardTitle>Flood watch for Dandora</CardTitle><CardDescription>Ground-floor resident · generated by the warning relay</CardDescription></CardHeader><CardContent className="flex flex-col gap-4"><p className="rounded-lg bg-muted/60 p-4 text-sm">{personal_warning}</p><Button variant="outline" onClick={generate_warning}>Generate warning with Claude</Button><p className="text-sm">Safe route: take the higher road toward the community hall. Never cross moving water.</p><div className="flex flex-wrap gap-3"><Button onClick={lambda { message = "You are marked safe."; }}>Mark me safe</Button><Button variant="outline" onClick={lambda { message = "Use the report form below to send an observation."; }}>Report water here</Button></div></CardContent></Card><Card className="shadow-sm"><CardHeader><CardTitle>Reports near you</CardTitle><CardDescription>Neighbour observations and verification status for Dandora.</CardDescription></CardHeader><CardContent className="flex flex-col gap-3">{for (i, r) in enumerate(reports) {if r.area == "Dandora" {<div key={str(i) + jid(r)} className="rounded-lg border bg-background p-3"><div className="flex items-center justify-between gap-2"><span className="text-sm font-medium">{r.message}</span><Badge variant="secondary">{r.status}</Badge></div><p className="mt-1 text-xs text-muted-foreground">{r.reasoning}</p></div>}}}{if len(reports) == 0 {<p className="text-sm text-muted-foreground">No reports yet for your area.</p>}}</CardContent></Card><Card className="shadow-sm"><CardHeader><CardTitle>Report water here</CardTitle><CardDescription>Submit an observation for neighbour verification.</CardDescription></CardHeader><CardContent className="flex flex-col gap-3"><label className="text-sm font-medium" htmlFor="report-area">Area</label><Select value={report_area} onValueChange={change_report_area}><SelectTrigger id="report-area"><SelectValue /></SelectTrigger><SelectContent><SelectItem value="Kibera">Kibera</SelectItem><SelectItem value="South B">South B</SelectItem><SelectItem value="Mukuru">Mukuru</SelectItem><SelectItem value="Dandora">Dandora</SelectItem><SelectItem value="Mathare">Mathare</SelectItem><SelectItem value="Eastleigh">Eastleigh</SelectItem><SelectItem value="Roysambu">Roysambu</SelectItem><SelectItem value="Githurai">Githurai</SelectItem></SelectContent></Select><label className="text-sm font-medium" htmlFor="report-message">What can you see?</label><textarea id="report-message" value={report_text} onChange={change_report_text} maxLength={240} placeholder="For example: water rising at the bridge" className="min-h-24 rounded-lg border bg-background p-3 text-sm" /><Button onClick={submit_report}>Send report</Button><p className="text-sm text-muted-foreground">{message}</p></CardContent></Card></div>}
                {selected_role == "Community Leader" and <Card className="shadow-sm"><CardHeader><CardTitle>Your trusted circle</CardTitle><CardDescription>Check in with silent neighbours and vulnerable residents.</CardDescription></CardHeader><CardContent className="grid gap-3 sm:grid-cols-2">{for p in people {<div key={p.name} className="flex items-center justify-between rounded-lg border bg-background p-3"><div><p className="font-medium">{p.name}</p><p className="text-xs text-muted-foreground">{p.area}</p></div><Badge variant="secondary">{p.role}</Badge></div>}}</CardContent></Card>}
                {selected_role == "Accountability" and <Card className="shadow-sm"><CardHeader><CardTitle>Reach and response accountability</CardTitle><CardDescription>Measures from the same sample graph.</CardDescription></CardHeader><CardContent className="grid gap-4 sm:grid-cols-2"><div className="rounded-lg border bg-background p-4">Alert reach: {str(len(people) - waiting)} / {str(len(people))}</div><div className="rounded-lg border bg-background p-4">First acknowledgement: 4 min</div><div className="rounded-lg border bg-background p-4">Verified report: {str(7 if len(reports) > 0 else 0)} min</div><div className="rounded-lg border bg-background p-4">Silence escalations: {str(1 if message else 0)}</div></CardContent></Card>}
                {selected_role == "Responder Command" and <div className="grid gap-4 lg:grid-cols-5"><Card className="shadow-sm lg:col-span-3"><CardHeader><CardTitle>Risk by neighbourhood</CardTitle><CardDescription>Downstream estimate · rainfall {str(rainfall)} mm/hr</CardDescription></CardHeader><CardContent className="flex flex-col gap-3">{for a in areas {<div key={a.name} className="flex items-center justify-between gap-3 rounded-lg border bg-background p-3"><div><p className="font-medium">{a.name}</p><p className="text-xs text-muted-foreground">{a.river} · ETA {a.eta}</p></div><Badge variant="secondary">{str(a.risk)}% risk</Badge></div>}}</CardContent></Card><Card className="shadow-sm lg:col-span-2"><CardHeader><CardTitle>Neighbour reports</CardTitle><CardDescription>Cross-checked with nearby signals</CardDescription></CardHeader><CardContent className="flex flex-col gap-3">{for r in reports {<div key={jid(r)} className="rounded-lg border bg-background p-3"><div className="flex items-center justify-between"><span className="font-medium">{r.area}</span><Badge variant="secondary">{r.status}</Badge></div><p className="mt-2 text-sm">{r.message}</p><p className="mt-2 text-xs text-muted-foreground">{r.reasoning}</p></div>}}</CardContent></Card></div>}
                <Card className="shadow-sm"><CardHeader><CardTitle>Demo sequence</CardTitle><CardDescription>8 areas · 2 rivers · 12 residents · weighted trust graph</CardDescription></CardHeader><CardContent className="flex flex-wrap items-center gap-3"><Badge variant="outline">1 · Raise rainfall</Badge><Badge variant="outline">2 · Relay warnings</Badge><Badge variant="outline">3 · Escalate silence</Badge><Badge variant="outline">4 · Verify report</Badge><span className="text-sm text-muted-foreground">{message}</span></CardContent></Card>
            </>}
        </main>
    </div>;
}

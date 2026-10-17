sv import from ..services.wimbi { Area, Person, Report, get_dashboard, set_rainfall, run_demo_flow }
import from .ui.card { Card, CardHeader, CardTitle, CardDescription, CardContent }
import from .ui.button { Button }
import from .ui.badge { Badge }
import from .ui.select { Select, SelectTrigger, SelectContent, SelectItem, SelectValue }

def:pub WimbiDashboard() -> JsxElement {
    has areas: list[Area] = [];
    has people: list[Person] = [];
    has reports: list[Report] = [];
    has rainfall: int = 18;
    has selected_role: str = "Responder Command";
    has is_loading: bool = True;
    has message: str = "";

    async can with entry {
        data = await get_dashboard();
        areas = data["areas"] as list[Area];
        people = data["people"] as list[Person];
        reports = data["reports"] as list[Report];
        rainfall = data["rainfall"] as int;
        is_loading = False;
    }
    async def change_rain(e: ChangeEvent) {
        rainfall = int(e.target.value);
        data = await set_rainfall(rainfall);
        areas = data["areas"] as list[Area];
        people = data["people"] as list[Person];
    }
    async def demo_action() {
        data = await run_demo_flow();
        areas = data["areas"] as list[Area];
        people = data["people"] as list[Person];
        reports = data["reports"] as list[Report];
        message = "Silent neighbour escalated; Kibera report confirmed and risk updated.";
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
                {selected_role == "Resident" and <Card className="shadow-sm"><CardHeader><Badge className="w-fit">Personal warning · Swahili</Badge><CardTitle>Flood watch for Kibera</CardTitle><CardDescription>Ground-floor resident · move essentials upstairs first</CardDescription></CardHeader><CardContent className="flex flex-col gap-4"><p className="rounded-lg bg-muted/60 p-4 text-sm">Tahadhari ya mafuriko Kibera. Move medicines, phone and documents upstairs. Avoid low crossings near the river.</p><p className="text-sm">Safe route: take the higher road toward the community hall. Never cross moving water.</p><Button onClick={lambda { message = "You are marked safe."; }}>Mark me safe</Button><Button variant="outline" onClick={lambda { message = "Report sent for verification."; }}>Report water here</Button></CardContent></Card>}
                {selected_role == "Community Leader" and <Card className="shadow-sm"><CardHeader><CardTitle>Your trusted circle</CardTitle><CardDescription>Check in with silent neighbours and vulnerable residents.</CardDescription></CardHeader><CardContent className="grid gap-3 sm:grid-cols-2">{for p in people {<div key={p.name} className="flex items-center justify-between rounded-lg border bg-background p-3"><div><p className="font-medium">{p.name}</p><p className="text-xs text-muted-foreground">{p.area}</p></div><Badge variant="secondary">{p.role}</Badge></div>}}</CardContent></Card>}
                {selected_role == "Accountability" and <Card className="shadow-sm"><CardHeader><CardTitle>Reach and response accountability</CardTitle><CardDescription>Measures from the same sample graph.</CardDescription></CardHeader><CardContent className="grid gap-4 sm:grid-cols-2"><div className="rounded-lg border bg-background p-4">Alert reach: {str(len(people) - waiting)} / {str(len(people))}</div><div className="rounded-lg border bg-background p-4">First acknowledgement: 4 min</div><div className="rounded-lg border bg-background p-4">Verified report: 7 min</div><div className="rounded-lg border bg-background p-4">Silence escalations: {str(1 if message else 0)}</div></CardContent></Card>}
                {selected_role == "Responder Command" and <div className="grid gap-4 lg:grid-cols-5"><Card className="shadow-sm lg:col-span-3"><CardHeader><CardTitle>Risk by neighbourhood</CardTitle><CardDescription>Downstream estimate · rainfall {str(rainfall)} mm/hr</CardDescription></CardHeader><CardContent className="flex flex-col gap-3">{for a in areas {<div key={a.name} className="flex items-center justify-between gap-3 rounded-lg border bg-background p-3"><div><p className="font-medium">{a.name}</p><p className="text-xs text-muted-foreground">{a.river} · ETA {a.eta}</p></div><Badge variant="secondary">{str(a.risk)}% risk</Badge></div>}}</CardContent></Card><Card className="shadow-sm lg:col-span-2"><CardHeader><CardTitle>Neighbour reports</CardTitle><CardDescription>Cross-checked with nearby signals</CardDescription></CardHeader><CardContent className="flex flex-col gap-3">{for r in reports {<div key={r.message} className="rounded-lg border bg-background p-3"><div className="flex items-center justify-between"><span className="font-medium">{r.area}</span><Badge variant="secondary">{r.status}</Badge></div><p className="mt-2 text-sm">{r.message}</p><p className="mt-2 text-xs text-muted-foreground">{r.reasoning}</p></div>}}</CardContent></Card></div>}
                <Card className="shadow-sm"><CardHeader><CardTitle>Demo sequence</CardTitle><CardDescription>8 areas · 2 rivers · 12 residents · weighted trust graph</CardDescription></CardHeader><CardContent className="flex flex-wrap items-center gap-3"><Badge variant="outline">1 · Raise rainfall</Badge><Badge variant="outline">2 · Relay warnings</Badge><Badge variant="outline">3 · Escalate silence</Badge><Badge variant="outline">4 · Verify report</Badge><span className="text-sm text-muted-foreground">{message}</span></CardContent></Card>
            </>}
        </main>
    </div>;
}

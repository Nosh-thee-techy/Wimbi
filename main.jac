import from services.wimbi { get_dashboard, set_rainfall, run_demo_flow, submit_resident_report }
import from .components.WimbiDashboard { WimbiDashboard }
import ".styles.global.css";

def:pub app() -> JsxElement {
    return <WimbiDashboard />;
}

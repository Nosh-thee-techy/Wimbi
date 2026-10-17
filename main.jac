import from services.wimbi { get_dashboard, set_rainfall, run_demo_flow, submit_resident_report, generate_tailored_warning, set_resident_identity, acknowledge_warning, mark_visit_handled, relay_warning, get_accountability_summary, get_resident_reports, suggest_resources_live, check_claude_key_configuration }
import from .components.WimbiDashboard { WimbiDashboard }
import ".styles.global.css";

def:pub app() -> JsxElement {
    return <WimbiDashboard />;
}

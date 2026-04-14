<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>TAB Skills Tracker — Airadigm</title>
<script src="config.js"></script>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:14px;background:#f5f5f0;color:#1a1a1a;min-height:100vh}
.page{display:none}.page.active{display:block}
/* LOGIN */
.login-bg{min-height:100vh;display:flex;align-items:center;justify-content:center;padding:1rem}
.login-box{background:#fff;border-radius:14px;border:0.5px solid #e0e0d8;padding:2rem;width:100%;max-width:380px}
.login-logo{font-size:22px;font-weight:600;margin-bottom:4px}
.login-logo span{color:#1D9E75}
.login-sub{font-size:13px;color:#888;margin-bottom:1.5rem}
.field{margin-bottom:1rem}
.field label{display:block;font-size:12px;color:#666;margin-bottom:5px;font-weight:500}
.field input,.field select{width:100%;padding:9px 12px;border:0.5px solid #ddd;border-radius:8px;font-size:14px;background:#fff;color:#1a1a1a;outline:none}
.field input:focus,.field select:focus{border-color:#1D9E75;box-shadow:0 0 0 3px rgba(29,158,117,0.1)}
.btn{padding:10px 20px;background:#1D9E75;color:#fff;border:none;border-radius:8px;font-size:14px;font-weight:500;cursor:pointer}
.btn:hover{background:#0F6E56}
.btn-full{width:100%}
.btn-outline{background:#fff;color:#1D9E75;border:1px solid #1D9E75}
.btn-outline:hover{background:#E1F5EE}
.btn-danger{background:#e74c3c}
.btn-danger:hover{background:#c0392b}
.err{font-size:12px;color:#c0392b;margin-top:8px;display:none;padding:8px 10px;background:#FCEBEB;border-radius:6px}
.login-hint{font-size:11px;color:#aaa;text-align:center;margin-top:1rem}
/* TOPBAR */
.topbar{display:flex;align-items:center;justify-content:space-between;padding:12px 20px;background:#fff;border-bottom:0.5px solid #e8e8e0;position:sticky;top:0;z-index:10}
.tb-left{display:flex;align-items:center;gap:10px}
.tb-logo{font-size:15px;font-weight:600}
.tb-logo span{color:#1D9E75}
.region-pill{font-size:11px;padding:3px 10px;border-radius:20px;background:#E1F5EE;color:#0F6E56;font-weight:500}
.tb-right{display:flex;align-items:center;gap:8px}
.tb-user{font-size:12px;color:#888}
.tb-logout{font-size:12px;color:#666;padding:5px 10px;border:0.5px solid #ddd;border-radius:7px;cursor:pointer;background:#fff}
.tb-logout:hover{background:#f5f5f0}
/* MAIN */
.main{padding:16px 20px;max-width:1100px;margin:0 auto}
/* METRICS */
.metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:10px;margin-bottom:14px}
.metric{background:#fff;border:0.5px solid #e8e8e0;border-radius:10px;padding:12px 14px}
.metric-label{font-size:11px;color:#888;margin-bottom:4px}
.metric-val{font-size:24px;font-weight:600}
/* ALERTS */
.alert-stalled{background:#FAEEDA;border:0.5px solid #EF9F27;border-radius:10px;padding:10px 14px;margin-bottom:14px}
.alert-title{font-size:12px;font-weight:600;color:#633806;margin-bottom:6px}
.alert-pills{display:flex;flex-wrap:wrap;gap:6px}
.alert-pill{font-size:11px;background:#fff;border:0.5px solid #EF9F27;border-radius:20px;padding:3px 10px;color:#854F0B}
/* SECTION */
.section-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:10px}
.section-title{font-size:13px;font-weight:600}
.view-tabs{display:flex;gap:4px}
.vtab{font-size:11px;padding:5px 11px;border-radius:7px;border:0.5px solid #ddd;cursor:pointer;color:#666;background:#fff}
.vtab.on{background:#1D9E75;color:#fff;border-color:#1D9E75;font-weight:500}
/* TECH GRID */
.tech-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:10px}
@media(max-width:700px){.tech-grid{grid-template-columns:1fr}.metrics{grid-template-columns:repeat(2,1fr)}}
.tcard{background:#fff;border:0.5px solid #e8e8e0;border-radius:12px;padding:12px;cursor:pointer;transition:border-color .15s}
.tcard:hover{border-color:#1D9E75}
.tcard-top{display:flex;align-items:center;gap:10px;margin-bottom:10px}
.avatar{width:36px;height:36px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:600;flex-shrink:0}
.tcard-name{font-size:13px;font-weight:600}
.tcard-sub{font-size:11px;color:#888;margin-top:2px}
.bars{display:flex;flex-direction:column;gap:5px}
.brow{display:flex;align-items:center;gap:6px}
.blabel{font-size:10px;color:#888;width:52px;flex-shrink:0}
.btrack{flex:1;height:5px;background:#f0f0eb;border-radius:3px;overflow:hidden}
.bfill{height:100%;border-radius:3px}
.bval{font-size:10px;font-weight:600;min-width:22px;text-align:right}
.flag{font-size:9px;padding:1px 4px;border-radius:3px;background:#FCEBEB;color:#A32D2D;font-weight:600;margin-left:2px}
.trend-up{color:#0F6E56;font-size:10px;font-weight:600}
.trend-dn{color:#c0392b;font-size:10px;font-weight:600}
.trend-eq{color:#aaa;font-size:10px}
/* DETAIL */
.back-btn{font-size:12px;color:#1D9E75;cursor:pointer;margin-bottom:12px;display:inline-flex;align-items:center;gap:4px}
.back-btn:hover{text-decoration:underline}
.detail-card{background:#fff;border:0.5px solid #e8e8e0;border-radius:12px;padding:14px;margin-bottom:12px}
.detail-header{display:flex;align-items:center;gap:12px;margin-bottom:14px}
.detail-avatar{width:48px;height:48px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:15px;font-weight:600}
.detail-name{font-size:16px;font-weight:600}
.detail-sub{font-size:12px;color:#888;margin-top:2px}
.hist-table{width:100%;border-collapse:collapse;font-size:12px}
.hist-table th{text-align:left;padding:7px 8px;color:#888;border-bottom:0.5px solid #eee;font-size:11px;font-weight:500}
.hist-table td{padding:7px 8px;border-bottom:0.5px solid #f0f0eb;vertical-align:middle}
.hist-table tr:last-child td{border-bottom:none}
.score-pill{font-size:10px;padding:2px 7px;border-radius:8px;font-weight:600}
.sg{background:#E1F5EE;color:#0F6E56}
.sa{background:#FAEEDA;color:#854F0B}
.sr{background:#FCEBEB;color:#A32D2D}
.sn{background:#f0f0eb;color:#888}
/* STALLED */
.stalled-box{background:#FCEBEB;border:0.5px solid #F09595;border-radius:10px;padding:10px 14px;margin-bottom:12px}
.stalled-title{font-size:12px;font-weight:600;color:#791F1F;margin-bottom:6px}
.skill-alert-row{display:flex;align-items:center;justify-content:space-between;padding:5px 0;border-bottom:0.5px solid #F7C1C1;font-size:12px;color:#1a1a1a}
.skill-alert-row:last-child{border-bottom:none}
/* COMMENTS */
.comment-entry{margin-bottom:10px}
.comment-date{font-size:10px;color:#aaa;margin-bottom:3px}
.comment-text{background:#f8f8f3;border-radius:7px;padding:8px 10px;font-size:12px;color:#555;font-style:italic}
.no-comment{font-size:12px;color:#bbb;font-style:italic}
/* TECH OWN VIEW */
.my-scores{background:#fff;border:0.5px solid #e8e8e0;border-radius:12px;padding:14px;margin-bottom:12px}
.my-bars{display:flex;flex-direction:column;gap:9px}
.my-brow{display:flex;align-items:center;gap:10px}
.my-label{font-size:12px;color:#888;width:130px;flex-shrink:0}
.my-track{flex:1;height:8px;background:#f0f0eb;border-radius:4px;overflow:hidden}
.my-fill{height:100%;border-radius:4px}
.my-val{font-size:12px;font-weight:600;min-width:40px;text-align:right}
/* COMPARE */
.compare-wrap{background:#fff;border:0.5px solid #e8e8e0;border-radius:12px;padding:14px}
/* LOADING */
.loading{text-align:center;padding:2rem;color:#888;font-size:13px}
/* NEBB */
.nebb-badge{font-size:10px;padding:2px 7px;border-radius:20px;font-weight:500}
.nebb-cp{background:#EEEDFE;color:#534AB7}
.nebb-ct{background:#E1F5EE;color:#0F6E56}
.nebb-tr{background:#f0f0eb;color:#666}
/* SUCCESS */
.success-box{background:#E1F5EE;border:0.5px solid #1D9E75;border-radius:10px;padding:12px 16px;margin-bottom:14px;font-size:13px;color:#0F6E56;font-weight:500}

/* ═══════════════════════════════════════
   QUESTIONNAIRE STYLES
═══════════════════════════════════════ */
.q-wrap{max-width:760px;margin:0 auto;padding:16px 20px}
.q-header{background:#fff;border:0.5px solid #e8e8e0;border-radius:12px;padding:16px 20px;margin-bottom:16px}
.q-title{font-size:18px;font-weight:600;margin-bottom:6px}
.q-sub{font-size:13px;color:#666;line-height:1.6}
.q-progress{background:#f0f0eb;border-radius:4px;height:6px;margin-top:12px;overflow:hidden}
.q-progress-fill{height:100%;background:#1D9E75;border-radius:4px;transition:width .3s}
.q-progress-label{font-size:11px;color:#888;margin-top:5px}
.q-section{background:#fff;border:0.5px solid #e8e8e0;border-radius:12px;padding:16px 20px;margin-bottom:14px}
.q-section-title{font-size:14px;font-weight:600;margin-bottom:4px;display:flex;align-items:center;gap:8px}
.q-section-sub{font-size:12px;color:#888;margin-bottom:14px;line-height:1.5}
.q-skill{margin-bottom:18px;padding-bottom:18px;border-bottom:0.5px solid #f0f0eb}
.q-skill:last-child{margin-bottom:0;padding-bottom:0;border-bottom:none}
.q-skill-name{font-size:13px;font-weight:500;margin-bottom:8px;line-height:1.5;color:#1a1a1a}
.q-skill-cat{font-size:11px;color:#888;margin-bottom:6px}
.rating-row{display:flex;gap:6px;flex-wrap:wrap}
.rating-btn{flex:1;min-width:50px;padding:8px 4px;border:1px solid #ddd;border-radius:8px;background:#fff;cursor:pointer;text-align:center;transition:all .15s;font-size:12px;color:#666}
.rating-btn:hover{border-color:#1D9E75;background:#E1F5EE;color:#0F6E56}
.rating-btn.selected-1{background:#FCEBEB;border-color:#E24B4A;color:#A32D2D;font-weight:600}
.rating-btn.selected-2{background:#FEF3E2;border-color:#EF9F27;color:#854F0B;font-weight:600}
.rating-btn.selected-3{background:#EBF3FE;border-color:#378ADD;color:#185FA5;font-weight:600}
.rating-btn.selected-4{background:#E1F5EE;border-color:#1D9E75;color:#0F6E56;font-weight:600}
.rating-btn.selected-5{background:#E1F5EE;border-color:#085041;color:#085041;font-weight:600}
.rating-label{font-size:10px;color:#aaa;margin-top:2px}
.q-legend{background:#f8f8f3;border-radius:8px;padding:10px 12px;margin-bottom:14px;font-size:11px;color:#666;line-height:1.8}
.q-comment{width:100%;padding:10px 12px;border:0.5px solid #ddd;border-radius:8px;font-size:13px;font-family:inherit;resize:vertical;min-height:80px;outline:none;color:#1a1a1a}
.q-comment:focus{border-color:#1D9E75}
.q-nav{display:flex;align-items:center;justify-content:space-between;margin-top:16px;gap:10px}
.q-blocked{background:#fff;border:0.5px solid #e8e8e0;border-radius:12px;padding:2rem;text-align:center;margin-top:1rem}
.q-blocked-icon{font-size:36px;margin-bottom:12px}
.q-blocked-title{font-size:16px;font-weight:600;margin-bottom:6px}
.q-blocked-sub{font-size:13px;color:#666}
</style>
</head>
<body>

<!-- ═══════ LOGIN ═══════ -->
<div id="pg-login" class="page active">
  <div class="login-bg">
    <div class="login-box">
      <div class="login-logo">Airadigm <span>Skills</span></div>
      <div class="login-sub">TAB Skills Self-Assessment Tracker</div>
      <div class="field">
        <label>Role</label>
        <select id="role-sel" onchange="toggleRoleFields()">
          <option value="pm">Project Manager</option>
          <option value="tech">Technician</option>
        </select>
      </div>
      <div id="pm-fields">
        <div class="field">
          <label>Region</label>
          <select id="region-sel">
            <option value="RM">Rocky Mountain</option>
            <option value="SW">Southwest</option>
            <option value="SE">Southeast</option>
            <option value="National">National</option>
            <option value="Survey">Survey</option>
          </select>
        </div>
        <div class="field">
          <label>Password</label>
          <input type="password" id="pm-pass" placeholder="Enter your password">
        </div>
      </div>
      <div id="tech-fields" style="display:none">
        <div class="field">
          <label>First name</label>
          <input type="text" id="tech-name" placeholder="e.g. Richard">
        </div>
        <div class="field">
          <label>Password</label>
          <input type="password" id="tech-pass" placeholder="Enter your password">
        </div>
      </div>
      <div class="err" id="login-err">Incorrect credentials. Please try again.</div>
      <button class="btn btn-full" style="margin-top:0.5rem" onclick="doLogin()">Sign in</button>
      <div class="login-hint">Contact your Project Manager if you need help with your password.</div>
    </div>
  </div>
</div>

<!-- ═══════ PM PAGE ═══════ -->
<div id="pg-pm" class="page">
  <div class="topbar">
    <div class="tb-left">
      <div class="tb-logo">Airadigm <span>Skills</span></div>
      <div class="region-pill" id="pm-region-pill"></div>
    </div>
    <div class="tb-right">
      <div class="tb-user" id="pm-user-label"></div>
      <div class="tb-logout" onclick="doLogout()">Sign out</div>
    </div>
  </div>
  <div class="main">
    <div id="pm-overview">
      <div class="metrics" id="pm-metrics"><div class="loading">Loading...</div></div>
      <div id="pm-alert-box"></div>
      <div class="section-head">
        <div class="section-title">Team</div>
        <div class="view-tabs">
          <div class="vtab on" id="tab-cards" onclick="setView('cards')">Cards</div>
          <div class="vtab" id="tab-compare" onclick="setView('compare')">Compare</div>
        </div>
      </div>
      <div id="view-cards"><div class="tech-grid" id="tech-grid"><div class="loading">Loading technicians...</div></div></div>
      <div id="view-compare" style="display:none">
        <div class="compare-wrap">
          <div class="section-title" style="margin-bottom:12px">Team skill averages</div>
          <canvas id="compare-chart" height="220"></canvas>
        </div>
      </div>
    </div>
    <div id="pm-detail" style="display:none">
      <div class="back-btn" onclick="backToOverview()">&#8592; Back to team</div>
      <div id="pm-detail-content"></div>
    </div>
  </div>
</div>

<!-- ═══════ TECH PAGE ═══════ -->
<div id="pg-tech" class="page">
  <div class="topbar">
    <div class="tb-left"><div class="tb-logo">Airadigm <span>Skills</span></div></div>
    <div class="tb-right">
      <div class="tb-user" id="tech-user-label"></div>
      <div class="tb-logout" onclick="doLogout()">Sign out</div>
    </div>
  </div>
  <div class="main">
    <div id="tech-home"><div class="loading">Loading your profile...</div></div>
  </div>
</div>

<!-- ═══════ QUESTIONNAIRE PAGE ═══════ -->
<div id="pg-questionnaire" class="page">
  <div class="topbar">
    <div class="tb-left"><div class="tb-logo">Airadigm <span>Skills</span></div></div>
    <div class="tb-right">
      <div class="tb-user" id="q-user-label"></div>
      <div class="tb-logout" onclick="backToTechHome()">&#8592; Back</div>
    </div>
  </div>
  <div class="q-wrap" id="q-content"></div>
</div>

<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<script>
// ─── STATE ───────────────────────────────────────────────────────────────────
let currentRole=null, currentRegion=null, currentTechId=null, currentTechName=null;
let regionTechs=[], compareChartInst=null;
let qAnswers={}, qComment='';

// ─── SKILL DEFINITIONS ───────────────────────────────────────────────────────
const SKILL_CATS=[
  {key:'safety_avg',label:'Safety / Core Values'},
  {key:'basic_avg',label:'Basic'},
  {key:'intermediate_avg',label:'Intermediate'},
  {key:'advanced_avg',label:'Advanced'},
  {key:'survey_avg',label:'TAB Survey'}
];

const QUESTIONNAIRE=[
  {section:'Safety + Core Values + Tools',color:'#1D9E75',emoji:'',key:'safety',skills:[
    {id:'s1',cat:'SAFETY',name:'PPE Usage: Demonstrate proper daily usage and replacement of damaged or missing PPE.'},
    {id:'s2',cat:'SAFETY',name:'Fall Protection: Explain and demonstrate ladder safety protocols and fall protection procedures.'},
    {id:'s3',cat:'SAFETY',name:'Electrical Safety & LOTO: Apply electrical safety protocols including lockout/tagout procedures.'},
    {id:'s4',cat:'SAFETY',name:'Tool Safety: Demonstrate proper tool safety and handling techniques including tool storage.'},
    {id:'s5',cat:'SAFETY',name:'Vehicle Incident Reporting: Understand jobsite safety documentation and incident reporting procedures.'},
    {id:'s6',cat:'CORE VALUES',name:'Integrity: Demonstrate integrity in daily work practices.'},
    {id:'s7',cat:'CORE VALUES',name:'Responsiveness: Respond promptly and appropriately to the needs of others.'},
    {id:'s8',cat:'CORE VALUES',name:'Teamwork: Collaborate effectively with others to achieve shared goals.'},
    {id:'s9',cat:'CORE VALUES',name:'Wellness: Take proactive steps to maintain well-being and support a healthy workplace.'},
    {id:'s10',cat:'CORE VALUES',name:'Always Improving: Look for ways to learn, grow, and improve performance.'},
    {id:'s11',cat:'CORE VALUES',name:'All In: Show dedication and give your best effort in every task.'},
    {id:'s12',cat:'CORE VALUES',name:'Accountability: Take ownership of actions and follow through on commitments.'},
    {id:'s13',cat:'TOOLS',name:'100% Tooled-Up: Keep the Tool Report on USABalancer up to date to maintain full inventory.'}
  ]},
  {section:'Basic Skills (0–3 months)',color:'#1D9E75',emoji:'',key:'basic',skills:[
    {id:'b1',cat:'TAB MATH',name:'Area & Volume Calculations: Calculate area and volume for HVAC applications.'},
    {id:'b2',cat:'TAB MATH',name:'Basic Algebra: Apply basic algebra principles for TAB calculations.'},
    {id:'b3',cat:'TAB MATH',name:'CFM and RPM Relationships: Understand and apply Fan Law 1.'},
    {id:'b4',cat:'TAB MATH',name:'Flow Rate Calculations: Calculate CFM using formulas (CFM = A x V) for rectangular and round ducts.'},
    {id:'b5',cat:'TAB MATH',name:'Percentage Calculations: Calculate percentages for balancing tolerances and system performance.'},
    {id:'b6',cat:'TAB MATH',name:'Square/Cube Calculations: Understand and apply Fan Laws 2 and 3.'},
    {id:'b7',cat:'TAB MATH',name:'Unit Conversions: Convert model numbers to BTU, tonnage, and CFM values.'},
    {id:'b8',cat:'TAB MATH',name:'Ratio & Proportion: Apply ratio and proportion calculations in TAB work.'},
    {id:'b9',cat:'INSTRUMENTS',name:'Capture Hood Operation: Operate capture hood with all settings, data storage, and recall functions.'},
    {id:'b10',cat:'INSTRUMENTS',name:'Airfoil Usage & Traverse: Use airfoil probes and traverse procedures.'},
    {id:'b11',cat:'INSTRUMENTS',name:'Static Pressure Measurements: Take and store Total Static Pressure and External Static Pressure readings.'},
    {id:'b12',cat:'INSTRUMENTS',name:'Velocity Grid Operation: Operate velocity grid equipment for airflow measurements.'},
    {id:'b13',cat:'INSTRUMENTS',name:'Rotating Vane Anemometer: Operate RVA with all settings, data storage, recall functions, and CFM display.'},
    {id:'b14',cat:'INSTRUMENTS',name:'Temperature & Humidity Meters: Use thermometers and hygrometers with all settings.'},
    {id:'b15',cat:'INSTRUMENTS',name:'Tachometer RPM Measurements: Use tachometer for accurate RPM measurements.'},
    {id:'b16',cat:'INSTRUMENTS',name:'Strobe Scope RPM: Use strobe scope for RPM measurements and estimate RPMs by sheave sizes.'},
    {id:'b17',cat:'INSTRUMENTS',name:'Volt/Amp Meter: Operate voltage and amperage measurement equipment.'},
    {id:'b18',cat:'INSTRUMENTS',name:'Temperature Data Logging: Operate temperature data logging equipment for continuous monitoring.'},
    {id:'b19',cat:'INSTRUMENTS',name:'Instrument Management: Maintain instrument list, care procedures, and calibration schedules.'},
    {id:'b20',cat:'INSTRUMENTS',name:'Measurement Accuracy: Explain measurement uncertainty and accuracy concepts in instrumentation.'},
    {id:'b21',cat:'AIR BASICS',name:'Key Grille Balancing: Balance air distribution using key grilles and adjustment techniques.'},
    {id:'b22',cat:'AIR BASICS',name:'Trial and Error Balancing: Apply systematic trial and error methods for achieving balanced airflow.'},
    {id:'b23',cat:'UNIT TESTING',name:'Unit Data: Gather and record comprehensive unit performance data.'},
    {id:'b24',cat:'UNIT TESTING',name:'RPMs Actual and Predictive Measurement: Measure current RPM and predict performance at different speeds.'},
    {id:'b25',cat:'UNIT TESTING',name:'Volts, Amps Measurement: Accurately measure electrical parameters on HVAC equipment.'},
    {id:'b26',cat:'UNIT TESTING',name:'Static Pressures Measurements: Measure and record static pressures on various types of equipment.'},
    {id:'b27',cat:'UNIT TESTING',name:'Outside Airflows: Determine and verify outside air quantities and percentages.'},
    {id:'b28',cat:'UNIT TESTING',name:'Duct Traverses: Perform systematic duct traverses for accurate airflow measurements.'},
    {id:'b29',cat:'UNIT TESTING',name:'Motor Starters: Inspect and test motor starters and control circuits.'},
    {id:'b30',cat:'UNIT TESTING',name:'Fan Testing: Conduct comprehensive fan performance testing and analysis.'},
    {id:'b31',cat:'UNIT TESTING',name:'Fan Law Review: Apply fan laws for system performance predictions.'},
    {id:'b32',cat:'UNIT TESTING',name:'Coil Face Velocity: Measure and calculate air velocity across heating and cooling coils.'},
    {id:'b33',cat:'UNIT TESTING',name:'Air Apps on RTUs and EF: Complete comprehensive air testing on RTUs and exhaust fans.'},
    {id:'b34',cat:'UNIT TESTING',name:'Air Apps on AHUs: Complete comprehensive air testing and balancing on AHUs.'},
    {id:'b35',cat:'AIR BALANCING',name:"Ak's: Calculate and apply Ak factors for grille and diffuser performance."},
    {id:'b36',cat:'AIR BALANCING',name:'Ratio Balancing: Apply proportional balancing techniques on multi systems.'},
    {id:'b37',cat:'AIR BALANCING',name:'Trial and Error Balancing: Apply trial and error methods for simple systems.'},
    {id:'b38',cat:'AIR BALANCING',name:'KES Survey Projects: Complete HVAC survey projects for KES.'}
  ]},
  {section:'Intermediate Skills (4–12 months)',color:'#378ADD',emoji:'',key:'intermediate',skills:[
    {id:'i1',cat:'AIR BASICS',name:'Economizers - Setting Unit Total Flow: Set and verify economizer operation and obtain total unit airflow.'},
    {id:'i2',cat:'AIR BASICS',name:'Building Static Pressure: Measure and adjust building pressurization systems.'},
    {id:'i3',cat:'AIR BASICS',name:'Balance Sidewall Grilles: Balance air distribution through sidewall grilles and registers.'},
    {id:'i4',cat:'TROUBLESHOOTING',name:'Troubleshooting Low Airflow: Systematically troubleshoot and resolve low airflow conditions.'},
    {id:'i5',cat:'UNIT TESTING',name:'Air Handling Unit Component Identification: Identify and explain function of AHU components.'},
    {id:'i6',cat:'JOB MANAGEMENT',name:'Job Readiness Report: Regularly complete the readiness report at the beginning of the job.'},
    {id:'i7',cat:'JOB MANAGEMENT',name:'Balance Basic Job Solo: Successfully manage basic balancing jobs independently.'},
    {id:'i8',cat:'TAB REPORTS',name:'Writing Remarks: Write clear, accurate remarks and observations in technical reports.'},
    {id:'i9',cat:'TAB REPORTS',name:'USABalancer Proficiency: Produce high-quality TAB reports meeting professional standards.'},
    {id:'i10',cat:'UNIT TESTING',name:'Variable Frequency Drive: Operate multiple VFD models for system optimization.'},
    {id:'i11',cat:'UNIT TESTING',name:'Static Pressure Profile to include Coil and Filter Drops: Create comprehensive pressure profiles.'},
    {id:'i12',cat:'UNIT TESTING',name:'DSS / Cabinet Unit Heater Balancing: Perform a complete air app on DSS and Cabinet Heaters.'},
    {id:'i13',cat:'JOB MANAGEMENT',name:'Blueprint Reading Skills / Mechanical Schedules Familiarity: Read and interpret construction drawings.'},
    {id:'i14',cat:'JOB MANAGEMENT',name:'Mechanical Submittals Familiarity: Review and interpret mechanical equipment submittals.'},
    {id:'i15',cat:'JOB MANAGEMENT',name:'Can Project Manage Their Jobs: Demonstrate ability to manage multiple aspects of projects.'},
    {id:'i16',cat:'JOB MANAGEMENT',name:'Deadline Management: Successfully meet project deadlines and schedule requirements.'},
    {id:'i17',cat:'JOB MANAGEMENT',name:'Shows Flexibility with Project Demands: Adapt to changing project demands and requirements.'},
    {id:'i18',cat:'JOB MANAGEMENT',name:'Customer Service, Punch List Protocol: Execute professional customer service with daily updates.'},
    {id:'i19',cat:'UNIT TESTING',name:'Energy Recovery Units: Test and balance energy recovery ventilation systems.'},
    {id:'i20',cat:'UNIT TESTING',name:'Motor Sheave Calculations: Calculate proper sheave sizes for desired fan performance.'},
    {id:'i21',cat:'UNIT TESTING',name:'Establishing Final SP Setpoint: Determine and set appropriate system static pressure setpoints.'},
    {id:'i22',cat:'UNIT TESTING',name:'Total Unit CFM - VAV Systems: Posture unit to finalize data and obtain total airflow on VAV systems.'},
    {id:'i23',cat:'TAB REPORTS',name:'Report Review Analysis: Analyze and review technical reports for accuracy and completeness.'},
    {id:'i24',cat:'TERMINAL UNITS',name:'VAVs: Test and adjust VAV terminal units for proper operation.'},
    {id:'i25',cat:'TERMINAL UNITS',name:'Parallel Fan Powered Boxes: Test and balance parallel fan powered terminal units.'},
    {id:'i26',cat:'TROUBLESHOOTING',name:'Troubleshooting VAVs: Diagnose and resolve VAV system operational issues.'},
    {id:'i27',cat:'TERMINAL UNITS',name:'Series Fan Powered Boxes: Test and balance series fan powered terminal units.'},
    {id:'i28',cat:'TERMINAL UNITS',name:'Thermal Diffuser: Test and adjust thermal diffuser systems.'},
    {id:'i29',cat:'UNIT TESTING',name:'Airflow Monitor Calibration: Calibrate airflow measurement stations.'},
    {id:'i30',cat:'UNIT TESTING',name:'Fan Performance Curve Analysis: Analyze and interpret fan performance curves.'},
    {id:'i31',cat:'TROUBLESHOOTING',name:'Fans and System Effect: Analyze fan performance issues and system effect factors.'},
    {id:'i32',cat:'TROUBLESHOOTING',name:'Submittals: Can review and explain when they are needed.'},
    {id:'i33',cat:'TROUBLESHOOTING',name:'Occupant Comfort Issues: Diagnose and resolve indoor air quality and comfort complaints.'},
    {id:'i34',cat:'JOB MANAGEMENT',name:'Specifications: Read, interpret, and apply project specifications.'},
    {id:'i35',cat:'JOB MANAGEMENT',name:'Customer Service Skills: Demonstrate professional customer interaction and problem resolution.'},
    {id:'i36',cat:'SPECIALTY TESTING',name:'Air Changes per Hour: Measure and perform Room ACH.'},
    {id:'i37',cat:'SPECIALTY TESTING',name:'Fume Hoods: Test laboratory and commercial fume hoods.'},
    {id:'i38',cat:'HYDRONICS',name:'Balance Valves: Test, adjust, and balance hydronic system control valves.'},
    {id:'i39',cat:'HYDRONICS',name:'Understands Hydronic Precautions: Explain and implement safety precautions for hydronic systems.'},
    {id:'i40',cat:'TERMINAL UNITS',name:'HVAC Controls - Part 1: Understand basic principles of HVAC control systems.'},
    {id:'i41',cat:'TERMINAL UNITS',name:'Electronic Controls - Resource Access: Access and utilize electronic control system resources.'},
    {id:'i42',cat:'TERMINAL UNITS',name:'Pneumatic Controls - Resource Access: Access and utilize pneumatic control system resources.'},
    {id:'i43',cat:'TERMINAL UNITS',name:'HVAC Controls - Part 2: Understand advanced principles of HVAC control systems.'},
    {id:'i44',cat:'SPECIALTY TESTING',name:'Setting O/A Temperature Method: Establish proper outside air via the air temperature method.'}
  ]},
  {section:'Advanced Skills (13+ months)',color:'#EF9F27',emoji:'',key:'advanced',skills:[
    {id:'a1',cat:'HYDRONICS',name:'Explain Hydronic Components: Identify and explain function of hydronic system components.'},
    {id:'a2',cat:'HYDRONICS',name:'Balance Chillers: Balance chillers via evaporator and condenser drop.'},
    {id:'a3',cat:'HYDRONICS',name:'Balance Cooling Towers: Balance cooling tower, understand expected temperatures for design.'},
    {id:'a4',cat:'HYDRONICS',name:'Balance Boilers: Balance boiler systems.'},
    {id:'a5',cat:'HYDRONICS',name:'Balance Condenser Water: Balance condenser water systems.'},
    {id:'a6',cat:'HYDRONICS',name:'Pump Balancing: Balance Pumps and optimize hydronic pump operations.'},
    {id:'a7',cat:'HYDRONICS',name:'Solving Humidity Issues: Solve humidity control problems in HVAC systems.'},
    {id:'a8',cat:'HYDRONICS',name:'Understanding NEBB Procedural Standards: Apply NEBB Standards for balancing and reporting.'},
    {id:'a9',cat:'HYDRONICS',name:'Stairwell Pressures: Test and adjust stairwell pressurization systems.'},
    {id:'a10',cat:'HYDRONICS',name:'Primary / Secondary Piping Balancing: Balance primary and secondary piping systems.'},
    {id:'a11',cat:'HYDRONICS',name:'Coil Balancing: Balance water flow through heating and cooling coils utilizing submittal pressure drops.'},
    {id:'a12',cat:'HYDRONICS',name:'Pump Operating Setpoint: Can establish pump operating setpoint.'},
    {id:'a13',cat:'HYDRONICS',name:'CV Balancing: Balance coils using CVs.'},
    {id:'a14',cat:'HYDRONICS',name:'Heat Exchangers: Balance Heat Exchangers.'},
    {id:'a15',cat:'HYDRONICS',name:'Ultrasonic Flow Meter: Use ultrasonic meter for determining water flow.'},
    {id:'a16',cat:'TROUBLESHOOTING',name:'Troubleshooting Hydronics: Diagnose and resolve hydronic system operational problems.'},
    {id:'a17',cat:'COMMISSIONING',name:'Sequence of Operations Familiarization: Understand and read the equipment sequence of operations.'},
    {id:'a18',cat:'COMMISSIONING',name:'Commissioning Basics: Understand fundamental commissioning processes and procedures.'},
    {id:'a19',cat:'SPECIALTY TESTING',name:'Chilled Beams: Balance chilled beam systems.'},
    {id:'a20',cat:'SPECIALTY TESTING',name:'Duct Air Leakage Testing: Perform ductwork air leakage testing.'},
    {id:'a21',cat:'SPECIALTY TESTING',name:'Sound Testing: Conduct sound measurements and calculating the NC.'},
    {id:'a22',cat:'SPECIALTY TESTING',name:'Vibration Testing: Perform equipment vibration analysis and determine pass/fail criteria.'},
    {id:'a23',cat:'SPECIALTY TESTING',name:'Off-Season Testing: Conduct testing during non-peak seasons.'},
    {id:'a24',cat:'SPECIALTY TESTING',name:'Stairwell Pressurization Testing: Conduct comprehensive stairwell pressure testing.'},
    {id:'a25',cat:'SPECIALTY TESTING',name:'Temperature Differential Analysis / BTU Calculations: Perform advanced thermal analysis.'},
    {id:'a26',cat:'SPECIALTY TESTING',name:'Coil Water Carry Over: Diagnose and resolve coil water carryover problems.'},
    {id:'a27',cat:'TROUBLESHOOTING',name:'Makeup Water / PRVs: Troubleshoot water makeup and PRV systems.'},
    {id:'a28',cat:'TROUBLESHOOTING',name:'Piping Systems Comprehension: Understand design and operation, pipe sizing, expansion tank sizing.'}
  ]},
  {section:'TAB Survey Skills',color:'#7F77DD',emoji:'',key:'survey',skills:[
    {id:'sv1',cat:'UNIT TESTING',name:'Ability to accurately measure Wire Size.'},
    {id:'sv2',cat:'UNIT TESTING',name:'Ability to calculate Carrier unit tonnage.'},
    {id:'sv3',cat:'UNIT TESTING',name:'Ability to accurately measure Gas and Condenser Pipe Size.'},
    {id:'sv4',cat:'UNIT TESTING',name:'Ability to identify Hot Gas Reheat Coils.'},
    {id:'sv5',cat:'SURVEY PROJECTS',name:'Can complete Surveys independently.'},
    {id:'sv6',cat:'JOB MANAGEMENT',name:'Job Approach: Work a job in an order that has it completed by the estimated job hours.'},
    {id:'sv7',cat:'SURVEY REPORTS',name:'USABalancer Proficiency: Produce high-quality Survey reports meeting professional standards.'},
    {id:'sv8',cat:'SURVEY REPORTS',name:'Report Review Analysis: Analyze and review technical reports for accuracy and completeness.'},
    {id:'sv9',cat:'JOB MANAGEMENT',name:'Customer Service: Punch List Protocol: Execute professional customer service with detailed punch list.'}
  ]}
];

const RATING_LABELS=['','Beginner','Developing','Experienced','Proficient','Exceptional'];

// ─── HELPERS ─────────────────────────────────────────────────────────────────
function show(id){document.querySelectorAll('.page').forEach(p=>p.classList.remove('active'));document.getElementById(id).classList.add('active')}
function scoreColor(v){if(v===null)return'#aaa';if(v>=4)return'#1D9E75';if(v>=3)return'#378ADD';if(v>=2)return'#EF9F27';return'#E24B4A'}
function scorePillClass(v){if(v===null)return'sn';if(v>=3)return'sg';if(v>=2)return'sa';return'sr'}
function initials(name){return name.split(' ').map(w=>w[0]).join('').slice(0,2).toUpperCase()}
function avatarColors(name){
  const p=[{bg:'#E1F5EE',tc:'#0F6E56'},{bg:'#E6F1FB',tc:'#185FA5'},{bg:'#EEEDFE',tc:'#534AB7'},{bg:'#FAEEDA',tc:'#854F0B'},{bg:'#FBEAF0',tc:'#993556'},{bg:'#EAF3DE',tc:'#3B6D11'}];
  return p[name.charCodeAt(0)%p.length];
}
function nebbBadge(s){
  if(!s)return'';
  if(s.includes('CP'))return`<span class="nebb-badge nebb-cp">NEBB CP</span>`;
  if(s.includes('CT'))return`<span class="nebb-badge nebb-ct">NEBB CT</span>`;
  return`<span class="nebb-badge nebb-tr">In Training</span>`;
}
function sectionAvg(sectionKey){
  const sec=QUESTIONNAIRE.find(s=>s.key===sectionKey);
  if(!sec)return null;
  const vals=sec.skills.map(sk=>qAnswers[sk.id]).filter(v=>v!==undefined&&v!==null);
  return vals.length?vals.reduce((a,b)=>a+b,0)/vals.length:null;
}

// ─── SUPABASE ─────────────────────────────────────────────────────────────────
async function sbFetch(path,options={}){
  const url=SUPABASE_URL+'/rest/v1/'+path;
  const headers={'apikey':SUPABASE_KEY,'Authorization':'Bearer '+SUPABASE_KEY,'Content-Type':'application/json',...(options.headers||{})};
  const res=await fetch(url,{...options,headers});
  if(!res.ok){const e=await res.text();throw new Error(e);}
  const text=await res.text();
  return text?JSON.parse(text):[];
}

// ─── AUTH ─────────────────────────────────────────────────────────────────────
function toggleRoleFields(){
  const r=document.getElementById('role-sel').value;
  document.getElementById('pm-fields').style.display=r==='pm'?'block':'none';
  document.getElementById('tech-fields').style.display=r==='tech'?'block':'none';
  document.getElementById('login-err').style.display='none';
}

async function doLogin(){
  const role=document.getElementById('role-sel').value;
  const errEl=document.getElementById('login-err');
  errEl.style.display='none';
  try{
    if(role==='pm'){
      const region=document.getElementById('region-sel').value;
      const pass=document.getElementById('pm-pass').value.trim();
      const rows=await sbFetch(`users?role=eq.pm&region=eq.${region}&password=eq.${encodeURIComponent(pass)}&select=id`);
      if(!rows.length){errEl.style.display='block';return;}
      currentRole='pm';currentRegion=region;
      document.getElementById('pm-region-pill').textContent=REGION_LABELS[region];
      document.getElementById('pm-user-label').textContent='Project Manager';
      await loadPMDashboard(region);
      show('pg-pm');
    }else{
      const name=document.getElementById('tech-name').value.trim();
      const pass=document.getElementById('tech-pass').value.trim();
      const rows=await sbFetch(`users?role=eq.technician&password=eq.${encodeURIComponent(pass)}&select=id,tech_id`);
      let found=null;
      for(const r of rows){
        if(r.tech_id){
          const techs=await sbFetch(`technicians?id=eq.${r.tech_id}&select=id,name`);
          if(techs.length&&techs[0].name.toLowerCase().startsWith(name.toLowerCase())){found={techId:r.tech_id,techName:techs[0].name};break;}
        }
      }
      if(!found){errEl.style.display='block';return;}
      currentRole='tech';currentTechId=found.techId;currentTechName=found.techName;
      document.getElementById('tech-user-label').textContent=currentTechName;
      document.getElementById('q-user-label').textContent=currentTechName;
      await loadTechHome(currentTechId);
      show('pg-tech');
    }
  }catch(e){errEl.textContent='Connection error. Please try again.';errEl.style.display='block';console.error(e);}
}

function doLogout(){
  currentRole=null;currentRegion=null;currentTechId=null;currentTechName=null;qAnswers={};qComment='';
  document.getElementById('pm-pass').value='';
  document.getElementById('tech-pass').value='';
  document.getElementById('tech-name').value='';
  document.getElementById('login-err').style.display='none';
  show('pg-login');
}

// ─── PM DASHBOARD ─────────────────────────────────────────────────────────────
async function loadPMDashboard(region){
  document.getElementById('pm-metrics').innerHTML='<div class="loading">Loading...</div>';
  document.getElementById('tech-grid').innerHTML='<div class="loading">Loading technicians...</div>';
  const techs=await sbFetch(`technicians?region=eq.${region}&select=id,name,nebb_status,lead_tech`);
  regionTechs=techs;
  const all=await Promise.all(techs.map(t=>sbFetch(`assessments?technician_id=eq.${t.id}&select=*&order=date.asc`)));
  techs.forEach((t,i)=>{t.assessments=all[i];});
  renderMetrics(techs);renderAlerts(techs);renderTechGrid(techs);
}

function renderMetrics(techs){
  const total=techs.reduce((s,t)=>s+t.assessments.length,0);
  const avgs=techs.filter(t=>t.assessments.length).map(t=>{
    const last=t.assessments[t.assessments.length-1];
    const vals=SKILL_CATS.map(c=>last[c.key]).filter(v=>v!==null);
    return vals.length?vals.reduce((a,b)=>a+b,0)/vals.length:0;
  });
  const avg=avgs.length?(avgs.reduce((a,b)=>a+b,0)/avgs.length).toFixed(1):'—';
  const alerts=countStalled(techs);
  document.getElementById('pm-metrics').innerHTML=`
    <div class="metric"><div class="metric-label">Technicians</div><div class="metric-val">${techs.length}</div></div>
    <div class="metric"><div class="metric-label">Team avg score</div><div class="metric-val">${avg}</div></div>
    <div class="metric"><div class="metric-label">Total assessments</div><div class="metric-val">${total}</div></div>
    <div class="metric"><div class="metric-label">Stalled alerts</div><div class="metric-val" style="color:#c0392b">${alerts}</div></div>`;
}

function countStalled(techs){
  let n=0;
  techs.forEach(t=>{
    if(t.assessments.length>=2){
      const last=t.assessments[t.assessments.length-1],prev=t.assessments[t.assessments.length-2];
      SKILL_CATS.forEach(c=>{if(last[c.key]!==null&&prev[c.key]!==null&&last[c.key]<=2&&last[c.key]<=prev[c.key])n++;});
    }
  });
  return n;
}

function renderAlerts(techs){
  const issues=[];
  techs.forEach(t=>{
    if(t.assessments.length>=2){
      const last=t.assessments[t.assessments.length-1],prev=t.assessments[t.assessments.length-2];
      SKILL_CATS.forEach(c=>{if(last[c.key]!==null&&prev[c.key]!==null&&last[c.key]<=2&&last[c.key]<=prev[c.key])issues.push(`${t.name.split(' ')[0]} — ${c.label}`);});
    }
  });
  const box=document.getElementById('pm-alert-box');
  if(!issues.length){box.innerHTML='';return;}
  box.innerHTML=`<div class="alert-stalled"><div class="alert-title">Stalled skills — score ≤ 2, no improvement</div><div class="alert-pills">${issues.map(i=>`<span class="alert-pill">${i}</span>`).join('')}</div></div>`;
}

function renderTechGrid(techs){
  if(!techs.length){document.getElementById('tech-grid').innerHTML='<div class="loading">No technicians found for this region.</div>';return;}
  document.getElementById('tech-grid').innerHTML=techs.map((t,idx)=>{
    const last=t.assessments.length?t.assessments[t.assessments.length-1]:null;
    const prev=t.assessments.length>1?t.assessments[t.assessments.length-2]:null;
    const ac=avatarColors(t.name);
    const bars=SKILL_CATS.map(c=>{
      if(!last||last[c.key]===null)return'';
      const v=last[c.key],pct=Math.round((v/5)*100),col=scoreColor(v);
      const stalled=prev&&prev[c.key]!==null&&v<=2&&v<=prev[c.key];
      const tr=prev&&prev[c.key]!==null?(v>prev[c.key]?'<span class="trend-up">+</span>':v<prev[c.key]?'<span class="trend-dn">-</span>':'<span class="trend-eq">=</span>'):'';
      const lbl=c.label.length>9?c.label.slice(0,9)+'…':c.label;
      return`<div class="brow"><span class="blabel">${lbl}</span><div class="btrack"><div class="bfill" style="width:${pct}%;background:${col}"></div></div><span class="bval" style="color:${col}">${v.toFixed(1)}</span>${tr}${stalled?'<span class="flag">!</span>':''}</div>`;
    }).join('');
    return`<div class="tcard" onclick="openTech(${idx})">
      <div class="tcard-top"><div class="avatar" style="background:${ac.bg};color:${ac.tc}">${initials(t.name)}</div>
      <div><div class="tcard-name">${t.name}</div><div class="tcard-sub">${nebbBadge(t.nebb_status)}${t.lead_tech?' · '+t.lead_tech.split(' ')[0]:''}</div></div></div>
      <div class="bars">${bars||'<div style="font-size:11px;color:#aaa">No assessments yet</div>'}</div></div>`;
  }).join('');
}

function openTech(idx){
  const t=regionTechs[idx];
  document.getElementById('pm-overview').style.display='none';
  document.getElementById('pm-detail').style.display='block';
  renderDetailView(t,document.getElementById('pm-detail-content'));
}
function backToOverview(){document.getElementById('pm-overview').style.display='block';document.getElementById('pm-detail').style.display='none';}

function renderDetailView(t,container){
  const ac=avatarColors(t.name);
  const assessments=t.assessments||[];
  const last=assessments.length?assessments[assessments.length-1]:null;
  const prev=assessments.length>1?assessments[assessments.length-2]:null;
  const stalled=[];
  if(last&&prev)SKILL_CATS.forEach(c=>{if(last[c.key]!==null&&prev[c.key]!==null&&last[c.key]<=2&&last[c.key]<=prev[c.key])stalled.push({label:c.label,val:last[c.key]});});
  const visCats=SKILL_CATS.filter(c=>assessments.some(a=>a[c.key]!==null));
  const histRows=[...assessments].reverse().map((a,ri,arr)=>{
    const prevA=arr[ri+1];
    const cells=visCats.map(c=>{
      const v=a[c.key];if(v===null)return'<td>—</td>';
      const pv=prevA?prevA[c.key]:null;
      const tr=pv!==null?(v>pv?`<span class="trend-up"> +${(v-pv).toFixed(1)}</span>`:v<pv?`<span class="trend-dn"> ${(v-pv).toFixed(1)}</span>`:`<span class="trend-eq"> =</span>`):'';
      return`<td><span class="score-pill ${scorePillClass(v)}">${v.toFixed(1)}</span>${tr}</td>`;
    }).join('');
    const ds=a.date?new Date(a.date).toLocaleDateString('en-US',{month:'short',year:'numeric'}):'—';
    return`<tr><td style="color:#888">${ds}</td>${cells}</tr>`;
  }).join('');
  const comments=[...assessments].reverse().map(a=>{
    const ds=a.date?new Date(a.date).toLocaleDateString('en-US',{month:'short',year:'numeric'}):'—';
    return`<div class="comment-entry"><div class="comment-date">${ds}</div>${a.comment?`<div class="comment-text">"${a.comment}"</div>`:'<div class="no-comment">No comment submitted.</div>'}</div>`;
  }).join('');
  container.innerHTML=`
    <div class="detail-card">
      <div class="detail-header">
        <div class="detail-avatar" style="background:${ac.bg};color:${ac.tc}">${initials(t.name)}</div>
        <div><div class="detail-name">${t.name}</div><div class="detail-sub">${t.nebb_status||'In Training'}${t.lead_tech?' · Lead: '+t.lead_tech:''}</div></div>
      </div>
      ${assessments.length?`<div class="section-title" style="font-size:12px;margin-bottom:8px">Assessment history</div>
      <div style="overflow-x:auto"><table class="hist-table">
        <thead><tr><th>Date</th>${visCats.map(c=>`<th>${c.label}</th>`).join('')}</tr></thead>
        <tbody>${histRows}</tbody></table></div>`:'<div class="no-comment">No assessments recorded yet.</div>'}
    </div>
    ${stalled.length?`<div class="stalled-box"><div class="stalled-title">Skills needing attention — stalled at or below 2</div>${stalled.map(s=>`<div class="skill-alert-row"><span>${s.label}</span><span class="score-pill sr">${s.val.toFixed(1)}</span></div>`).join('')}</div>`:''}
    <div class="detail-card"><div class="section-title" style="font-size:12px;margin-bottom:10px">Technician comments</div>${comments||'<div class="no-comment">No comments yet.</div>'}</div>`;
}

function setView(v){
  document.getElementById('tab-cards').classList.toggle('on',v==='cards');
  document.getElementById('tab-compare').classList.toggle('on',v==='compare');
  document.getElementById('view-cards').style.display=v==='cards'?'block':'none';
  document.getElementById('view-compare').style.display=v==='compare'?'block':'none';
  if(v==='compare')renderCompareChart(regionTechs);
}

function renderCompareChart(techs){
  if(compareChartInst){compareChartInst.destroy();compareChartInst=null;}
  const labels=techs.map(t=>t.name.split(' ')[0]);
  const colors=['#1D9E75','#378ADD','#7F77DD','#EF9F27','#D4537E'];
  const datasets=SKILL_CATS.map((c,i)=>({
    label:c.label,
    data:techs.map(t=>{if(!t.assessments.length)return null;const v=t.assessments[t.assessments.length-1][c.key];return v!==null?parseFloat(v.toFixed(1)):null;}),
    backgroundColor:colors[i]+'33',borderColor:colors[i],borderWidth:1.5,spanGaps:true
  }));
  compareChartInst=new Chart(document.getElementById('compare-chart'),{
    type:'bar',data:{labels,datasets},
    options:{responsive:true,plugins:{legend:{labels:{font:{size:11},boxWidth:10}}},scales:{y:{min:0,max:5,ticks:{stepSize:1,font:{size:10}}},x:{ticks:{font:{size:10}}}}}
  });
}

// ─── TECH HOME ────────────────────────────────────────────────────────────────
async function loadTechHome(techId){
  const container=document.getElementById('tech-home');
  container.innerHTML='<div class="loading">Loading your profile...</div>';
  const [techArr,assessments]=await Promise.all([
    sbFetch(`technicians?id=eq.${techId}&select=*`),
    sbFetch(`assessments?technician_id=eq.${techId}&select=*&order=date.asc`)
  ]);
  const t=techArr[0];t.assessments=assessments;
  const ac=avatarColors(t.name);
  const last=assessments.length?assessments[assessments.length-1]:null;
  const prev=assessments.length>1?assessments[assessments.length-2]:null;

  // check if already submitted this month
  const now=new Date();
  const alreadyThisMonth=last&&new Date(last.date).getMonth()===now.getMonth()&&new Date(last.date).getFullYear()===now.getFullYear();

  const myBars=SKILL_CATS.map(c=>{
    if(!last||last[c.key]===null)return'';
    const v=last[c.key],pct=Math.round((v/5)*100),col=scoreColor(v);
    return`<div class="my-brow"><span class="my-label">${c.label}</span><div class="my-track"><div class="my-fill" style="width:${pct}%;background:${col}"></div></div><span class="my-val" style="color:${col}">${v.toFixed(1)} / 5</span></div>`;
  }).join('');

  const stalled=[];
  if(last&&prev)SKILL_CATS.forEach(c=>{if(last[c.key]!==null&&prev[c.key]!==null&&last[c.key]<=2&&last[c.key]<=prev[c.key])stalled.push({label:c.label,val:last[c.key]});});

  const visCats=SKILL_CATS.filter(c=>assessments.some(a=>a[c.key]!==null));
  const histRows=[...assessments].reverse().map((a,ri,arr)=>{
    const prevA=arr[ri+1];
    const cells=visCats.map(c=>{
      const v=a[c.key];if(v===null)return'<td>—</td>';
      const pv=prevA?prevA[c.key]:null;
      const tr=pv!==null?(v>pv?`<span class="trend-up"> +${(v-pv).toFixed(1)}</span>`:v<pv?`<span class="trend-dn"> ${(v-pv).toFixed(1)}</span>`:`<span class="trend-eq"> =</span>`):'';
      return`<td><span class="score-pill ${scorePillClass(v)}">${v.toFixed(1)}</span>${tr}</td>`;
    }).join('');
    const ds=a.date?new Date(a.date).toLocaleDateString('en-US',{month:'short',year:'numeric'}):'—';
    return`<tr><td style="color:#888">${ds}</td>${cells}</tr>`;
  }).join('');

  const comments=[...assessments].reverse().map(a=>{
    const ds=a.date?new Date(a.date).toLocaleDateString('en-US',{month:'short',year:'numeric'}):'—';
    return`<div class="comment-entry"><div class="comment-date">${ds}</div>${a.comment?`<div class="comment-text">"${a.comment}"</div>`:'<div class="no-comment">No comment submitted.</div>'}</div>`;
  }).join('');

  const lastDate=last?new Date(last.date).toLocaleDateString('en-US',{month:'long',year:'numeric'}):'—';

  const assessBtn=alreadyThisMonth
    ?`<div style="background:#f8f8f3;border:0.5px solid #ddd;border-radius:10px;padding:12px 16px;font-size:13px;color:#888;text-align:center">Assessment already submitted for ${lastDate}. Next submission available next month.</div>`
    :`<button class="btn" onclick="startQuestionnaire()" style="width:100%;padding:12px;font-size:14px">Take this month's assessment</button>`;

  container.innerHTML=`
    <div class="my-scores">
      <div style="display:flex;align-items:center;gap:12px;margin-bottom:14px">
        <div class="detail-avatar" style="background:${ac.bg};color:${ac.tc}">${initials(t.name)}</div>
        <div><div class="detail-name">${t.name}</div><div class="detail-sub">${t.nebb_status||'In Training'}${t.lead_tech?' · Lead: '+t.lead_tech:''} · ${t.region}</div></div>
      </div>
      <div style="font-size:11px;color:#888;margin-bottom:10px">Latest scores — ${lastDate}</div>
      <div class="my-bars">${myBars||'<div class="no-comment">No scores yet — complete your first assessment below.</div>'}</div>
    </div>
    <div style="margin-bottom:14px">${assessBtn}</div>
    ${stalled.length?`<div class="stalled-box"><div class="stalled-title">Skills needing your attention</div>${stalled.map(s=>`<div class="skill-alert-row"><span>${s.label}</span><span class="score-pill sr">${s.val.toFixed(1)}</span></div>`).join('')}</div>`:''}
    ${assessments.length?`<div class="detail-card"><div class="section-title" style="font-size:12px;margin-bottom:8px">My assessment history</div><div style="overflow-x:auto"><table class="hist-table"><thead><tr><th>Date</th>${visCats.map(c=>`<th>${c.label}</th>`).join('')}</tr></thead><tbody>${histRows}</tbody></table></div></div>`:''}
    <div class="detail-card"><div class="section-title" style="font-size:12px;margin-bottom:10px">My comments</div>${comments||'<div class="no-comment">No comments yet.</div>'}</div>`;
}

// ─── QUESTIONNAIRE ────────────────────────────────────────────────────────────
function startQuestionnaire(){
  qAnswers={};qComment='';
  renderQuestionnaire();
  show('pg-questionnaire');
  window.scrollTo(0,0);
}

function backToTechHome(){show('pg-tech');}

function setRating(skillId,val){
  qAnswers[skillId]=val;
  const btns=document.querySelectorAll(`.rating-btn[data-skill="${skillId}"]`);
  btns.forEach(b=>{
    b.className='rating-btn';
    if(parseInt(b.dataset.val)===val)b.classList.add('selected-'+val);
  });
  updateProgress();
}

function updateProgress(){
  const total=QUESTIONNAIRE.reduce((s,sec)=>s+sec.skills.length,0);
  const done=Object.keys(qAnswers).length;
  const pct=Math.round((done/total)*100);
  const fill=document.getElementById('q-progress-fill');
  const lbl=document.getElementById('q-progress-label');
  if(fill)fill.style.width=pct+'%';
  if(lbl)lbl.textContent=`${done} of ${total} skills rated (${pct}%)`;
}

function renderQuestionnaire(){
  const container=document.getElementById('q-content');
  const total=QUESTIONNAIRE.reduce((s,sec)=>s+sec.skills.length,0);
  const legend=`<div class="q-legend"><strong>Rating scale:</strong><br>1 = Beginner — Not seen / No experience<br>2 = Developing — Done it a few times, still needs guidance<br>3 = Experienced — Can do it with minimal guidance<br>4 = Proficient — Confident performing independently<br>5 = Exceptional — Full mastery, can teach others</div>`;

  const sections=QUESTIONNAIRE.map(sec=>{
    const skills=sec.skills.map(sk=>{
      const btns=[1,2,3,4,5].map(v=>`<button class="rating-btn ${qAnswers[sk.id]===v?'selected-'+v:''}" data-skill="${sk.id}" data-val="${v}" onclick="setRating('${sk.id}',${v})"><div>${v}</div><div class="rating-label">${RATING_LABELS[v]}</div></button>`).join('');
      return`<div class="q-skill"><div class="q-skill-cat">${sk.cat}</div><div class="q-skill-name">${sk.name}</div><div class="rating-row">${btns}</div></div>`;
    }).join('');
    return`<div class="q-section">
      <div class="q-section-title" style="color:${sec.color}">${sec.section}</div>
      <div class="q-section-sub">Rate each skill from 1 (Beginner) to 5 (Exceptional).</div>
      ${legend}${skills}
    </div>`;
  }).join('');

  container.innerHTML=`
    <div class="q-header">
      <div class="q-title">TAB Skills Self-Assessment</div>
      <div class="q-sub">Rate every skill honestly. Your answers help customize your training and track your progress over time.</div>
      <div class="q-progress"><div class="q-progress-fill" id="q-progress-fill" style="width:0%"></div></div>
      <div class="q-progress-label" id="q-progress-label">0 of ${total} skills rated (0%)</div>
    </div>
    ${sections}
    <div class="q-section">
      <div class="q-section-title">Comments (optional)</div>
      <div class="q-section-sub">Any challenges, suggestions, or things you want your Project Manager to know?</div>
      <textarea class="q-comment" id="q-comment-field" placeholder="Share any thoughts about this assessment period..."></textarea>
    </div>
    <div class="q-nav">
      <button class="btn btn-outline" onclick="backToTechHome()">Cancel</button>
      <button class="btn" onclick="submitAssessment()">Submit assessment</button>
    </div>`;
}

async function submitAssessment(){
  const total=QUESTIONNAIRE.reduce((s,sec)=>s+sec.skills.length,0);
  const done=Object.keys(qAnswers).length;
  if(done<total){
    const missing=total-done;
    if(!confirm(`You have ${missing} skill(s) not yet rated. Submit anyway?`))return;
  }
  const comment=document.getElementById('q-comment-field').value.trim();
  const today=new Date().toISOString().split('T')[0];
  const payload={
    technician_id:currentTechId,
    date:today,
    safety_avg:sectionAvg('safety'),
    basic_avg:sectionAvg('basic'),
    intermediate_avg:sectionAvg('intermediate'),
    advanced_avg:sectionAvg('advanced'),
    survey_avg:sectionAvg('survey'),
    comment:comment||null,
    raw_scores:qAnswers
  };
  try{
    await sbFetch('assessments',{method:'POST',headers:{'Prefer':'return=minimal'},body:JSON.stringify(payload)});
    qAnswers={};qComment='';
    await loadTechHome(currentTechId);
    show('pg-tech');
    window.scrollTo(0,0);
    document.getElementById('tech-home').insertAdjacentHTML('afterbegin','<div class="success-box">Assessment submitted successfully! Your scores have been updated.</div>');
    setTimeout(()=>{const s=document.querySelector('.success-box');if(s)s.remove();},4000);
  }catch(e){alert('Error submitting. Please try again.\n'+e.message);}
}
</script>
</body>
</html>

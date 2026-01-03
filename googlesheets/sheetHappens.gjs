"use strict";

const MIN_TIME_UNIT = 1;
const MAX_TIME_UNIT = 240;

const MODEL_TUNING = {
  BASELINE: "Conservative",
  LOWERQUARTILE: "Low-Key Flex",
  MEDIAN: "Reliable Prediction",
  UPPERQUARTILE: "Baller Bracket",
  MAX: "Boss Level"
}
const TIME_UNIT = {
  DAY: 0.35,
  WEEK: 0.25,
  MONTH: 1,
  QUARTER: 3,
  YEAR: 12
}

function today() {
  const today = new Date();
  var now = new Intl.DateTimeFormat('en-US').format(today);
  return now;
}

function assertValidModel(value) {
  if (!Object.values(MODEL_TUNING).includes(value)) {
    throw new Error(`Invalid Model: ${value}`);
  }
}

function assertValidMonthInRange(month) {
  if (!(typeof month === 'number' || month >= 0 || month <= MAX_TIME_UNIT )) {
    throw new Error(`month not valid or out of bounds: ${month}`);
  }
}

function assertValidTime(value) {
  if (!Object.values(TIME_UNIT).includes(value)) {
    throw new Error(`Invalid Time: ${value}`);
  }
}

const longTime = (t) => {
  let lt = "inf";
    switch (t) {
      case TIME_UNIT.DAY:
        lt = 'day';
        break;
      case TIME_UNIT.WEEK:
        lt = 'week';
        break;
      case TIME_UNIT.MONTH:
        lt = 'month';
        break;
      case TIME_UNIT.QUARTER:
        lt = 'quarter';
        break;
      case TIME_UNIT.YEAR:
        lt = 'year';
        break;
      default:
    }
    return lt;
}

//  return formatted date given TIME_UNIT enum with n, n being between 1 and MAX_TIME_UNIT;
//    \  /  \  /
//     \/    \/
//
const timeFunc = (t,n=MIN_TIME_UNIT) => {
    let lt = ""
    let sToday = `"${today()}"`;
    let fxYear=`year(${sToday})`;
    const fxFirstOfMonth = (month) => { 
      assertValidMonthInRange(month);
      return `DATE( ${fxYear},1,${month})`; 
    }

    switch (t) {
      //   today()
      //  1/01/2026 + 0.35 * 1
      case TIME_UNIT.DAY:
        //   "1/3/2026"
        //   lt = '=text(day(today()),"dddd")';
        //   txt=`=text(day(DATE( year(today()),1,${month}),"dddd")`
        lt =`=text(WEEKDAY(${sToday}, 1),"dddd")`;
        break;
      case TIME_UNIT.WEEK:
        //  week of, begins sunday
        //lt = '=weeknum(today())';
        lt =`=${fxFirstOfMonth(n)}-(WEEKDAY(${fxFirstOfMonth(n)})  - 1)`
        break;
      case TIME_UNIT.MONTH:
        // =text(C5,"mmm")
        lt = `=text(${fxFirstOfMonth(n)},"mmm")`;

        break;
      case TIME_UNIT.QUARTER:
        //
        lt = `=concat("Q",mod(${fxFirstOfMonth(n)},4))'`;
        break;
      case TIME_UNIT.YEAR:
        //
        //lt = '=year(today())';
        lt = `=text(${sToday}, "yy")`;
        break;
      default:
    }
    return lt;
}

//  
//
const timeFuncaasdadss = (t,month) => {
    let lt = "";
    let fxYear="year(today())";

    const fxFirstOfMonth = (month) => { 
      assertValidMonthInRange(month);
      return `DATE( ${fxYear},1,${month})`; 
    };

    let fx=`DATE( year(),1,1)`;

    switch (t) {
      //   today()
      //  1/01/2026 + 0.35 * 1
      case TIME_UNIT.DAY:
        //   "1/3/2026"
        //   lt = '=text(day(today()),"dddd")';
        //   txt=`=text(day(DATE( year(today()),1,${month}),"dddd")`
        lt ='=text(day(today()),"dddd")'

        break;
      case TIME_UNIT.WEEK:
        //  week of, begins sunday
        lt = '=weeknum(today())';
        break;
      case TIME_UNIT.MONTH:
        // =text(C5,"mmm")
        lt = '=text(C5,"mmm")';
        lt = '=text(month(today()),"mmmm")';
        break;
      case TIME_UNIT.QUARTER:
        //
        lt = '=concat("Q",mod(month(today()),4))';
        break;
      case TIME_UNIT.YEAR:
        //
        lt = '=year(today())';
        break;
      default:
    }
    return lt;
}

const longModel = (m) => {
  let lm = "";
    switch (m) {
      case MODEL_TUNING.BASELINE:
        lm = "baseline";
        break;
      case MODEL_TUNING.LOWERQUARTILE:
        lm = "lowerquartile";
        break;
      case MODEL_TUNING.MEDIAN:
        lm = "median";
        break;

      case MODEL_TUNING.UPPERQUARTILE:
        lm = "upperquartile";
        break;

      case MODEL_TUNING.MAX:
        lm = "max";
        break;
      default:
    }
    return lm;
}

//  takes timeUnits, modelTuning, data
//    returns resultSet
//
//  TODO rename this
//
function runCalc(t, m, d) {
  assertValidTime(t);
  assertValidModel(m);
  
  d['CAC'] = d['cost_per_sale'];
  d['ARPA'] = d["revenue_per_client"];
 
  let funcFromStr = {
    'lifetime_value': (timeUnit,modelTuning) => {
      return d['revenue_per_client'] * d['avg_client_lifespan'];
    },
    'gross_profit_per_client': (timeUnit,modelTuning) => {
      return d['revenue_per_client'] - d['overhead'];
    },
    'net_profit_per_client': (timeUnit,modelTuning) => {
      return d['revenue_per_client'] - d['profit_margin'];
    }
  };


  //TODO
  //  
  console.log(`(month == month) [${longTime(t)}]`);
    let sToday = `"${today()}"`;
    console.log("sToday:"+sToday);
    let fxYear=`year(${sToday})`;
    console.log("fxYear:"+fxYear);
    const fxFirstOfMonth = (month) => { 
      assertValidMonthInRange(month);
      return `DATE( ${fxYear},1,${month})`; 
    };

  console.log("fxFirstOfMonth(1):"+fxFirstOfMonth(1));

  let rs = {};
  rs[longTime(t)] = timeFunc(t);


  rs[longTime(TIME_UNIT.DAY)] = timeFunc(TIME_UNIT.DAY);


  console.log(JSON.stringify(rs));
  //console.log(rs['month']);
  //let rs = "{":"=MONTH(TODAY())"};
  //JSON.parse(JSON.stringify(d));

  //  field renaming can happen here
  //
  for (let [field,value] of Object.entries(rs)) {

  }

  for (let i = d['time_begin']; i <= d['time_end']; i += 1) {
    console.log("ts:"+i);

    for (let [field,fn] of Object.entries(funcFromStr)) {
      let f = field + "_" + longTime(t) + "_" + longModel(m);
      rs[f] = fn(t,m);
      console.log("runCalc field: "+f+" t step:"+i);
    }
  }

//  console.log(rs)

  return rs;
}

//  data constructor from user's form input
//
function funroll(nicheEnum, formLink) {

//Client Perspective ROI	
//Leads	50
//Lead sell price to client	$55.00
//Client Close %	5.00%
//Could work in Contact %	60.00%
//Leads contacted	30.00
//these numbers are typical cases	
//closed as paying clients (% of contacted)	20%
//client close %	12.00%
//client closed	10.00
//showed genuine interest	50.00%
//booked a consult	40.00%
//Closed Deal Value Example	$1,000.00
//Gross Income	$10,000.00
//leads cost	$2,750.00
//Net return	$7,250.00
//Cost per Sale	$458.33
//gross ROI	$2.64
//Profit Margin (for Net Rev in ROAS)	25.00%
//Net profit for leads	$2,500.00
//Net ROAS	$0.91

// Legend:
//Revenue: Total sales volume, tracking market presence.
//Gross Profit: How efficiently you produce and price your core product.
//Net Profit: How much money is truly left after all costs, indicating overall financial health. 
//ARPA average revenue per account
//LTV (Lifetime Value)	Total revenue expected from a client over their lifetime	LTV = ARPA × AvgClientRetentionMonths
//CAC (Customer Acquisition Cost)	Average cost to acquire a new client	CAC = TotalMarketingSpend / NewClientsAcquired
//LTV:CAC ratio	Measures profitability per acquisition	LTV:CAC = LTV ÷ CAC

  var data = {
    "form_row_link": formLink,
    "time": TIME_UNIT.MONTH,
    "model": MODEL_TUNING.BASELINE,
    "graph": {"fields": [] },
    "new_clients": "10",
    "ad_spend_min": "20000",  //time base month
    "ad_spend_max": "100000", //time base month
    "avg_client_lifespan": "12",  //time base month
    "client_retention_rate": 0.8,
    "revenue_per_client": 300,
    "cost_per_sale": 100, //CAC (Customer Acquisition Cost)	= TotalMarketingSpend / NewClientsAcquired
  };
  data["time_begin"] = 0;
  data["time_end"] = data["time"] * MAX_TIME_UNIT;


  switch (nicheEnum) {
    case "emergency":
      data["ad_spend_min"] = "20000";
      data["ad_spend_max"] = "100000";
      data['service'] = ['Emergency Triage & Critical Care','After-Hours Diagnostics','Trauma & Surgery Intervention'];
      data['service_hours'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data['service_price'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data['service_cost'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      
      break;
    case "surgical":
      data['service'] = ['Orthopedic Surgery Package','Oncology Treatment Protocol','Specialty Diagnostics'];
      data['service_hours'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data["ad_spend_min"] = "10000";
      data["ad_spend_max"] = "50000";
      break;
    case "franchise_vet":
      data['service'] = ['Annual Wellness Plan','Pet Vaccination Package','Preventative Dental Program'];
      data['service_hours'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data["ad_spend_min"] = "8000";
      data["ad_spend_max"] = "40000";
      break;
    case "training":
      data['service'] = ['Board & Train Intensive Program','Obedience Group Classes','One-on-One Behavioral Coaching']
      data['service_hours'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data["ad_spend_min"] = "5000";
      data["ad_spend_max"] = "25000";
      break;
    case "boarding":
      data['service'] = ['Overnight Boarding Package','Daycare Enrollment','Playtime & Socialization Add-on']
      data['service_hours'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data["ad_spend_min"] = "4000";
      data["ad_spend_max"] = "20000";
      break;
    case "mobile_vet":
      data['service'] = ['Mobile Wellness Exam','At-Home Vaccination Service','In-Home Lab & Diagnostics']
      data['service_hours'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data["ad_spend_min"] = "3000";
      data["ad_spend_max"] = "15000";
      break;
    case "luxury_sitting":
      data['service'] = ['Premium Overnight Sitting','Daily Check-Ins & Playtime','Special Needs / Med Admin']
      data['service_hours'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data["ad_spend_min"] = "3000";
      data["ad_spend_max"] = "12000";
      break;
    case "luxury_grooming":
      data['service'] = ['Full Groom & Styling','Show Groom Prep','Specialty Breed Maintenance']
      data['service_hours'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data["ad_spend_min"] = "2000";
      data["ad_spend_max"] = "10000";
      break;
    case "walking":
      data['service'] = ['30-min Daily Walk Plan','60-min Premium Walk Plan','Pack Walk / Socialization Class']
      data['service_hours'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data["ad_spend_min"] = "1500";
      data["ad_spend_max"] = "8000";
      break;
    case "transportation":
      data['service'] = ['Airport Pet Transfer','Vet / Grooming Pickup & Drop-Off','Long-Distance Relocation']
      data['service_hours'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data["ad_spend_min"] = "1500";
      data["ad_spend_max"] = "7000";
      break;
    case "cremation":
      data['service'] = ['Individual Cremation','Communal Cremation','Memorial Keepsake Package']
      data['service_hours'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data["ad_spend_min"] = "1000";
      data["ad_spend_max"] = "6000";
      break;
    case "delivery":
      data['service'] = ['Monthly Raw Food Delivery','Prescription Diet Subscription','Supplemental Treat Packs']
      data['service_hours'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data["ad_spend_min"] = "1000";
      data["ad_spend_max"] = "5000";
      break;
    case "photo":
      data['service'] = ['Studio Portrait Session','Outdoor Adventure Shoot','Event Coverage (Birthday / Adoption Day)']
      data['service_hours'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data["ad_spend_min"] = "500";
      data["ad_spend_max"] = "3000";
      break;
    case "exotic":
      data['service'] = ['Reptile Health Exam','Bird Beak / Feather Care','Small Mammal Wellness Plan']
      data['service_hours'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data["ad_spend_min"] = "300";
      data["ad_spend_max"] = "2000";
      break;
    case "waste":
      data['service'] = ['Weekly Pooper Scooper Plan','Bi-Weekly Clean-Up','One-Time Yard Clean Event']
      data['service_hours'] = [{'min': 2, 'median': 3, 'max': 4}, {'min':0, "median":0, "max":0}, {'min':0,'median':0,'max':0}];
      data["ad_spend_min"] = "300";
      data["ad_spend_max"] = "1500";
      break;
    default:
  }
  return data;
}

function makeGraph(d) {
  console.log("makeGraph() begin")
}

function populateSheet() {
  console.log("populateSheet() begin")
  var path = "macros/s/AKfycbz_cxx8goUoutIDaUUSGt7wm_sfv8O6h1GFNzsGynjBEMUZKyimnXVQ2wTL5ccWFVY/exec";
  var query = "?action=read"
  var url = "https://script.google.com/"+path+query; // Replace with your URL
  var html;

  console.log("await fetchXHR "+url)
  html = " fetching data <p>";
  let sheet_url = 'https://docs.google.com/spreadsheets/d/1YYVl5EGOy2WOk74l3DmtaugP5RgW_c6UQDtJkTE4itE/edit?resourcekey=&gid=25088639#gid=25088639';
  const ss = SpreadsheetApp.openByUrl(sheet_url);
  const form_sheet = ss.getSheetByName('Forminator');

  //console.log(`spreadsheet name ${form_sheet.getFormUrl()}`)

  //ui.showModalDialog(HtmlService.createHtmlOutput(html), 'Executing sequence');
  let response = UrlFetchApp.fetch(url);
  //  data = response.getContentText();
  var data = JSON.parse(response.getContentText());

  var n = data.length + 1;//data.slice(-1);
  let el = data.pop();
  var niche = el["Niche|select-1"];
  var active_clients = el["Active Clients|number-1"];

  let link = `${sheet_url}&${n}:${n}`;
  let dataTable = funroll(niche, `=HYPERLINK("${link}", "row ${n}")`);
  
  assertValidTime(dataTable.time)
  assertValidModel(dataTable.model)

  //  TODO: this could & should be tied to the UI
  //

  dataTable = runCalc(dataTable.time, dataTable.model, dataTable);
  console.log(dataTable)

  const data_sheet = ss.getSheetByName('DataTable');
  const graph_sheet = ss.getSheetByName('Graph');

  let c = 1;
  let r = 1;
  for (let [key, value] of Object.entries(dataTable)) {
    data_sheet.getRange(c,1).setValue(key);  
    data_sheet.getRange(c,2).setValue(value);
    c=c+1;
  }

  let graph = makeGraph(dataTable);

  c = 1;
  r = 1;

return;


  for (let row of Object.entries(graph)) {
    c = 1;
    for (let column of Object.entries(row)) {
      graph_sheet.getRange(r, c).setValue(column);
      c=c+1;
    }
    r=r+1;
  }

}

function doGet(e) {
  if (e.parameter.action === 'read') {
    return readData();
  }

  if (e.parameter.action === 'update') {
    return populateSheet();
  }

  if (e.parameter.action === 'populate') {
    return populateSheet();
  }

  return ContentService
    .createTextOutput('Invalid action')
    .setMimeType(ContentService.MimeType.TEXT);
}

/**
 * WRITE DATA (Web App POST)
 * Body JSON: { "id": 1, "status": "Active" }
 */
function doPost(e) {
  const data = JSON.parse(e.postData.contents);
  return writeData(data);
}

/**
 * Read all sheet data as JSON
 */
function readData() {

const ss = SpreadsheetApp.openByUrl(
    'https://docs.google.com/spreadsheets/d/1YYVl5EGOy2WOk74l3DmtaugP5RgW_c6UQDtJkTE4itE/edit?resourcekey=&gid=25088639#gid=25088639'
);
const sheet = ss.getSheetByName('Forminator');

  const values = sheet.getDataRange().getValues();
  const headers = values.shift();

  const rows = values.map(row => {
    return headers.reduce((obj, key, i) => {
      obj[key] = row[i];
      return obj;
    }, {});
  });

  return ContentService
    .createTextOutput(JSON.stringify(rows))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * Update row by ID
 */
function writeData(sheet, data) {
  console.log("writeData ")
  const values = sheet.getDataRange().getValues();
  console.log(values)
  const headers = values[0];

  console.log(data)

  for (let row = 1; row < values.length; row++) {
    for (let col = 1; col< values[row].length; col++) {
      sheet.getRange(row, col).setValue("suckit");
    }
  }
  return ContentService.createTextOutput('Updated');

  //return ContentService.createTextOutput('ID not found');
}

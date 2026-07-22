const XLSX = require('xlsx');
const crypto = require('crypto');
const excel4node = require('excel4node');
const fs = require('fs');

// ===== 加载 dt_unit 数据 =====
const sql = fs.readFileSync('scripts/sql/dt_tieline.sql', 'utf8');
const dtUnits = [];
const regex = /INSERT INTO `dt_unit` VALUES \(([^;]+)\)/g;
let m;
while ((m = regex.exec(sql)) !== null) {
    const rows = m[1].split('),(');
    for (let r of rows) {
        r = r.replace(/^\(|\)$/g, '').trim();
        if (!r) continue;
        const parts = r.match(/'[^']*'|[^,]+/g);
        if (parts && parts.length >= 6) {
            dtUnits.push({
                cim_id: parts[1].replace(/'/g, '').trim(),
                unit_name: parts[2].replace(/'/g, '').trim(),
                plant_name: parts[4].replace(/'/g, '').trim(),
                code: parts[5].replace(/'/g, '').trim()
            });
        }
    }
}
console.log('dt_unit 加载:', dtUnits.length, '条');

// ===== 加载三个 xlsx =====
const sd = XLSX.utils.sheet_to_json(XLSX.readFile('源文件.xlsx').Sheets['DahNonMktUnitPlan'], {header: 1});
const md = XLSX.utils.sheet_to_json(XLSX.readFile('已匹配.xlsx').Sheets['结果'], {header: 1});
const ud = XLSX.utils.sheet_to_json(XLSX.readFile('未匹配.xlsx').Sheets['结果'], {header: 1});

// ===== 匹配函数：对源文件一行执行 3→2→1 逻辑 =====
function matchSourceRow(row) {
    const facName = String(row[1] || '').trim();
    const unitName = String(row[3] || '').trim();
    const unitCode = String(row[4] || '').trim();

    // 第3级：方式② — 精确匹配（PLANT_NAME + UNIT_NAME）
    const m3 = dtUnits.filter(d =>
        d.plant_name === facName && d.unit_name === unitName);
    if (m3.length > 0) return { matched: true, level: 3, cim_id: m3[0].cim_id };

    // 第2级：方式① — 仅 UNIT_NAME 匹配
    // 条件：该电厂+设备名的精确组合不存在于 dt_unit
    const exactExists = dtUnits.some(d =>
        d.plant_name === facName && d.unit_name === unitName);
    if (!exactExists) {
        const m2 = dtUnits.filter(d => d.unit_name === unitName);
        if (m2.length > 0) return { matched: true, level: 2, cim_id: m2[0].cim_id };
    }

    // 第1级：CODE 匹配
    if (unitCode && unitCode !== 'undefined' && unitCode !== 'NUll') {
        const m1 = dtUnits.filter(d => d.code === unitCode);
        if (m1.length > 0) return { matched: true, level: 1, cim_id: m1[0].cim_id };
    }

    return { matched: false, level: 0, cim_id: null };
}

// ===== 构建已匹配的曲线索引（用于获取额外数据） =====
function hashJson(s) {
    try { const a = JSON.parse(s); const h = crypto.createHash('md5'); a.forEach(v => h.update(String(Number(v).toFixed(4)))); return h.digest('hex'); } catch(e) { return null; }
}
function hashCols(row, sc) {
    const h = crypto.createHash('md5');
    for (let i = sc; i < sc+96 && i < row.length; i++) h.update(String(Number(row[i]||0).toFixed(4)));
    return h.digest('hex');
}

const matchedMap = new Map();
for (let i = 1; i < md.length; i++) {
    const key = hashJson(md[i][4]);
    if (key) matchedMap.set(key, { device_id: md[i][1], device_name: md[i][2], plant_id: md[i][7], plant_name: md[i][8] });
}

// ===== 输出 =====
const wb = new excel4node.Workbook();
const ws = wb.addWorksheet('合并结果');
const hS = wb.createStyle({font:{bold:true,color:'FFFFFF',size:10},fill:{type:'pattern',patternType:'solid',fgColor:'4472C4'}});
const yS = wb.createStyle({fill:{type:'pattern',patternType:'solid',fgColor:'FFFF00'},font:{size:10}});
const oS = wb.createStyle({fill:{type:'pattern',patternType:'solid',fgColor:'FFC000'},font:{size:10}});
const rS = wb.createStyle({fill:{type:'pattern',patternType:'solid',fgColor:'FF6666'},font:{size:10}});

const header = [...sd[0], '匹配状态', '匹配层级', '新DEVICE_ID', '新DEVICE_NAME', '新PLANT_ID', '新PLANT_NAME'];
header.forEach((h, ci) => ws.cell(1, ci+1).string(h||'').style(hS));

let mc=0, uc=0;
for (let i = 1; i < sd.length; i++) {
    const row = sd[i];
    const ri = i + 1;
    const result = matchSourceRow(row);
    // 判断是否全零曲线
    let allZero = true;
    for (let c = 5; c < 5 + 96 && c < row.length; c++) {
        if (Number(row[c] || 0) !== 0) { allZero = false; break; }
    }

    const isMatched = result.matched;
    const style = !isMatched ? rS : (allZero ? oS : yS);
    if (isMatched) mc++; else uc++;

    // 写源数据
    for (let ci = 0; ci < row.length; ci++) {
        const val = row[ci];
        const cell = ws.cell(ri, ci+1);
        if (val===null||val===undefined) cell.string('').style(style);
        else if (typeof val==='number') cell.number(val).style(style);
        else cell.string(String(val)).style(style);
    }

    // 附加列
    const sc = row.length + 1;
    ws.cell(ri, sc).string(isMatched ? '已匹配' : '未匹配').style(style);
    ws.cell(ri, sc+1).string(isMatched ? '第' + result.level + '级' : '-').style(style);

    if (isMatched) {
        const dStyle = allZero ? oS : yS;
        // 从已匹配文件获取额外数据
        const hash = hashCols(row, 5);
        const extra = matchedMap.get(hash);
        if (extra) {
            ws.cell(ri, sc+2).string(String(extra.device_id||'')).style(dStyle);
            ws.cell(ri, sc+3).string(String(extra.device_name||'')).style(dStyle);
            ws.cell(ri, sc+4).string(String(extra.plant_id||'')).style(dStyle);
            ws.cell(ri, sc+5).string(String(extra.plant_name||'')).style(dStyle);
        } else {
            for (let c=2; c<=5; c++) ws.cell(ri, sc+c).string('').style(dStyle);
        }
    } else {
        for (let c=2; c<=5; c++) ws.cell(ri, sc+c).string('').style(rS);
    }
}

wb.write('非市场机组_颜色标注.xlsx');
console.log('✅ 总记录:', sd.length-1, ' 已匹配:', mc, ' 未匹配:', uc);
console.log('匹配逻辑已按 3→2→1 执行');

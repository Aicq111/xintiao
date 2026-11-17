// ============================================================
// 薪跳 App · 核心计薪引擎（JS 镜像 + 测试）
// 与 Dart 版 lib/core/engine.dart 同一算法；本文件用于本地验证数学正确性。
// 运行：node engine_check.mjs
// ============================================================

const H = 60; // 1 小时 = 60 分钟
const DAY = 1440; // 1 天 = 1440 分钟

// ---------- 班次 ----------
const SHIFTS = {
  bai:  { name:'白班',   startMin:8*H,  endMin:17*H, breaks:[{s:12*H,e:13*H}] },      // 计薪 8h
  ye:   { name:'夜班',   startMin:20*H, endMin:30*H, breaks:[{s:24*H,e:25*H}] },      // 20:00→次日6:00，宵夜 0:00-1:00 → 计薪 9h
  zao:  { name:'早班',   startMin:0,    endMin:8*H,  breaks:[] },
  zhong:{ name:'中班',   startMin:8*H,  endMin:16*H, breaks:[] },
  wan:  { name:'晚班',   startMin:16*H, endMin:24*H, breaks:[] },
  full: { name:'全天候', startMin:0,    endMin:24*H, breaks:[] },
};

function billableSeconds(shift){
  let min = shift.endMin - shift.startMin;
  for(const b of shift.breaks) min -= (b.e - b.s);
  return min * 60;
}

// ---------- 日期工具 ----------
function dayIndex(y, m, d){ return Math.floor(Date.UTC(y, m-1, d) / 86400000); }
function weekday(y, m, d){ return (dayIndex(y, m, d) + 3) % 7; }        // 0=周一
function daysInMonth(y, m){ return new Date(Date.UTC(y, m, 0)).getUTCDate(); }
function weekIndex(y, m, d){
  const first = dayIndex(y, m, 1);
  const firstMon = first - weekday(y, m, 1);                            // 当月第一天所在周的周一
  return Math.floor((dayIndex(y, m, d) - firstMon) / 7);
}

// ---------- 排班模式 → 当日班次 ----------
function shiftForDay(mode, y, m, d){
  const w = weekday(y, m, d);
  const idx = dayIndex(y, m, d);
  switch(mode){
    case '全天候': return SHIFTS.full;
    case '长白班': case '自定义': return w >= 5 ? null : SHIFTS.bai;
    case '长夜班': return w >= 5 ? null : SHIFTS.ye;
    case '两班倒': return w >= 5 ? null : (weekIndex(y,m,d) % 2 === 1 ? SHIFTS.bai : SHIFTS.ye);
    case '三班倒': return w >= 5 ? null : [SHIFTS.zao, SHIFTS.zhong, SHIFTS.wan][idx % 3];
    default: return null;
  }
}

// 当月纯排班计薪秒数（不含特殊日）—— 基准速率的除数
function monthlyBillableSeconds(y, m, mode){
  let total = 0;
  for(let d = 1; d <= daysInMonth(y, m); d++){
    const s = shiftForDay(mode, y, m, d);
    if(s) total += billableSeconds(s);
  }
  return total;
}

// ---------- 特殊日 → 当日计薪区间（绝对分钟，含倍率） ----------
// special: { 'y-m-d': {type:'overtime',mult,shift} | {type:'leave',s,e} | {type:'off'} }
function dayIntervals(y, m, d, mode, special){
  const key = y + '-' + m + '-' + d;
  const sp = special[key];
  if(sp && sp.type === 'off') return [];                     // 调休：整天计薪 0
  let shift = shiftForDay(mode, y, m, d);
  if(sp && sp.type === 'overtime' && !shift) shift = sp.shift; // 休息日加班：用加班时段（复制班次）
  if(!shift) return [];
  const dayStart = dayIndex(y, m, d) * DAY;
  // 班次时间线切掉休息 → 区间
  const raw = [];
  let s = shift.startMin;
  for(const b of shift.breaks){ raw.push([s, b.s]); s = b.e; }
  raw.push([s, shift.endMin]);
  let mult = 1;
  if(sp && sp.type === 'overtime') mult = sp.mult;
  const out = [];
  if(sp && sp.type === 'leave'){
    const ls = dayStart + sp.s, le = dayStart + sp.e;        // 请假区间（绝对分钟）
    for(const [a, b] of raw){
      const A = dayStart + a, B = dayStart + b;
      if(le <= A || ls >= B){ out.push({s:A, e:B, mult}); }
      else {
        if(A < ls) out.push({s:A, e:ls, mult});
        if(le < B) out.push({s:le, e:B, mult});
      }
    }
  } else {
    for(const [a, b] of raw) out.push({s:dayStart+a, e:dayStart+b, mult});
  }
  return out;
}

// ---------- 收入累计 ----------
// income: {amountYuan, period:'monthly', follow:bool, participate:bool}
// 返回：毫（1 元 = 10000 毫）
function accumulate(y, m, fromD, toD, mode, special, income, endMinute){
  const days = daysInMonth(y, m);
  let rate; // 毫/秒
  if(income.follow){
    rate = income.amountYuan * 10000 / monthlyBillableSeconds(y, m, mode);
  } else {
    const periodSec = income.period === 'monthly' ? days * 86400 : 7 * 86400; // V1 仅月/周
    rate = income.amountYuan * 10000 / periodSec;
  }
  let millis = 0;
  for(let d = fromD; d <= toD; d++){
    const ivs = dayIntervals(y, m, d, mode, special);
    for(const iv of ivs){
      let e = iv.e;
      if(d === toD && endMinute !== undefined) e = Math.min(e, dayIndex(y,m,d)*DAY + endMinute);
      if(e <= iv.s) continue;
      const secs = (e - iv.s) * 60;   // 分钟 → 秒
      const m2 = income.follow && income.participate ? iv.mult : 1;
      millis += secs * m2 * rate;
    }
  }
  return millis;
}

// ============================================================
// 测试（2026 年 11 月；11/1 为周日，工作日 21 天）
// ============================================================
let failed = 0;
function check(name, actual, expected, tol){
  const ok = Math.abs(actual - expected) <= (tol ?? 1);
  if(!ok) failed++;
  console.log((ok ? '✅' : '❌') + ' ' + name + '：' + actual.toFixed(2) + '（期望 ' + expected.toFixed(2) + '）');
}

const Y = 2026, M = 11;
const incomeZhu = { amountYuan: 5000, period:'monthly', follow:true,  participate:true  };
const incomeFu  = { amountYuan: 1000, period:'monthly', follow:false, participate:false };
const special = {
  '2026-11-14': { type:'overtime', mult:1.5, shift:SHIFTS.bai }, // 周六加班 1.5×（复制白班）
  '2026-11-18': { type:'leave',    s:12*H,  e:17*H },            // 请假下午（12:00-17:00，扣计薪 13:00-17:00）
  '2026-11-20': { type:'off' },                                  // 调休
};

// T1 星期验证：11/1 = 周日(6)
check('T1 2026-11-01 是周日', weekday(Y,M,1), 6, 0);

// T2 长白班月计薪秒数 = 21 天 × 8h
check('T2 长白班月计薪秒数', monthlyBillableSeconds(Y,M,'长白班'), 21*8*3600, 0);

// T3 长白班基准速率（毫/秒）= 5000×10000/604800
const rateZhu = incomeZhu.amountYuan * 10000 / monthlyBillableSeconds(Y,M,'长白班');
check('T3 长白班速率（毫/秒）', rateZhu, 5000*10000/604800, 0.01);

// T4 11/14 周六 1.5×：当日收入 = 8h × 1.5 × rate ≈ 357.14 元
check('T4 11/14 加班 1.5× 当日收入（毫）', accumulate(Y,M,14,14,'长白班',special,incomeZhu), 8*3600*1.5*rateZhu, 1);

// T5 11/18 请假下午：当日收入 = 4h × rate ≈ 119.05 元
check('T5 11/18 请假下午当日收入（毫）', accumulate(Y,M,18,18,'长白班',special,incomeZhu), 4*3600*rateZhu, 1);

// T6 11/20 调休：当日收入 = 0
check('T6 11/20 调休当日收入（毫）', accumulate(Y,M,20,20,'长白班',special,incomeZhu), 0, 0);

// T7 11/1→11/16 累计 = (11 个工作日 × 8h + 14 日 12h 等效) × rate ≈ 2976.19 元
const exp7 = (11*8*3600 + 8*3600*1.5) * rateZhu;
check('T7 11/1-16 累计（毫）', accumulate(Y,M,1,16,'长白班',special,incomeZhu), exp7, 1);

// T8 长夜班月计薪秒数 = 21 天 × 9h（跨零点宵夜正确扣除）
check('T8 长夜班月计薪秒数', monthlyBillableSeconds(Y,M,'长夜班'), 21*9*3600, 0);

// T9 11/2(周一) 夜班区间 = 20:00-24:00 + 1:00-6:00 = 9h（0:00-1:00 宵夜不计薪）
check('T9 夜班跨天当日计薪分钟数', (()=>{
  const ivs = dayIntervals(Y,M,2,'长夜班',{});
  return ivs.reduce((a,b)=>a+(b.e-b.s),0);
})(), 9*60, 0);

// T10 两班倒月计薪秒数 = 178h（白周 88h + 夜周 90h）
check('T10 两班倒月计薪秒数', monthlyBillableSeconds(Y,M,'两班倒'), 178*3600, 0);

// T11 全天候副业 1000/月：速率 = 1000×10000/(30×86400)；11/1-16 = 16 天
const rateFu = incomeFu.amountYuan*10000/(30*86400);
check('T11 副业 11/1-16 累计（毫）', accumulate(Y,M,1,16,'全天候',{},incomeFu), 16*86400*rateFu, 1);

// T12 副业不受特殊日影响（14 日加班日也照常涨 24h）
check('T12 副业 11/14 当日（毫）', accumulate(Y,M,14,14,'全天候',{},incomeFu), 86400*rateFu, 1);

// T13 不参与倍率的跟随排班收入：14 日加班按 1.0×
const incomeNoMult = { amountYuan:3000, period:'monthly', follow:true, participate:false };
const rateN = 3000*10000/monthlyBillableSeconds(Y,M,'长白班');
check('T13 不参与倍率：14 日按 1.0×（毫）', accumulate(Y,M,14,14,'长白班',special,incomeNoMult), 8*3600*rateN, 1);

console.log(failed === 0 ? '\n🎉 全部 13 项测试通过' : '\n⚠️ 有 ' + failed + ' 项测试失败');
process.exit(failed === 0 ? 0 : 1);

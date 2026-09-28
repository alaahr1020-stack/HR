import { LOGO, SIDES, SCHOOLS, FORM_TYPES, STATUSES, PIPELINE, OVERDUE_DAYS } from './config.js';
import { createStore, DEMO } from './store.js';

const $ = (sel, root = document) => root.querySelector(sel);
const app = $('#app');

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const statusOf = (id) => STATUSES.find((s) => s.id === id) || { id, label: id, tone: 'neutral' };
const formOf = (id) => FORM_TYPES.find((f) => f.id === id) || { id, label: id, group: 'أخرى' };
const sideName = (s) => (SIDES[s] || {}).short || s;
const fmtDate = (d) => (d ? d.toLocaleDateString('ar-EG', { year: 'numeric', month: 'short', day: 'numeric' }) : '—');
const fmtDateTime = (d) => (d ? d.toLocaleString('ar-EG', { year: 'numeric', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }) : '—');
const daysSince = (d) => (d ? Math.floor((Date.now() - d.getTime()) / 864e5) : 0);
const isOpen = (r) => !['done', 'rejected'].includes(r.status);
const isOverdue = (r) => isOpen(r) && daysSince(r.createdAt) > OVERDUE_DAYS;
const badge = (id) => { const s = statusOf(id); return `<span class="badge tone-${s.tone}">${esc(s.label)}</span>`; };
const safeUrl = (u) => (/^https?:\/\//i.test(u || '') ? u : '');

let store;
let me = null;
let requests = [];
let unsubList = null;
let unsubView = [];
const filters = { q: '', status: '', form: '', school: '', open: false };
const selected = new Set();

function toast(msg, bad = false) {
  document.querySelectorAll('.toast').forEach((x) => x.remove());
  const t = document.createElement('div');
  t.className = 'toast' + (bad ? ' bad' : '');
  t.textContent = msg;
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 3200);
}

function cleanupView() {
  unsubView.forEach((f) => f && f());
  unsubView = [];
}

// ------------------------------------------------------------------ shell
function brand() {
  return `
    <a class="brand" href="#/">
      ${LOGO ? `<img src="${esc(LOGO)}" alt="نيو جيزة">` : ''}
      <span class="brand-text"><b>NEW GIZA</b><small>إدارة المدارس · بورتال التأمينات الاجتماعية</small></span>
    </a>`;
}

function shell(active, body) {
  const nav = [
    ['#/', 'لوحة المتابعة', 'home'],
    ['#/requests', 'المعاملات', 'list'],
    ['#/new', 'معاملة جديدة', 'new'],
  ].map(([h, l, k]) => `<a href="${h}" class="${active === k ? 'on' : ''}">${l}</a>`).join('');
  return `
    ${DEMO ? `<div class="demo-bar">وضع تجريبي — البيانات محفوظة على الجهاز ده بس. اربط Firebase من <code>js/config.js</code> عشان الطرفين يشوفوا نفس البيانات. <button class="link" id="demo-reset">إعادة البيانات التجريبية</button></div>` : ''}
    <header class="top">
      ${brand()}
      <nav>${nav}</nav>
      <div class="who">
        <span class="side side-${esc(me.side)}">${esc(sideName(me.side))}</span>
        <span class="who-name">${esc(me.name)}</span>
        <button class="btn ghost sm" id="logout">خروج</button>
      </div>
    </header>
    <main class="page">${body}</main>
    <footer class="foot">بورتال متابعة خاص بين ${esc(SIDES.ng.name)} و${esc(SIDES.partner.name)} فقط</footer>`;
}

function bindShell() {
  $('#logout').onclick = () => store.logout();
  const r = $('#demo-reset');
  if (r) r.onclick = () => { if (confirm('مسح كل البيانات التجريبية ورجوعها للأصل؟')) store.resetDemo(); };
}

// ------------------------------------------------------------------ login
function renderLogin(err) {
  document.title = 'دخول — بورتال نيو جيزة';
  app.innerHTML = `
    <div class="login-wrap">
      <div class="login-card">
        ${brand()}
        <h1>متابعة معاملات التأمينات الاجتماعية</h1>
        <p class="muted">بورتال مشترك بين ${esc(SIDES.ng.name)} و${esc(SIDES.partner.name)} لمتابعة كل الاستمارات والنماذج من التسليم لحد التسجيل.</p>
        ${err ? `<div class="alert">${esc(err)}</div>` : ''}
        ${DEMO ? `
          <p class="demo-note">وضع تجريبي: اختار الطرف اللي عايز تدخل بيه.</p>
          <div class="stack">
            <button class="btn primary" data-side="ng">دخول كـ ${esc(SIDES.ng.name)}</button>
            <button class="btn" data-side="partner">دخول كـ ${esc(SIDES.partner.name)}</button>
          </div>` : `
          <form id="login" class="stack">
            <label>البريد الإلكتروني<input type="email" name="email" required autocomplete="username" dir="ltr"></label>
            <label>كلمة المرور<input type="password" name="password" required autocomplete="current-password" dir="ltr"></label>
            <button class="btn primary" type="submit">دخول</button>
            <button class="link" type="button" id="forgot">نسيت كلمة المرور؟</button>
          </form>`}
      </div>
    </div>`;
  if (DEMO) {
    app.querySelectorAll('[data-side]').forEach((b) => (b.onclick = () => store.login(b.dataset.side)));
    return;
  }
  $('#login').onsubmit = async (e) => {
    e.preventDefault();
    const f = new FormData(e.target);
    try {
      await store.login(f.get('email').trim(), f.get('password'));
    } catch (_) {
      renderLogin('البريد أو كلمة المرور غلط.');
    }
  };
  $('#forgot').onclick = async () => {
    const email = $('#login [name=email]').value.trim();
    if (!email) return toast('اكتب البريد الإلكتروني الأول', true);
    try { await store.resetPassword(email); toast('اتبعت رابط تغيير كلمة المرور على البريد'); } catch (_) { toast('تعذّر الإرسال', true); }
  };
}

// ------------------------------------------------------------------ dashboard
function renderDashboard() {
  document.title = 'لوحة المتابعة — بورتال نيو جيزة';
  const count = (fn) => requests.filter(fn).length;
  const open = requests.filter(isOpen);
  const tiles = [
    ['إجمالي المعاملات', requests.length, '#/requests', ''],
    ['مفتوحة', open.length, '#/requests?open=1', ''],
    ['لم تُسلَّم بعد', count((r) => r.status === 'new'), '#/requests?status=new', ''],
    ['مطلوب استيفاء', count((r) => r.status === 'needs_info'), '#/requests?status=needs_info', 'danger'],
    [`متأخرة (+${OVERDUE_DAYS} يوم)`, count(isOverdue), '#/requests?overdue=1', 'warn'],
    ['تم التسجيل', count((r) => r.status === 'done'), '#/requests?status=done', 'success'],
  ].map(([l, n, h, t]) => `<a class="tile ${t}" href="${h}"><span>${l}</span><b>${n}</b></a>`).join('');

  const byStatus = STATUSES.map((s) => {
    const n = count((r) => r.status === s.id);
    const pct = requests.length ? Math.round((n / requests.length) * 100) : 0;
    return `<a class="bar-row" href="#/requests?status=${s.id}"><span>${esc(s.label)}</span><span class="bar"><i class="tone-${s.tone}" style="width:${pct}%"></i></span><b>${n}</b></a>`;
  }).join('');

  const byForm = FORM_TYPES.map((f) => [f, requests.filter((r) => r.formType === f.id)])
    .filter(([, rs]) => rs.length)
    .map(([f, rs]) => `<tr><td>${esc(f.label)}</td><td>${rs.length}</td><td>${rs.filter(isOpen).length}</td><td>${rs.filter((r) => r.status === 'done').length}</td></tr>`)
    .join('');

  const waiting = me.side === 'partner'
    ? requests.filter((r) => ['delivered', 'in_progress'].includes(r.status))
    : requests.filter((r) => ['new', 'needs_info'].includes(r.status));
  const waitTitle = me.side === 'partner' ? 'مطلوب منك: معاملات مستلمة لسه ما اتقدمتش' : 'مطلوب منك: معاملات لسه ما اتسلمتش أو مطلوب استيفاؤها';

  const recent = [...requests].sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0)).slice(0, 8);

  app.innerHTML = shell('home', `
    <div class="page-head"><h1>لوحة المتابعة</h1><a class="btn primary" href="#/new">+ معاملة جديدة</a></div>
    <section class="tiles">${tiles}</section>
    <div class="grid2">
      <section class="card"><h2>${waitTitle}</h2>${compactTable(waiting.slice(0, 10)) || '<p class="empty">مفيش حاجة مستنياك 👌</p>'}</section>
      <section class="card"><h2>توزيع المعاملات حسب الحالة</h2><div class="bars">${byStatus}</div></section>
    </div>
    <div class="grid2">
      <section class="card"><h2>حسب نوع النموذج</h2>${byForm ? `<table class="tbl"><thead><tr><th>النموذج</th><th>الإجمالي</th><th>مفتوح</th><th>تم</th></tr></thead><tbody>${byForm}</tbody></table>` : '<p class="empty">لا توجد بيانات</p>'}</section>
      <section class="card"><h2>آخر تحديثات</h2>${compactTable(recent) || '<p class="empty">لا توجد معاملات بعد</p>'}</section>
    </div>`);
  bindShell();
}

// ------------------------------------------------------------------ list
function compactTable(rows) {
  if (!rows.length) return '';
  return `<div class="tbl-wrap"><table class="tbl">
    <thead><tr><th>الرقم</th><th>الموظف / النموذج</th><th>الحالة</th><th>آخر تحديث</th></tr></thead>
    <tbody>${rows.map((r) => `
      <tr class="${isOverdue(r) ? 'overdue' : ''}">
        <td><a href="#/r/${esc(r.id)}" class="ref">${esc(r.ref)}</a></td>
        <td><a href="#/r/${esc(r.id)}">${esc(r.employeeName || '—')}</a><small class="muted d-block">${esc(formOf(r.formType).label)}</small></td>
        <td>${badge(r.status)}${isOverdue(r) ? '<small class="late">متأخرة</small>' : ''}</td>
        <td class="nowrap">${fmtDate(r.updatedAt)}</td>
      </tr>`).join('')}</tbody></table></div>`;
}

function listTable(rows, selectable) {
  if (!rows.length) return '';
  return `<div class="tbl-wrap"><table class="tbl">
    <thead><tr>${selectable ? '<th><input type="checkbox" id="sel-all" aria-label="تحديد الكل"></th>' : ''}<th>الرقم</th><th>الموظف</th><th>النموذج</th><th>الجهة</th><th>الحالة</th><th>تاريخ التسجيل</th></tr></thead>
    <tbody>${rows.map((r) => `
      <tr class="${isOverdue(r) ? 'overdue' : ''}">
        ${selectable ? `<td><input type="checkbox" class="sel" value="${esc(r.id)}" ${selected.has(r.id) ? 'checked' : ''}></td>` : ''}
        <td><a href="#/r/${esc(r.id)}" class="ref">${esc(r.ref)}</a></td>
        <td><a href="#/r/${esc(r.id)}">${esc(r.employeeName || '—')}</a>${r.nationalId ? `<small class="muted d-block" dir="ltr">${esc(r.nationalId)}</small>` : ''}</td>
        <td class="col-form">${esc(formOf(r.formType).label)}</td>
        <td>${esc(r.school || '—')}</td>
        <td>${badge(r.status)}${isOverdue(r) ? '<small class="late">متأخرة</small>' : ''}</td>
        <td class="nowrap">${fmtDate(r.createdAt)}</td>
      </tr>`).join('')}</tbody></table></div>`;
}

function applyFilters(rows, overdue) {
  const q = filters.q.trim().toLowerCase();
  return rows.filter((r) =>
    (!filters.status || r.status === filters.status) &&
    (!filters.form || r.formType === filters.form) &&
    (!filters.school || r.school === filters.school) &&
    (!filters.open || isOpen(r)) &&
    (!overdue || isOverdue(r)) &&
    (!q || [r.ref, r.employeeName, r.nationalId, r.insuranceNo, r.insuranceRef, r.notes].some((v) => String(v || '').toLowerCase().includes(q))));
}

function allSchools() {
  return [...new Set([...SCHOOLS, ...requests.map((r) => r.school).filter(Boolean)])];
}

function renderList(params) {
  document.title = 'المعاملات — بورتال نيو جيزة';
  if (params.has('status')) filters.status = params.get('status');
  if (params.has('open')) filters.open = true;
  const overdue = params.has('overdue');
  const opt = (v, l, cur) => `<option value="${esc(v)}" ${cur === v ? 'selected' : ''}>${esc(l)}</option>`;

  app.innerHTML = shell('list', `
    <div class="page-head"><h1>المعاملات${overdue ? ' المتأخرة' : ''}</h1>
      <div class="actions">
        <button class="btn" id="csv">تصدير Excel (CSV)</button>
        <button class="btn" id="handover" disabled>طباعة كشف تسليم (<span id="sel-n">0</span>)</button>
        <a class="btn primary" href="#/new">+ معاملة جديدة</a>
      </div>
    </div>
    <section class="card filters">
      <input type="search" id="f-q" placeholder="بحث بالاسم / الرقم القومي / الرقم التأميني / رقم المعاملة" value="${esc(filters.q)}">
      <select id="f-status">${opt('', 'كل الحالات', filters.status)}${STATUSES.map((s) => opt(s.id, s.label, filters.status)).join('')}</select>
      <select id="f-form">${opt('', 'كل النماذج', filters.form)}${FORM_TYPES.map((f) => opt(f.id, f.label, filters.form)).join('')}</select>
      <select id="f-school">${opt('', 'كل الجهات', filters.school)}${allSchools().map((s) => opt(s, s, filters.school)).join('')}</select>
      <label class="check"><input type="checkbox" id="f-open" ${filters.open ? 'checked' : ''}> المفتوحة بس</label>
      ${overdue ? '<a class="btn ghost sm" href="#/requests">إلغاء فلتر المتأخرة</a>' : ''}
    </section>
    <section class="card" id="list-body"></section>`);
  bindShell();

  const draw = () => {
    const rows = applyFilters(requests, overdue);
    $('#list-body').innerHTML = `<p class="muted count">${rows.length} معاملة</p>` + (listTable(rows, true) || '<p class="empty">مفيش معاملات مطابقة</p>');
    $('#sel-n').textContent = selected.size;
    $('#handover').disabled = !selected.size;
    const all = $('#sel-all');
    if (all) {
      all.checked = rows.length && rows.every((r) => selected.has(r.id));
      all.onchange = () => { rows.forEach((r) => (all.checked ? selected.add(r.id) : selected.delete(r.id))); draw(); };
    }
    app.querySelectorAll('.sel').forEach((c) => (c.onchange = () => { c.checked ? selected.add(c.value) : selected.delete(c.value); $('#sel-n').textContent = selected.size; $('#handover').disabled = !selected.size; }));
  };
  $('#f-q').oninput = (e) => { filters.q = e.target.value; draw(); };
  $('#f-status').onchange = (e) => { filters.status = e.target.value; draw(); };
  $('#f-form').onchange = (e) => { filters.form = e.target.value; draw(); };
  $('#f-school').onchange = (e) => { filters.school = e.target.value; draw(); };
  $('#f-open').onchange = (e) => { filters.open = e.target.checked; draw(); };
  $('#csv').onclick = () => exportCsv(applyFilters(requests, overdue));
  $('#handover').onclick = () => { location.hash = '#/handover'; };
  draw();
  renderList.redraw = draw;
}

function exportCsv(rows) {
  const cols = [
    ['رقم المعاملة', (r) => r.ref], ['الموظف', (r) => r.employeeName], ['الرقم القومي', (r) => r.nationalId],
    ['الرقم التأميني', (r) => r.insuranceNo], ['الجهة', (r) => r.school], ['النموذج', (r) => formOf(r.formType).label],
    ['الحالة', (r) => statusOf(r.status).label], ['تاريخ التسجيل', (r) => fmtDate(r.createdAt)],
    ['تاريخ التسليم للشركة', (r) => fmtDate(r.deliveredAt)], ['تاريخ التقديم للتأمينات', (r) => fmtDate(r.submittedAt)],
    ['تاريخ الإنهاء', (r) => fmtDate(r.completedAt)], ['رقم الإيصال / القيد', (r) => r.insuranceRef], ['ملاحظات', (r) => r.notes],
  ];
  const cell = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`;
  const csv = '﻿' + [cols.map((c) => cell(c[0])).join(','), ...rows.map((r) => cols.map((c) => cell(c[1](r))).join(','))].join('\r\n');
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
  a.download = `معاملات-التأمينات-${new Date().toISOString().slice(0, 10)}.csv`;
  a.click();
  URL.revokeObjectURL(a.href);
}

// ------------------------------------------------------------------ new / edit
function renderForm(existing) {
  document.title = (existing ? 'تعديل معاملة' : 'معاملة جديدة') + ' — بورتال نيو جيزة';
  const r = existing || {};
  app.innerHTML = shell(existing ? '' : 'new', `
    <div class="page-head"><h1>${existing ? `تعديل ${esc(r.ref)}` : 'تسجيل معاملة جديدة'}</h1></div>
    <form class="card form" id="req-form">
      <div class="fgrid">
        <label class="span2">نوع النموذج / الاستمارة *
          <select name="formType" required>
            <option value="">— اختار —</option>
            ${[...new Set(FORM_TYPES.map((f) => f.group))].map((g) => `<optgroup label="${esc(g)}">${FORM_TYPES.filter((f) => f.group === g).map((f) => `<option value="${f.id}" ${r.formType === f.id ? 'selected' : ''}>${esc(f.label)}</option>`).join('')}</optgroup>`).join('')}
          </select>
        </label>
        <label>اسم الموظف *<input name="employeeName" required value="${esc(r.employeeName)}"></label>
        <label>الرقم القومي<input name="nationalId" inputmode="numeric" pattern="\\d{14}" title="14 رقم" dir="ltr" value="${esc(r.nationalId)}"></label>
        <label>الرقم التأميني<input name="insuranceNo" dir="ltr" value="${esc(r.insuranceNo)}"></label>
        <label>المدرسة / الجهة *<input name="school" list="schools" required value="${esc(r.school)}"><datalist id="schools">${allSchools().map((s) => `<option value="${esc(s)}">`).join('')}</datalist></label>
        <label>الوظيفة<input name="jobTitle" value="${esc(r.jobTitle)}"></label>
        <label>تاريخ الحدث (تعيين / تعديل / انتهاء)<input type="date" name="eventDate" value="${esc(r.eventDate)}"></label>
        <label>عدد الأوراق / المرفقات المسلّمة<input type="number" min="0" name="pages" value="${esc(r.pages)}"></label>
        <label class="span2">رابط المستندات (Google Drive / OneDrive)<input type="url" name="docsLink" dir="ltr" placeholder="https://" value="${esc(r.docsLink)}"></label>
        <label class="span2">ملاحظات<textarea name="notes" rows="3">${esc(r.notes)}</textarea></label>
        ${existing ? '' : `<label class="span2 check"><input type="checkbox" name="delivered"> الورق اتسلّم للشركة فعلاً (المعاملة تبدأ بحالة "تم التسليم للشركة")</label>`}
      </div>
      <div class="form-actions">
        <button class="btn primary" type="submit">${existing ? 'حفظ التعديلات' : 'تسجيل المعاملة'}</button>
        <a class="btn ghost" href="${existing ? `#/r/${esc(r.id)}` : '#/requests'}">إلغاء</a>
      </div>
    </form>`);
  bindShell();

  $('#req-form').onsubmit = async (e) => {
    e.preventDefault();
    const f = new FormData(e.target);
    const data = {};
    for (const k of ['formType', 'employeeName', 'nationalId', 'insuranceNo', 'school', 'jobTitle', 'eventDate', 'pages', 'docsLink', 'notes']) {
      data[k] = String(f.get(k) || '').trim();
    }
    if (data.docsLink && !safeUrl(data.docsLink)) return toast('الرابط لازم يبدأ بـ https://', true);
    const btn = e.target.querySelector('[type=submit]');
    btn.disabled = true;
    try {
      if (existing) {
        await store.updateRequest(r.id, data);
        location.hash = `#/r/${r.id}`;
      } else {
        if (f.get('delivered')) data.status = 'delivered';
        const id = await store.createRequest(data);
        toast('اتسجلت المعاملة');
        location.hash = `#/r/${id}`;
      }
    } catch (err) {
      console.error(err);
      toast('حصل خطأ في الحفظ', true);
      btn.disabled = false;
    }
  };
}

// ------------------------------------------------------------------ detail
function stepper(r) {
  const off = ['needs_info', 'rejected'].includes(r.status);
  const idx = PIPELINE.indexOf(r.status);
  return `<ol class="stepper">${PIPELINE.map((s, i) => {
    const cls = idx >= 0 ? (i < idx || r.status === 'done' ? 'done' : i === idx ? 'cur' : '') : '';
    return `<li class="${cls}"><span>${i + 1}</span>${esc(statusOf(s).label)}</li>`;
  }).join('')}</ol>${off ? `<div class="off-track">${badge(r.status)}</div>` : ''}`;
}

function eventLine(ev) {
  let what = '';
  if (ev.type === 'created') what = `سجّل المعاملة ${ev.to && ev.to !== 'new' ? `بحالة ${badge(ev.to)}` : ''}`;
  else if (ev.type === 'status') what = `غيّر الحالة ${ev.from ? `من ${badge(ev.from)} ` : ''}إلى ${badge(ev.to)}`;
  else if (ev.type === 'edit') what = 'عدّل بيانات المعاملة';
  else what = 'علّق';
  const link = safeUrl(ev.link);
  return `<li class="ev ev-${esc(ev.type)} ev-by-${esc(ev.side)}">
    <div class="ev-head"><b>${esc(ev.byName)}</b> <span class="side side-${esc(ev.side)}">${esc(sideName(ev.side))}</span> ${what}<time>${fmtDateTime(ev.at)}</time></div>
    ${ev.text && ev.type !== 'edit' ? `<p>${esc(ev.text)}</p>` : ''}
    ${link ? `<a href="${esc(link)}" target="_blank" rel="noopener">📎 مستند مرفق</a>` : ''}
  </li>`;
}

function renderDetail(id) {
  let r = null;
  let events = [];
  const draw = () => {
    if (!r) { app.innerHTML = shell('', '<section class="card"><p class="empty">المعاملة مش موجودة</p></section>'); bindShell(); return; }
    document.title = `${r.ref} — بورتال نيو جيزة`;
    const docs = safeUrl(r.docsLink);
    const field = (l, v, ltr) => `<div><dt>${l}</dt><dd ${ltr && v ? 'dir="ltr"' : ''}>${v ? esc(v) : '—'}</dd></div>`;
    const draft = $('#c-text') ? $('#c-text').value : '';
    app.innerHTML = shell('', `
      <div class="page-head">
        <div><a href="#/requests" class="muted">← المعاملات</a><h1>${esc(r.ref)} · ${esc(r.employeeName)}</h1></div>
        <div class="actions">
          <button class="btn" id="print">طباعة إيصال استلام</button>
          <a class="btn" href="#/r/${esc(r.id)}/edit">تعديل البيانات</a>
        </div>
      </div>
      <section class="card">${stepper(r)}</section>
      <div class="grid2 detail">
        <div>
          <section class="card">
            <h2>بيانات المعاملة ${badge(r.status)} ${isOverdue(r) ? '<span class="late">متأخرة</span>' : ''}</h2>
            <dl class="dl">
              ${field('النموذج', formOf(r.formType).label)}
              ${field('المدرسة / الجهة', r.school)}
              ${field('الرقم القومي', r.nationalId, true)}
              ${field('الرقم التأميني', r.insuranceNo, true)}
              ${field('الوظيفة', r.jobTitle)}
              ${field('تاريخ الحدث', r.eventDate)}
              ${field('عدد الأوراق', r.pages)}
              ${field('رقم الإيصال / القيد بالتأمينات', r.insuranceRef)}
              <div><dt>سجّلها</dt><dd>${esc(r.createdByName)} <span class="side side-${esc(r.createdBySide)}">${esc(sideName(r.createdBySide))}</span></dd></div>
              ${field('تاريخ التسجيل', fmtDate(r.createdAt))}
              ${field('التسليم للشركة', fmtDate(r.deliveredAt))}
              ${field('التقديم للتأمينات', fmtDate(r.submittedAt))}
              ${field('تاريخ الإنهاء', fmtDate(r.completedAt))}
              <div class="span2"><dt>المستندات</dt><dd>${docs ? `<a href="${esc(docs)}" target="_blank" rel="noopener">فتح رابط المستندات</a>` : '—'}</dd></div>
              ${r.notes ? `<div class="span2"><dt>ملاحظات</dt><dd class="pre">${esc(r.notes)}</dd></div>` : ''}
            </dl>
          </section>
          <section class="card">
            <h2>تحديث الحالة</h2>
            <form id="status-form" class="stack">
              <select name="to" required>${STATUSES.map((s) => `<option value="${s.id}" ${s.id === r.status ? 'selected' : ''}>${esc(s.label)}</option>`).join('')}</select>
              <input name="insuranceRef" placeholder="رقم الإيصال / القيد بالتأمينات (اختياري)" value="${esc(r.insuranceRef)}">
              <textarea name="text" rows="2" placeholder="ملاحظة على التحديث (مثلاً: المطلوب استيفاؤه)"></textarea>
              <button class="btn primary">حفظ الحالة</button>
            </form>
          </section>
        </div>
        <section class="card">
          <h2>سجل المتابعة والتعليقات</h2>
          <ul class="timeline">${events.map(eventLine).join('') || '<li class="empty">لا يوجد</li>'}</ul>
          <form id="comment-form" class="stack">
            <textarea id="c-text" name="text" rows="3" required placeholder="اكتب رسالة للطرف التاني…"></textarea>
            <input name="link" type="url" dir="ltr" placeholder="رابط مستند (اختياري) https://">
            <button class="btn primary">إرسال</button>
          </form>
        </section>
      </div>`);
    bindShell();
    $('#c-text').value = draft;
    $('#print').onclick = () => printReceipt(r);
    $('#status-form').onsubmit = async (e) => {
      e.preventDefault();
      const f = new FormData(e.target);
      const to = f.get('to');
      const text = String(f.get('text') || '').trim();
      const insuranceRef = String(f.get('insuranceRef') || '').trim();
      if (to === r.status && insuranceRef === (r.insuranceRef || '') && !text) return toast('مفيش تغيير');
      if (to === 'needs_info' && !text) return toast('اكتب المطلوب استيفاؤه في الملاحظة', true);
      try {
        if (to === r.status) {
          if (insuranceRef !== (r.insuranceRef || '')) await store.updateRequest(r.id, { insuranceRef }, `تسجيل رقم الإيصال / القيد: ${insuranceRef}`);
          if (text) await store.addComment(r.id, text);
        } else {
          await store.setStatus(r.id, r.status, to, text, { insuranceRef });
        }
        toast('اتحفظ');
      } catch (err) { console.error(err); toast('حصل خطأ في الحفظ', true); }
    };
    $('#comment-form').onsubmit = async (e) => {
      e.preventDefault();
      const f = new FormData(e.target);
      const link = String(f.get('link') || '').trim();
      if (link && !safeUrl(link)) return toast('الرابط لازم يبدأ بـ https://', true);
      try {
        $('#c-text').value = '';
        await store.addComment(r.id, String(f.get('text')).trim(), link);
      } catch (err) { console.error(err); toast('تعذّر الإرسال', true); }
    };
  };
  unsubView.push(store.watchRequest(id, (x) => { r = x; draw(); }));
  unsubView.push(store.watchEvents(id, (x) => { events = x; draw(); }));
}

// ------------------------------------------------------------------ print
function printDoc(title, body) {
  const w = window.open('', '_blank');
  if (!w) return toast('اسمح بالنوافذ المنبثقة عشان الطباعة', true);
  w.document.write(`<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><title>${esc(title)}</title>
    <link href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;700&display=swap" rel="stylesheet">
    <style>
      body{font-family:Cairo,sans-serif;margin:32px;color:#111}
      header{display:flex;justify-content:space-between;align-items:flex-end;border-bottom:3px solid #0e4d3c;padding-bottom:10px;margin-bottom:18px}
      header b{font-size:22px;letter-spacing:2px;color:#0e4d3c;display:block}
      h1{font-size:20px;margin:0 0 12px}
      table{width:100%;border-collapse:collapse;font-size:13px}
      th,td{border:1px solid #999;padding:6px 8px;text-align:right}
      th{background:#eef3f1}
      .sig{display:flex;gap:40px;margin-top:48px}
      .sig div{flex:1;border-top:1px solid #333;padding-top:6px;text-align:center}
      small{color:#555}
    </style></head><body>
    <header><div><b>NEW GIZA</b><small>إدارة المدارس</small></div><small>${fmtDateTime(new Date())}</small></header>
    ${body}
    <div class="sig"><div>توقيع المُسلِّم — ${esc(SIDES.ng.short)}</div><div>توقيع المُستلِم — ${esc(SIDES.partner.short)}</div></div>
    <script>document.fonts.ready.then(()=>setTimeout(()=>print(),200))<\/script>
    </body></html>`);
  w.document.close();
}

const receiptRow = (r, i) => `<tr><td>${i + 1}</td><td>${esc(r.ref)}</td><td>${esc(r.employeeName)}</td><td dir="ltr">${esc(r.nationalId || '')}</td><td>${esc(formOf(r.formType).label)}</td><td>${esc(r.school || '')}</td><td>${esc(r.pages || '')}</td></tr>`;
const receiptHead = '<tr><th>م</th><th>رقم المعاملة</th><th>الموظف</th><th>الرقم القومي</th><th>النموذج</th><th>الجهة</th><th>عدد الأوراق</th></tr>';

function printReceipt(r) {
  printDoc(`إيصال ${r.ref}`, `<h1>إيصال استلام مستندات تأمينات اجتماعية</h1>
    <table><thead>${receiptHead}</thead><tbody>${receiptRow(r, 0)}</tbody></table>
    ${r.notes ? `<p><b>ملاحظات:</b> ${esc(r.notes)}</p>` : ''}`);
}

function renderHandover() {
  const rows = requests.filter((r) => selected.has(r.id));
  if (!rows.length) { location.hash = '#/requests'; return; }
  printDoc('كشف تسليم', `<h1>كشف تسليم مستندات تأمينات اجتماعية (${rows.length} معاملة)</h1>
    <table><thead>${receiptHead}</thead><tbody>${rows.map(receiptRow).join('')}</tbody></table>`);
  history.replaceState(null, '', '#/requests');
  route();
}

// ------------------------------------------------------------------ router
function route() {
  cleanupView();
  renderList.redraw = null;
  if (!me) return renderLogin();
  const [path, qs] = location.hash.slice(1).split('?');
  const params = new URLSearchParams(qs || '');
  const parts = (path || '/').split('/').filter(Boolean);
  if (!parts.length) return renderDashboard();
  if (parts[0] === 'requests') return renderList(params);
  if (parts[0] === 'new') return renderForm(null);
  if (parts[0] === 'handover') return renderHandover();
  if (parts[0] === 'r' && parts[1] && parts[2] === 'edit') {
    let done = false;
    unsubView.push(store.watchRequest(parts[1], (r) => { if (!done) { done = true; renderForm(r); } }));
    return;
  }
  if (parts[0] === 'r' && parts[1]) return renderDetail(parts[1]);
  location.hash = '#/';
}

function onRequests(rows) {
  requests = rows;
  const [path] = location.hash.slice(1).split('?');
  if (!path || path === '/') renderDashboard();
  else if (path === '/requests' && renderList.redraw) renderList.redraw();
}

(async function main() {
  app.innerHTML = '<div class="loading">جاري التحميل…</div>';
  try {
    store = await createStore();
  } catch (err) {
    console.error(err);
    app.innerHTML = '<div class="loading">تعذّر الاتصال بالخادم. تأكد من الإنترنت وإعدادات Firebase.</div>';
    return;
  }
  store.onAuth((u, err) => {
    me = u;
    if (unsubList) { unsubList(); unsubList = null; }
    requests = [];
    selected.clear();
    if (!u) return renderLogin(err);
    let first = true;
    unsubList = store.watchRequests((rows) => {
      if (first) { first = false; requests = rows; route(); } else onRequests(rows);
    });
  });
  window.addEventListener('hashchange', () => me && route());
})();

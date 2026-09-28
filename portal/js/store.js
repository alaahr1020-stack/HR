// طبقة البيانات: Firebase لو الإعدادات موجودة، وإلا وضع تجريبي على الجهاز (localStorage).
import { firebaseConfig } from './config.js';

export const DEMO = !firebaseConfig.apiKey;

const FB = 'https://www.gstatic.com/firebasejs/10.12.2/';

function refNumber(n, date = new Date()) {
  return `NG-${date.getFullYear()}-${String(n).padStart(4, '0')}`;
}

// ---------------------------------------------------------------- Firebase
async function firebaseStore() {
  const [{ initializeApp }, auth, fs] = await Promise.all([
    import(FB + 'firebase-app.js'),
    import(FB + 'firebase-auth.js'),
    import(FB + 'firebase-firestore.js'),
  ]);
  const app = initializeApp(firebaseConfig);
  const a = auth.getAuth(app);
  const db = fs.getFirestore(app);
  let me = null;

  const eventsCol = (id) => fs.collection(db, 'requests', id, 'events');
  const toDate = (v) => (v && v.toDate ? v.toDate() : v ? new Date(v) : null);
  const norm = (d) => {
    const x = { id: d.id, ...d.data() };
    for (const k of ['createdAt', 'updatedAt', 'deliveredAt', 'submittedAt', 'completedAt', 'at']) {
      if (k in x) x[k] = toDate(x[k]);
    }
    return x;
  };

  async function addEvent(id, ev) {
    await fs.addDoc(eventsCol(id), {
      ...ev,
      by: me.uid,
      byName: me.name,
      side: me.side,
      at: fs.serverTimestamp(),
    });
  }

  return {
    onAuth(cb) {
      auth.onAuthStateChanged(a, async (u) => {
        if (!u) { me = null; return cb(null); }
        let p = null;
        try {
          const snap = await fs.getDoc(fs.doc(db, 'users', u.uid));
          p = snap.exists() ? snap.data() : null;
        } catch (_) { /* قواعد الحماية بترفض القراءة لو الحساب مش متفعّل */ }
        if (!p || !p.active) {
          await auth.signOut(a);
          return cb(null, 'الحساب ده مش متفعّل على البورتال. كلّم مسؤول البورتال.');
        }
        me = { uid: u.uid, email: u.email, name: p.name || u.email, side: p.side };
        cb(me);
      });
    },
    async login(email, password) {
      await auth.signInWithEmailAndPassword(a, email, password);
    },
    async resetPassword(email) {
      await auth.sendPasswordResetEmail(a, email);
    },
    logout: () => auth.signOut(a),

    watchRequests(cb) {
      const q = fs.query(fs.collection(db, 'requests'), fs.orderBy('createdAt', 'desc'), fs.limit(2000));
      return fs.onSnapshot(q, (s) => cb(s.docs.map(norm)));
    },
    watchRequest(id, cb) {
      return fs.onSnapshot(fs.doc(db, 'requests', id), (d) => cb(d.exists() ? norm(d) : null));
    },
    watchEvents(id, cb) {
      const q = fs.query(eventsCol(id), fs.orderBy('at', 'asc'));
      return fs.onSnapshot(q, (s) => cb(s.docs.map(norm)));
    },

    async createRequest(data) {
      const counter = fs.doc(db, 'counters', 'requests');
      const reqRef = fs.doc(fs.collection(db, 'requests'));
      await fs.runTransaction(db, async (t) => {
        const c = await t.get(counter);
        const n = c.exists() ? c.data().n + 1 : 1;
        t.set(counter, { n });
        t.set(reqRef, {
          ...data,
          ref: refNumber(n),
          status: data.status || 'new',
          createdBy: me.uid,
          createdByName: me.name,
          createdBySide: me.side,
          createdAt: fs.serverTimestamp(),
          updatedAt: fs.serverTimestamp(),
          ...(data.status === 'delivered' ? { deliveredAt: fs.serverTimestamp() } : {}),
        });
      });
      await addEvent(reqRef.id, { type: 'created', to: data.status || 'new' });
      return reqRef.id;
    },
    async updateRequest(id, fields, note) {
      await fs.updateDoc(fs.doc(db, 'requests', id), { ...fields, updatedAt: fs.serverTimestamp() });
      await addEvent(id, { type: 'edit', text: note || 'تعديل بيانات المعاملة' });
    },
    async setStatus(id, from, to, text, extra = {}) {
      const stamp = { delivered: 'deliveredAt', submitted: 'submittedAt', done: 'completedAt' }[to];
      await fs.updateDoc(fs.doc(db, 'requests', id), {
        ...extra,
        status: to,
        updatedAt: fs.serverTimestamp(),
        ...(stamp ? { [stamp]: fs.serverTimestamp() } : {}),
      });
      await addEvent(id, { type: 'status', from, to, text: text || '' });
    },
    async addComment(id, text, link) {
      await fs.updateDoc(fs.doc(db, 'requests', id), { updatedAt: fs.serverTimestamp() });
      await addEvent(id, { type: 'comment', text, link: link || '' });
    },
  };
}

// ---------------------------------------------------------------- Demo (localStorage)
function demoStore() {
  const KEY = 'ng-portal-demo-v1';
  const listeners = new Set();
  let me = null;
  let authCb = () => {};

  const load = () => {
    try {
      const d = JSON.parse(localStorage.getItem(KEY));
      if (d && d.requests) return d;
    } catch (_) { /* ignore */ }
    return seed();
  };
  const save = () => {
    try { localStorage.setItem(KEY, JSON.stringify(data)); } catch (_) { /* ignore */ }
    listeners.forEach((f) => f());
  };
  const hydrate = (r) => {
    const x = { ...r };
    for (const k of ['createdAt', 'updatedAt', 'deliveredAt', 'submittedAt', 'completedAt', 'at']) {
      if (x[k]) x[k] = new Date(x[k]);
    }
    return x;
  };
  const uid = () => Math.random().toString(36).slice(2, 10);
  const now = () => new Date().toISOString();
  let data = load();

  function seed() {
    const d = (days) => new Date(Date.now() - days * 864e5).toISOString();
    const ng = { by: 'demo-ng', byName: 'شئون العاملين — نيو جيزة', side: 'ng' };
    const pt = { by: 'demo-partner', byName: 'مسؤول التأمينات — الشركة', side: 'partner' };
    const rows = [
      ['form1', 'أحمد محمود سالم', '29001011234567', '', 'مدرسة (1)', 'done', 20],
      ['form6', 'منى عبد الرحمن علي', '28805052345678', '1234567', 'مدرسة (2)', 'submitted', 9],
      ['form2', 'كريم حسن فؤاد', '29203033456789', '2345678', 'الإدارة العامة للمدارس', 'needs_info', 16],
      ['data_update', 'سارة يوسف إبراهيم', '29507074567890', '3456789', 'مدرسة (1)', 'delivered', 3],
      ['form1', 'محمد عادل رمضان', '29909095678901', '', 'مدرسة (2)', 'new', 1],
    ];
    const requests = [];
    const events = {};
    rows.forEach(([formType, employeeName, nationalId, insuranceNo, school, status, age], i) => {
      const id = uid();
      const order = ['new', 'delivered', 'in_progress', 'submitted', 'done'];
      const r = {
        id, ref: refNumber(i + 1, new Date()), formType, employeeName, nationalId, insuranceNo, school,
        status, notes: '', insuranceRef: status === 'done' ? 'إيصال 99812' : '',
        createdBy: ng.by, createdByName: ng.byName, createdBySide: 'ng',
        createdAt: d(age), updatedAt: d(Math.max(0, age - 2)),
      };
      const ev = [{ id: uid(), type: 'created', to: 'new', at: d(age), ...ng }];
      const target = status === 'needs_info' ? 'submitted' : status;
      const steps = order.slice(1, order.indexOf(target) + 1);
      steps.forEach((s, k) => {
        const at = d(age - (k + 1) * 2 > 0 ? age - (k + 1) * 2 : 0);
        ev.push({ id: uid(), type: 'status', from: order[k], to: s, text: '', at, ...(s === 'delivered' ? ng : pt) });
        if (s === 'delivered') r.deliveredAt = at;
        if (s === 'submitted') r.submittedAt = at;
        if (s === 'done') r.completedAt = at;
      });
      if (status === 'needs_info') {
        ev.push({ id: uid(), type: 'status', from: 'submitted', to: 'needs_info', text: 'مطلوب صورة بطاقة سارية ومفردات مرتب معتمدة.', at: d(3), ...pt });
      }
      requests.push(r);
      events[id] = ev;
    });
    return { counter: rows.length, requests, events };
  }

  return {
    onAuth(cb) {
      authCb = cb;
      let side = null;
      try { side = sessionStorage.getItem('ng-portal-demo-side'); } catch (_) { /* ignore */ }
      this._set(side);
    },
    _set(side) {
      me = side ? {
        uid: 'demo-' + side,
        email: side + '@demo',
        name: side === 'ng' ? 'شئون العاملين — نيو جيزة' : 'مسؤول التأمينات — الشركة',
        side,
      } : null;
      authCb(me);
    },
    async login(side) {
      try { sessionStorage.setItem('ng-portal-demo-side', side); } catch (_) { /* ignore */ }
      this._set(side);
    },
    async resetPassword() {},
    async logout() {
      try { sessionStorage.removeItem('ng-portal-demo-side'); } catch (_) { /* ignore */ }
      this._set(null);
    },
    resetDemo() { data = seed(); save(); },

    watchRequests(cb) {
      const f = () => cb([...data.requests].sort((a, b) => b.createdAt.localeCompare(a.createdAt)).map(hydrate));
      listeners.add(f); f();
      return () => listeners.delete(f);
    },
    watchRequest(id, cb) {
      const f = () => { const r = data.requests.find((x) => x.id === id); cb(r ? hydrate(r) : null); };
      listeners.add(f); f();
      return () => listeners.delete(f);
    },
    watchEvents(id, cb) {
      const f = () => cb((data.events[id] || []).map(hydrate));
      listeners.add(f); f();
      return () => listeners.delete(f);
    },
    _event(id, ev) {
      (data.events[id] ||= []).push({ id: uid(), at: now(), by: me.uid, byName: me.name, side: me.side, ...ev });
    },
    async createRequest(fields) {
      const id = uid();
      data.counter += 1;
      const status = fields.status || 'new';
      data.requests.push({
        ...fields, id, ref: refNumber(data.counter), status,
        createdBy: me.uid, createdByName: me.name, createdBySide: me.side,
        createdAt: now(), updatedAt: now(), ...(status === 'delivered' ? { deliveredAt: now() } : {}),
      });
      this._event(id, { type: 'created', to: status });
      save();
      return id;
    },
    async updateRequest(id, fields, note) {
      Object.assign(data.requests.find((x) => x.id === id), fields, { updatedAt: now() });
      this._event(id, { type: 'edit', text: note || 'تعديل بيانات المعاملة' });
      save();
    },
    async setStatus(id, from, to, text, extra = {}) {
      const r = data.requests.find((x) => x.id === id);
      const stamp = { delivered: 'deliveredAt', submitted: 'submittedAt', done: 'completedAt' }[to];
      Object.assign(r, extra, { status: to, updatedAt: now() }, stamp ? { [stamp]: now() } : {});
      this._event(id, { type: 'status', from, to, text: text || '' });
      save();
    },
    async addComment(id, text, link) {
      data.requests.find((x) => x.id === id).updatedAt = now();
      this._event(id, { type: 'comment', text, link: link || '' });
      save();
    },
  };
}

export async function createStore() {
  return DEMO ? demoStore() : firebaseStore();
}

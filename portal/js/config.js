// إعدادات البورتال — عدّل الملف ده بس عشان تغيّر الإعدادات.

// 1) بيانات مشروع Firebase (من Project settings > Your apps > Web app).
//    لو سبتها فاضية، البورتال بيشتغل "وضع تجريبي" والبيانات بتتحفظ على الجهاز بس.
export const firebaseConfig = {
  apiKey: 'AIzaSyDYxJPbsKT1drSnBrmpwIbZY-8CnGeHAz0',
  authDomain: 'newgiza-portal.firebaseapp.com',
  projectId: 'newgiza-portal',
  storageBucket: 'newgiza-portal.firebasestorage.app',
  messagingSenderId: '619221708696',
  appId: '1:619221708696:web:699e2af1b1b7a2d24a45ed',
};

// شعار نيو جيزة الرسمي: حط الملف في portal/assets واكتب اسمه هنا (مثلاً 'assets/logo.png').
// لو فاضي، بيظهر اسم NEW GIZA مكتوب.
export const LOGO = '';

// 2) أسماء الطرفين (التراكينج بين الطرفين دول بس).
export const SIDES = {
  ng: { name: 'نيو جيزة — إدارة المدارس', short: 'نيو جيزة' },
  partner: { name: 'بروسيرف — شركة التأمينات', short: 'بروسيرف' },
};

// 3) المدارس / الجهات التابعة (بتظهر كاختيارات، وتقدر تكتب غيرها).
export const SCHOOLS = [
  'الإدارة العامة للمدارس',
  'مدرسة (1)',
  'مدرسة (2)',
];

// 4) أنواع النماذج والاستمارات.
export const FORM_TYPES = [
  { id: 'form1', label: 'استمارة 1 — اشتراك مؤمن عليه جديد', group: 'تسجيل' },
  { id: 'form2', label: 'استمارة 2 — تعديل أجر الاشتراك', group: 'تعديل' },
  { id: 'data_update', label: 'تعديل بيانات مؤمن عليه (اسم / رقم قومي / وظيفة)', group: 'تعديل' },
  { id: 'form6', label: 'استمارة 6 — إخطار انتهاء خدمة', group: 'انتهاء خدمة' },
  { id: 'print', label: 'برنت تأميني / بيان مدد اشتراك', group: 'استخراج' },
  { id: 'injury', label: 'إخطار إصابة عمل', group: 'إخطار' },
  { id: 'establishment', label: 'تحديث بيانات المنشأة', group: 'منشأة' },
  { id: 'monthly', label: 'كشف الاشتراكات الشهري / السداد', group: 'منشأة' },
  { id: 'other', label: 'نموذج آخر', group: 'أخرى' },
];

// 5) مراحل المعاملة بالترتيب.
export const STATUSES = [
  { id: 'new', label: 'مسجّل — لم يُسلَّم', tone: 'neutral' },
  { id: 'delivered', label: 'تم التسليم للشركة', tone: 'info' },
  { id: 'in_progress', label: 'قيد التنفيذ', tone: 'info' },
  { id: 'submitted', label: 'مُقدَّم للتأمينات', tone: 'warn' },
  { id: 'needs_info', label: 'مطلوب استيفاء', tone: 'danger' },
  { id: 'done', label: 'تم التسجيل بالتأمينات', tone: 'success' },
  { id: 'rejected', label: 'مرفوض / ملغي', tone: 'muted' },
];

// المراحل اللي بتظهر في شريط التقدم.
export const PIPELINE = ['new', 'delivered', 'in_progress', 'submitted', 'done'];

// المعاملة تعتبر متأخرة لو فاتت الأيام دي من غير ما تخلص.
export const OVERDUE_DAYS = 14;

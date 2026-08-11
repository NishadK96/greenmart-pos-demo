import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localeProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  static const _key = 'app_locale';

  @override
  Locale build() {
    _restore();
    return const Locale('en');
  }

  Future<void> _restore() async {
    final saved = (await SharedPreferences.getInstance()).getString(_key);
    if (saved != null && saved != state.languageCode) {
      state = Locale(saved);
    }
  }

  Future<void> setLanguage(String code) async {
    state = Locale(code);
    await (await SharedPreferences.getInstance()).setString(_key, code);
  }
}

class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const delegate = _AppLocalizationsDelegate();

  String tr(String text) =>
      locale.languageCode == 'ar' ? _ar[text] ?? text : text;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension LocalizationBuildContext on BuildContext {
  String tr(String text) => AppLocalizations.of(this).tr(text);
  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';
}

const Map<String, String> _ar = {
  'RetailFlow': 'ريتيل فلو',
  'GreenMart': 'جرين مارت',
  'Point of Sale': 'نقطة البيع',
  'POS': 'نقطة البيع',
  'Dashboard': 'لوحة التحكم',
  'Products': 'المنتجات',
  'Categories': 'الفئات',
  'Purchases': 'المشتريات',
  'Inventory': 'المخزون',
  'Customers': 'العملاء',
  'Sales': 'المبيعات',
  'Reports': 'التقارير',
  'Sync': 'المزامنة',
  'Settings': 'الإعدادات',
  'More': 'المزيد',
  'Online': 'متصل',
  'Synced': 'تمت المزامنة',
  'New sale': 'عملية بيع جديدة',
  'WORKSPACE': 'مساحة العمل',
  'Main Store': 'المتجر الرئيسي',
  'Administrator': 'مدير النظام',
  'Search by name, SKU or barcode...':
      'ابحث بالاسم أو رمز المنتج أو الباركود...',
  'Scan barcode or search product to add':
      'امسح الباركود أو ابحث عن منتج لإضافته',
  'All': 'الكل',
  'Grocery': 'بقالة',
  'Beverages': 'مشروبات',
  'Snacks': 'وجبات خفيفة',
  'Household': 'منزلية',
  'Personal Care': 'العناية الشخصية',
  'Grid': 'شبكة',
  'List': 'قائمة',
  'Top selling': 'الأكثر مبيعاً',
  'Current Order': 'الطلب الحالي',
  'Clear': 'مسح',
  'Walk-in Customer': 'عميل نقدي',
  'Customer': 'العميل',
  'Payment': 'الدفع',
  'Subtotal': 'المجموع الفرعي',
  'Tax (5%)': 'الضريبة (5%)',
  'Discount': 'الخصم',
  'Grand Total': 'الإجمالي',
  'View cart': 'عرض السلة',
  'Select customer': 'اختر العميل',
  'Cash': 'نقداً',
  'Card': 'بطاقة',
  'UPI': 'دفع إلكتروني',
  'items': 'عناصر',
  'item': 'عنصر',
  'each': 'للوحدة',
  'Search products': 'البحث في المنتجات',
  'Add product': 'إضافة منتج',
  'Product name': 'اسم المنتج',
  'Selling price': 'سعر البيع',
  'Opening stock': 'المخزون الافتتاحي',
  'Cancel': 'إلغاء',
  'Save product': 'حفظ المنتج',
  'Import': 'استيراد',
  'Bulk update': 'تحديث جماعي',
  'Quick add': 'إضافة سريعة',
  'New product': 'منتج جديد',
  'Quick add product': 'إضافة منتج سريعة',
  'Edit product': 'تعديل المنتج',
  'Create product': 'إنشاء منتج',
  'Create a sellable product with optional opening stock.':
      'أنشئ منتجاً قابلاً للبيع مع مخزون افتتاحي اختياري.',
  'Product details are saved directly to EazyERP.':
      'تُحفظ تفاصيل المنتج مباشرة في إيزي ERP.',
  'Manage inventory': 'إدارة المخزون',
  'Save changes': 'حفظ التغييرات',
  'Bulk update products': 'تحديث المنتجات جماعياً',
  'Apply category, location, or selling price to selected products.':
      'طبّق الفئة أو الموقع أو سعر البيع على المنتجات المحددة.',
  'Import products': 'استيراد المنتجات',
  'Upload the EazyERP product spreadsheet template.':
      'ارفع قالب جدول منتجات إيزي ERP.',
  'Add purchase': 'إضافة مشتريات',
  'Receive purchase': 'استلام مشتريات',
  'Product': 'المنتج',
  'Quantity': 'الكمية',
  'Purchase rate': 'سعر الشراء',
  'Save draft': 'حفظ كمسودة',
  'Save purchase': 'حفظ المشتريات',
  'Low stock': 'مخزون منخفض',
  'Out of stock': 'نفد المخزون',
  'Type': 'النوع',
  'Apply adjustment': 'تطبيق التعديل',
  'Today': 'اليوم',
  'Yesterday': 'أمس',
  'This week': 'هذا الأسبوع',
  'This month': 'هذا الشهر',
  'Close': 'إغلاق',
  'Print': 'طباعة',
  'Sync now': 'مزامنة الآن',
  'Start a sale': 'بدء عملية بيع',
  'Start new sale': 'بدء عملية بيع جديدة',
  'View sales history': 'عرض سجل المبيعات',
  'Share': 'مشاركة',
  'Email or username': 'البريد الإلكتروني أو اسم المستخدم',
  'Password': 'كلمة المرور',
  'Remember me': 'تذكرني',
  'Forgot password?': 'هل نسيت كلمة المرور؟',
  'Sign in': 'تسجيل الدخول',
  'English': 'English',
  'Arabic': 'العربية',
  'Language': 'اللغة',
  'Basmati Rice 5kg': 'أرز بسمتي 5 كجم',
  'Whole Wheat Flour': 'دقيق القمح الكامل',
  'Toor Dal 1kg': 'عدس تور 1 كجم',
  'Organic Sugar': 'سكر عضوي',
  'Sunflower Oil 1L': 'زيت دوار الشمس 1 لتر',
  'Tata Salt': 'ملح تاتا',
  'Fresh Milk 1L': 'حليب طازج 1 لتر',
  'Orange Juice': 'عصير برتقال',
  'Mineral Water': 'مياه معدنية',
  'Cola 750ml': 'كولا 750 مل',
  'Green Tea': 'شاي أخضر',
  'Instant Coffee': 'قهوة سريعة التحضير',
  'Masala Chips': 'رقائق ماسالا',
  'Salted Peanuts': 'فول سوداني مملح',
  'Cream Biscuits': 'بسكويت بالكريمة',
  'Dark Chocolate': 'شوكولاتة داكنة',
  'Roasted Makhana': 'مخانا محمصة',
  'Granola Bar': 'لوح جرانولا',
  'Dishwash Liquid': 'سائل غسيل الصحون',
  'Laundry Detergent': 'منظف الغسيل',
  'Floor Cleaner': 'منظف الأرضيات',
  'Kitchen Towels': 'مناشف المطبخ',
  'Garbage Bags': 'أكياس القمامة',
  'Aluminium Foil': 'رقائق ألمنيوم',
  'Herbal Shampoo': 'شامبو عشبي',
  'Bath Soap': 'صابون استحمام',
  'Toothpaste': 'معجون أسنان',
  'Hand Wash': 'غسول اليدين',
  'Face Cream': 'كريم للوجه',
  'Body Lotion': 'لوشن للجسم',
  'Store open': 'المتجر مفتوح',
  'Good morning, Nishad': 'صباح الخير، نيشاد',
  'Your store is on track. Here’s today at a glance.':
      'متجرك يسير بشكل جيد. إليك ملخص اليوم.',
  'Add stock': 'إضافة مخزون',
  "Today's sales": 'مبيعات اليوم',
  'Transactions': 'المعاملات',
  'Gross profit': 'إجمالي الربح',
  'Pending sync': 'مزامنة معلقة',
  'Purchases today': 'مشتريات اليوم',
  '7-day sales summary': 'ملخص مبيعات 7 أيام',
  'Recent sales': 'أحدث المبيعات',
  'Manage pricing, stock and barcodes.': 'إدارة الأسعار والمخزون والباركود.',
  'Organize products for faster checkout.': 'نظّم المنتجات لإتمام البيع بسرعة.',
  'Receive supplier stock locally.': 'استلام مخزون المورد محلياً.',
  'Live local stock and adjustments.': 'المخزون المحلي والتعديلات المباشرة.',
  'Customer profiles for faster billing.': 'ملفات العملاء لفوترة أسرع.',
  'Sales history': 'سجل المبيعات',
  'Local and synchronized transactions.': 'المعاملات المحلية والمتزامنة.',
  'Sales report': 'تقرير المبيعات',
  'Performance from locally available transactions.':
      'الأداء استناداً إلى المعاملات المحلية.',
  'Total sales': 'إجمالي المبيعات',
  'Total orders': 'إجمالي الطلبات',
  'Average order': 'متوسط الطلب',
  'Tax collected': 'الضريبة المحصلة',
  'Sales trend': 'اتجاه المبيعات',
  'Top selling products': 'المنتجات الأكثر مبيعاً',
  'Synchronization': 'المزامنة',
  'Offline changes remain safely queued on this device.':
      'تظل التغييرات دون اتصال محفوظة بأمان على هذا الجهاز.',
  'Internet status': 'حالة الإنترنت',
  'Pending records': 'السجلات المعلقة',
  'Failed records': 'السجلات الفاشلة',
  'Sync queue': 'قائمة انتظار المزامنة',
  'All local records are synchronized': 'تمت مزامنة جميع السجلات المحلية',
  'Pending': 'معلق',
  'Total': 'الإجمالي',
  'Tax': 'الضريبة',
  'Configure your business and connected services.':
      'إعداد نشاطك التجاري والخدمات المتصلة.',
  'Business profile': 'ملف النشاط التجاري',
  'Tax settings': 'إعدادات الضريبة',
  'Invoice settings': 'إعدادات الفاتورة',
  'Printer settings': 'إعدادات الطابعة',
  'Sync settings': 'إعدادات المزامنة',
  'Appearance': 'المظهر',
  'User & profile': 'المستخدم والملف الشخصي',
  'Light theme': 'المظهر الفاتح',
  'Receipt template and numbering': 'قالب الإيصال والترقيم',
  'Sell smarter.\nStay in control.': 'بِع بذكاء.\nابقَ مسيطراً.',
  'Fast checkout, accurate stock, and an offline-first workflow for modern retail.':
      'دفع سريع، ومخزون دقيق، وتجربة تعمل دون اتصال لتجارة التجزئة الحديثة.',
  'Ready even when the internet is not': 'جاهز حتى عندما لا يتوفر الإنترنت',
  'Welcome back': 'مرحباً بعودتك',
  'Sign in to open your store.': 'سجّل الدخول لفتح متجرك.',
  'Sale complete': 'اكتملت عملية البيع',
  'Thank you for shopping with us': 'شكراً لتسوقك معنا',
  'Pending synchronization': 'في انتظار المزامنة',
  'Adjust': 'تعديل',
  'No products match this filter': 'لا توجد منتجات مطابقة لهذا الفلتر',
  'Tap a product to start a sale': 'اضغط على منتج لبدء عملية بيع',
  'Minimum': 'الحد الأدنى',
  'left': 'متبقي',
  'Out': 'نفد',
  'UPI / Digital': 'دفع إلكتروني',
  'Collect': 'تحصيل',
  'Enter your username and password.': 'أدخل اسم المستخدم وكلمة المرور.',
  'The username or password is incorrect.':
      'اسم المستخدم أو كلمة المرور غير صحيحة.',
  'Login is not configured. Add the OAuth client secret to the build.':
      'تسجيل الدخول غير مُعد. أضف سر عميل OAuth إلى عملية البناء.',
  'Unable to reach the server. Check your connection.':
      'تعذر الوصول إلى الخادم. تحقق من اتصالك.',
  'Login failed. Please try again.': 'فشل تسجيل الدخول. حاول مرة أخرى.',
};

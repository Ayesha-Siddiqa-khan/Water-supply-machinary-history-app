import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  bool get _isUrdu => locale.languageCode.toLowerCase().startsWith('ur');

  String _t(String en, String ur) => _isUrdu ? ur : en;

  String get appTitle => _t('Water Supply Scheme History', 'واٹر سپلائی اسکیم ہسٹری');
  String get adminPanel => _t('Admin Panel', 'ایڈمن پینل');
  String get navDashboard => _t('Dashboard', 'ڈیش بورڈ');
  String get navSchemes => _t('Schemes', 'اسکیمیں');
  String get navUselessItems => _t('Useless Items', 'ناقابلِ استعمال اشیاء');
  String get navMiscellaneous => _t('Miscellaneous', 'متفرق');
  String get navImport => _t('Import', 'امپورٹ');
  String get navExport => _t('Export', 'ایکسپورٹ');
  String get navSettings => _t('Settings', 'ترتیبات');

  String get settingsLanguage => _t('Language', 'زبان');
  String get settingsLanguageSubtitle => _t('Choose application language', 'ایپلیکیشن کی زبان منتخب کریں');
  String get languageEnglish => _t('English', 'انگریزی');
  String get languageUrdu => _t('Urdu', 'اردو');
  String get languageSetEnglish => _t('Language set to English', 'زبان انگریزی کر دی گئی');
  String get languageSetUrdu => _t('Language set to Urdu', 'زبان اردو کر دی گئی');
  String get settingsHeading => _t('Settings', 'ترتیبات');
  String get settingsSubheading => _t('System Configuration', 'سسٹم کنفیگریشن');
  String get appearanceLabel => _t('APPEARANCE', 'ظاہری شکل');
  String get darkModeTitle => _t('Dark Mode', 'ڈارک موڈ');
  String get darkModeSubtitle => _t('Switch between light and dark theme', 'لائٹ اور ڈارک تھیم کے درمیان تبدیل کریں');

  String get loginSubtitle => _t('Sign in to continue', 'جاری رکھنے کے لئے سائن اِن کریں');
  String get loginUsername => _t('Username', 'یوزر نیم');
  String get loginUsernameRequired => _t('Username is required', 'یوزر نیم ضروری ہے');
  String get loginPassword => _t('Password', 'پاس ورڈ');
  String get loginPasswordRequired => _t('Password is required', 'پاس ورڈ ضروری ہے');
  String get loginRememberMe => _t('Remember me', 'مجھے یاد رکھیں');
  String get loginDefaultCredentials => _t('Default login: admin / admin123', 'ڈیفالٹ لاگ اِن: admin / admin123');
  String get loginSigningIn => _t('Signing in...', 'سائن اِن ہو رہا ہے...');
  String get loginButton => _t('Login', 'لاگ اِن');
  String get loginInvalidCredentials => _t('Invalid username or password', 'یوزر نیم یا پاس ورڈ غلط ہے');
  String get loginFailedPrefix => _t('Login failed', 'لاگ اِن ناکام');

  String get uselessEmptyTitle => _t('No useless items yet', 'ابھی کوئی ناقابلِ استعمال آئٹمز نہیں');
  String get uselessEmptySubtitle => _t(
    'Add a useless item scheme and then create sets and items inside it',
    'ایک ناقابلِ استعمال آئٹم اسکیم شامل کریں پھر اس میں سیٹس اور آئٹمز بنائیں',
  );
  String get uselessAddButton => _t('Add Useless Item', 'ناقابلِ استعمال آئٹم شامل کریں');

  String get commonErrorPrefix => _t('Error', 'خرابی');
  String get commonCancel => _t('Cancel', 'منسوخ');
  String get commonDelete => _t('Delete', 'حذف کریں');
  String get commonEdit => _t('Edit', 'ترمیم');
  String get commonClose => _t('Close', 'بند کریں');
  String get commonSaveAs => _t('Save As', 'محفوظ کریں بطور');
  String get commonShare => _t('Share', 'شیئر');
  String get commonWhatsappShare => _t('WhatsApp Share', 'واٹس ایپ شیئر');
  String get commonUntitled => _t('Untitled', 'بلا عنوان');

  String get schemeDeleteTitle => _t('Delete Scheme', 'اسکیم حذف کریں');
  String schemeDeleteMessage(String name) => _t(
    'Are you sure you want to delete "$name"?\nThis will delete ALL sets, machinery, and billing entries under this scheme.',
    'کیا آپ واقعی "$name" کو حذف کرنا چاہتے ہیں؟\nاس سے اس اسکیم کے تمام سیٹس، مشینری اور بلنگ اندراجات حذف ہو جائیں گے۔',
  );
  String get schemeDeletedSuccess => _t('Scheme deleted successfully', 'اسکیم کامیابی سے حذف ہو گئی');
  String schemeSetsCount(int count) => _t('$count Sets', '$count سیٹس');

  String get importTitle => _t('Import from Excel', 'ایکسل سے امپورٹ');
  String get importInstructionsTitle => _t('Import Instructions', 'امپورٹ ہدایات');
  String get importInstructionsBody => _t(
    'Select an Excel (.xlsx) file to import billing records.\n\nExpected format:\n• Each sheet represents a Set (e.g., "Tanky 2")\n• Sheets contain machinery sub-heads (Motor, Pump, Transformer, etc.)\n• Columns: Sr.No, Date, Voucher No., Amount, Reg. Page No.\n\nThe system will parse and preview the data before importing.',
    'بلنگ ریکارڈز امپورٹ کرنے کے لئے ایک ایکسل (.xlsx) فائل منتخب کریں۔\n\nمتوقع فارمیٹ:\n• ہر شیٹ ایک سیٹ کی نمائندگی کرتی ہے (مثلاً "Tanky 2")\n• شیٹس میں مشینری سب ہیڈز ہوں (Motor, Pump, Transformer وغیرہ)\n• کالمز: Sr.No, Date, Voucher No., Amount, Reg. Page No.\n\nسسٹم امپورٹ سے پہلے ڈیٹا کو پارس اور پری ویو کرے گا۔',
  );
  String get importParsing => _t('Parsing...', 'پارس ہو رہا ہے...');
  String get importTapToSelect => _t('Tap to select Excel file (.xlsx)', 'ایکسل فائل (.xlsx) منتخب کرنے کے لئے ٹیپ کریں');
  String get importSupportedFormat => _t('Supported format: .xlsx (Microsoft Excel)', 'سپورٹڈ فارمیٹ: .xlsx (Microsoft Excel)');
  String get importErrorPickingFile => _t('Error picking file', 'فائل منتخب کرنے میں خرابی');
  String get importErrorParsingFile => _t('Error parsing file', 'فائل پارس کرنے میں خرابی');
  String get importNoDataFound => _t(
    'No data found in the Excel file. Make sure it follows the expected format.',
    'ایکسل فائل میں کوئی ڈیٹا نہیں ملا۔ یقینی بنائیں کہ فارمیٹ درست ہے۔',
  );

  String get exportSelectScheme => _t('Please select a scheme', 'براہ کرم ایک اسکیم منتخب کریں');
  String get exportSelectSet => _t('Please select a set', 'براہ کرم ایک سیٹ منتخب کریں');
  String get exportSelectMiscItem => _t('Please select a miscellaneous item', 'براہ کرم ایک متفرق آئٹم منتخب کریں');
  String get exportErrorPrefix => _t('Export error', 'ایکسپورٹ خرابی');
  String get exportCompleteTitle => _t('Export Complete', 'ایکسپورٹ مکمل');
  String exportFileSavedTo(String path) => _t('File saved to:\n$path', 'فائل محفوظ ہوئی:\n$path');
  String get exportOpenFolder => _t('Open Folder', 'فولڈر کھولیں');
  String get exportShareText => _t('City Water Works - Export File', 'سٹی واٹر ورکس - ایکسپورٹ فائل');
  String get exportScopeTitle => _t('Export Scope', 'ایکسپورٹ اسکوپ');
  String get exportScopeSingleSet => _t('Single Set', 'سنگل سیٹ');
  String get exportScopeEntireSchemes => _t('Entire Schemes', 'مکمل اسکیمیں');
  String get exportSelectSchemeField => _t('Select Scheme', 'اسکیم منتخب کریں');
  String get exportMiscSingleItem => _t('Single Item', 'سنگل آئٹم');
  String get exportMiscComplete => _t('Complete', 'مکمل');
  String get exportMiscModeTitle => _t('Miscellaneous Mode', 'متفرق موڈ');
  String get exportSelectMiscField => _t('Select Miscellaneous Item', 'متفرق آئٹم منتخب کریں');
  String get exportMiscCompleteTitle => _t('Complete Miscellaneous Export', 'مکمل متفرق ایکسپورٹ');
  String get exportMiscCompleteSubtitle => _t('Exports all miscellaneous items and expenditures.', 'تمام متفرق آئٹمز اور اخراجات ایکسپورٹ ہوتے ہیں۔');
  String get exportSelectSetField => _t('Select Set', 'سیٹ منتخب کریں');
  String get exportSelectMachineryField => _t('Select Machinery', 'مشینری منتخب کریں');
  String get exportAllMachineryInSet => _t('All Machinery in this Set', 'اس سیٹ کی تمام مشینری');
  String get exportFormatTitle => _t('Export Format', 'ایکسپورٹ فارمیٹ');
  String get exportFormatPdf => _t('PDF Document', 'پی ڈی ایف دستاویز');
  String get exportFormatExcel => _t('Excel Spreadsheet', 'ایکسل اسپریڈشیٹ');
  String get exportFormatCsv => _t('CSV File', 'سی ایس وی فائل');
  String get exportInProgress => _t('Exporting...', 'ایکسپورٹ ہو رہا ہے...');
  String get exportAllMachinerySinglePdf => _t('Export All Machinery (Single PDF)', 'تمام مشینری ایکسپورٹ کریں (سنگل PDF)');

  String get dashboardLoadError => _t('Error loading data', 'ڈیٹا لوڈ کرنے میں خرابی');
  String get dashboardMachineryPdfReady => _t('Machinery PDF Ready', 'مشینری PDF تیار ہے');
  String get dashboardMachineryShareText => _t('City Water Works - Machinery Report', 'سٹی واٹر ورکس - مشینری رپورٹ');
  String get dashboardGenerateReportError => _t('Error generating report', 'رپورٹ بنانے میں خرابی');
  String get dashboardAllMachineryPdfReady => _t('All Machinery PDF Ready', 'تمام مشینری PDF تیار ہے');
  String get dashboardAllMachineryShareText => _t('City Water Works - Complete Machinery Report', 'سٹی واٹر ورکس - مکمل مشینری رپورٹ');
  String get dashboardGenerateFullReportError => _t('Error generating full report', 'مکمل رپورٹ بنانے میں خرابی');
  String get dashboardOverview => _t('City Water Works Overview', 'سٹی واٹر ورکس کا خلاصہ');
  String get dashboardActive => _t('Active', 'فعال');
  String get dashboardTotalSchemes => _t('Total Schemes', 'کل اسکیمیں');
  String get dashboardTotalSets => _t('Total Sets', 'کل سیٹس');
  String get dashboardEntriesPerMonth => _t('Entries / Month', 'اندراجات / ماہ');
  String get dashboardAmountPerMonth => _t('Amount / Month', 'رقم / ماہ');
  String get dashboardMonthlyExpenditure => _t('Monthly Expenditure', 'ماہانہ اخراجات');
  String get dashboardMachineryStatus => _t('Machinery Functional Status', 'مشینری فعال حالت');
  String get dashboardGenerating => _t('Generating...', 'تیار ہو رہا ہے...');
  String get dashboardExportAllMachinery => _t('Export All Machinery', 'تمام مشینری ایکسپورٹ');
  String get dashboardFunctional => _t('Functional', 'فعال');
  String get dashboardRecentBillingEntries => _t('Recent Billing Entries', 'حالیہ بلنگ اندراجات');
  String get dashboardSetsLowercase => _t('sets', 'سیٹس');
  String get dashboardSearchHint => _t('Search schemes, vouchers, amounts...', 'اسکیمیں، واؤچر، رقوم تلاش کریں...');
  String dashboardSearchResults(int count) => _t('Search Results ($count)', 'تلاش کے نتائج ($count)');
  String dashboardFilePreparedAt(String path) => _t('File prepared at:\n$path', 'فائل تیار ہوئی:\n$path');
  String get dashboardChooseSavePath => _t('Choose Save Path', 'محفوظ کرنے کی جگہ منتخب کریں');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    final code = locale.languageCode.toLowerCase();
    return code == 'en' || code == 'ur';
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

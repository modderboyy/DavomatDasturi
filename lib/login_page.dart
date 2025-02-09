import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:DavomatYettilik/main.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_cupertino_navigation_bar/super_cupertino_navigation_bar.dart';

class LoginPage extends StatefulWidget {
  final void Function(bool) onLoginSuccess;

  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final _logger = Logger();
  String? _applicationStatusMessage;
  List<Map<String, dynamic>> _companies = [];
  String? _selectedCompanyId;
  String _searchQuery = '';
  String? _selectedCompanyName;

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
    _checkApplicationStatus();
    print('LoginPageState initState'); // Debug print
  }

  Future<void> _fetchCompanies() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await supabase
          .from('companies')
          .select('id, name, url, anon_key')
          .order('name');
      if (response is List) {
        setState(() {
          _companies = List<Map<String, dynamic>>.from(response);
          print(
              "Companies fetched successfully: ${_companies.length} companies"); // Debug print
          if (_companies.isNotEmpty) {
            print(
                "First company name: ${_companies.first['name']}"); // Debug print first company name
          }
        });
      } else {
        _logger.e('Unexpected response format fetching companies: $response');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Kompaniyalarni yuklashda xatolik yuz berdi (kutilmagan format)'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (error) {
      _logger.e('Kompaniyalarni yuklashda kutilmagan xatolik: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Kompaniyalarni yuklashda kutilmagan xatolik yuz berdi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedCompanyId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kompaniyani tanlang'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      print(
          "Attempting to sign in with company ID: $_selectedCompanyId"); // Debug print
      if (_companies.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Kompaniyalar yuklanmadi. Iltimos, dasturni qayta ishga tushiring.'), // User-friendly message
              backgroundColor: Colors.red,
            ),
          );
        }
        return; // Exit signIn if companies are empty
      }

      print(
          "Selected Company ID before firstWhere: $_selectedCompanyId"); // Debug print
      print("Companies list before firstWhere: $_companies"); // Debug print

      final selectedCompany = _companies.firstWhere((company) =>
          company['id'].toString() ==
          _selectedCompanyId); // Ensure comparison is with String

      final companyUrl = selectedCompany['url'] as String?;
      final companyAnonKey = selectedCompany['anon_key'] as String?;

      if (companyUrl == null || companyAnonKey == null) {
        throw Exception('Kompaniya URL yoki kaliti topilmadi');
      }

      print("Company URL: $companyUrl"); // Debug print
      print("Company Anon Key: $companyAnonKey"); // Debug print

      final newSupabaseClient = SupabaseClient(companyUrl, companyAnonKey);
      print("SupabaseClient initialized: $newSupabaseClient"); // Debug print

      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      print("Attempting signInWithPassword with email: $email"); // Debug print
      final response = await newSupabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      print("signInWithPassword response: $response"); // Debug print

      if (response.session != null) {
        await newSupabaseClient.from('login_activities').insert({
          'user_id': response.user!.id,
          'login_time': DateTime.now().toIso8601String(),
          'success': true,
        });
        _logger.i(
            'Foydalanuvchi tizimga kirdi: ${response.user!.id} kompaniya: ${selectedCompany['name']}');
        widget.onLoginSuccess(true);
        _checkApplicationStatus();
      }
    } on AuthException catch (error) {
      _logger.e('Kirish xatosi: ${error.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.red,
          ),
        );
      }

      final email = _emailController.text.trim();
      try {
        final selectedCompany = _companies.firstWhere((company) =>
            company['id'].toString() ==
            _selectedCompanyId); // Ensure comparison is with String
        final companyUrl = selectedCompany['url'] as String?;
        final companyAnonKey = selectedCompany['anon_key'] as String?;
        final newSupabaseClient = SupabaseClient(companyUrl!, companyAnonKey!);

        final user = await newSupabaseClient
            .from('users')
            .select('id')
            .eq('email', email)
            .maybeSingle();
        if (user != null) {
          await newSupabaseClient.from('login_activities').insert({
            'user_id': user['id'],
            'login_time': DateTime.now().toIso8601String(),
            'success': false,
          });
        }
      } catch (logError) {
        _logger.e('Login logini yozishda xatolik: $logError');
      }
    } on PostgrestException catch (error) {
      _logger.e('Kutilmagan xatolik: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Kutilmagan xatolik yuz berdi: ${error.message} - ${error.code}'), // Display code as well
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      _logger.e('Kutilmagan xatolik: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kutilmagan xatolik yuz berdi: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showRegistrationSheet(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return const RegistrationSheet();
      },
    );
  }

  Future<void> _checkApplicationStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminEmail = prefs.getString('adminEmail');

    if (adminEmail != null && adminEmail.isNotEmpty) {
      try {
        final request = await supabase
            .from('requests')
            .select('status')
            .eq('admin_email', adminEmail)
            .single();
        final status = request['status'] as String;

        if (mounted) {
          setState(() {
            if (status == 'pending') {
              _applicationStatusMessage =
                  'Sizning arizangiz ko\'rib chiqilmoqda... Biz tez orada sizga aloqaga chiqamiz.';
            } else if (status == 'active') {
              _applicationStatusMessage =
                  'Sizning arizangiz ko\'rib chiqildi. Agarda siz akkountlaringizni olmagan bo\'lsangiz:\nTelegram: @davomat_admin ga murojaat qiling.';
            } else if (status == 'rejected') {
              _applicationStatusMessage =
                  'Arizangiz qabul qilinmadi.Siz to\'lov qilmagansiz shekilli\nYordam uchun telegram: @davomat_admin';
            } else {
              _applicationStatusMessage = null;
              _logger.w('Unknown application status: $status');
            }
          });
        }
      } catch (e) {
        _logger.e('Error fetching application status: $e');
        if (mounted) {
          setState(() {
            _applicationStatusMessage = null;
          });
        }
      }
    }
  }

  List<Map<String, dynamic>> get _filteredCompanies {
    if (_searchQuery.isEmpty) {
      return _companies;
    }
    return _companies.where((company) {
      final companyName = company['name'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return companyName.contains(query);
    }).toList();
  }

  void _showCompanySelectionDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        String searchQuery = '';
        List<Map<String, dynamic>> filteredCompanies = _companies;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            void updateFilteredCompanies(String query) {
              setState(() {
                searchQuery = query;
                filteredCompanies = _companies.where((company) {
                  final companyName = company['name'].toString().toLowerCase();
                  final lowerQuery = searchQuery.toLowerCase();
                  return companyName.contains(lowerQuery);
                }).toList();
              });
            }

            return CupertinoAlertDialog(
              title: const Text('Kompaniyani tanlang'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  children: [
                    CupertinoSearchTextField(
                      placeholder: 'Kompaniya qidirish',
                      onChanged: updateFilteredCompanies,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 200, // Adjust height as needed
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredCompanies.length,
                        itemBuilder: (context, index) {
                          final company = filteredCompanies[index];
                          return CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              setState(() {
                                _selectedCompanyId = company['id'].toString();
                                _selectedCompanyName = company['name'];
                              });
                              print(
                                  "Selected Company ID: $_selectedCompanyId, Name: $_selectedCompanyName"); // Debug print when company is selected
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.secondarySystemFill,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(company['name'] as String),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: <CupertinoDialogAction>[
                CupertinoDialogAction(
                  child: const Text('Bekor qilish'),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor =
        isDarkMode ? CupertinoColors.white : CupertinoColors.black;

    return Scaffold(
      backgroundColor: isDarkMode
          ? CupertinoColors.systemGrey6.resolveFrom(context)
          : CupertinoColors.white,
      body: SuperScaffold(
        appBar: SuperAppBar(
          title: const Text('Davomat Dasturi'),
          largeTitle: SuperLargeTitle(
            enabled: true,
            largeTitle: "Tizimga Kirish",
          ),
          searchBar: SuperSearchBar(enabled: false),
          backgroundColor: isDarkMode
              ? CupertinoColors.systemGrey6.resolveFrom(context)
              : CupertinoColors.white,
          border: const Border(
            bottom: BorderSide(
              color: CupertinoColors.systemGrey4,
              width: 0.0,
            ),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CupertinoButton(
                        onPressed: _isLoading
                            ? null
                            : () => _showCompanySelectionDialog(context),
                        child: Text(
                          _selectedCompanyName ?? 'Kompaniyani tanlang',
                          style: TextStyle(color: CupertinoColors.activeBlue),
                        ),
                      ),
                      if (_selectedCompanyName != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Tanlangan kompaniya: $_selectedCompanyName',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.secondaryLabel),
                        ),
                      ],
                      if (_companies.isEmpty && !_isLoading) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Text(
                            "Kompaniyalar topilmadi. Iltimos, keyinroq urinib ko'ring.",
                            textAlign: TextAlign.center,
                          ),
                        )
                      ],
                      if (_isLoading) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: CupertinoActivityIndicator(),
                        )
                      ],
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: CupertinoColors.secondarySystemFill,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: CupertinoTextFormFieldRow(
                            prefix: const Icon(CupertinoIcons.mail_solid),
                            placeholder: 'Email',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              print(
                                  'Email Validator value: $value'); // Debug Print
                              if (value == null || value.isEmpty) {
                                return 'Emailni kiriting';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: CupertinoColors.secondarySystemFill,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: CupertinoTextFormFieldRow(
                            obscureText: true,
                            prefix: const Icon(CupertinoIcons.padlock_solid),
                            placeholder: 'Parol',
                            controller: _passwordController,
                            validator: (value) {
                              print(
                                  'Password Validator value: $value'); // Debug Print
                              if (value == null || value.isEmpty) {
                                return 'Parolni kiriting';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      CupertinoButton.filled(
                        onPressed: _isLoading ? null : _signIn,
                        child: _isLoading
                            ? const CupertinoActivityIndicator()
                            : const Text('Kirish'),
                      ),
                      const SizedBox(height: 12),
                      CupertinoButton(
                        child: const Text('Hisobingiz yo\'qmi?'),
                        onPressed: () => _showRegistrationSheet(context),
                      ),
                      if (_applicationStatusMessage != null) ...[
                        const SizedBox(height: 24),
                        Text(
                          _applicationStatusMessage!,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        if (_applicationStatusMessage ==
                            'Arizangiz qabul qilinmadi.') ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Agar sizga aloqaga chiqilmagan bo\'lsa, telegramdan aloqaga chiqing: @davomat_admin',
                            style: TextStyle(
                                fontSize: 14, color: CupertinoColors.systemRed),
                            textAlign: TextAlign.center,
                          ),
                        ]
                      ],
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegistrationSheet extends StatefulWidget {
  const RegistrationSheet({super.key});

  @override
  _RegistrationSheetState createState() => _RegistrationSheetState();
}

class _RegistrationSheetState extends State<RegistrationSheet> {
  final _regFormKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _employeesCountController = TextEditingController();
  final _workingHoursStartController = TextEditingController();
  final _workingHoursEndController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  bool _regIsLoading = false;
  final _logger = Logger();

  final List<String> _employeePositions = [];
  final _positionController = TextEditingController();

  String? _filePath;
  String? _fileUrl;
  String? _fileName;
  Uint8List? _fileBytes;

  @override
  void initState() {
    super.initState();
    print('RegistrationSheetState initState'); // Debug print
  }

  void _addPosition() {
    final position = _positionController.text.trim();
    if (position.isNotEmpty) {
      setState(() {
        _employeePositions.add(position);
        _positionController.clear();
      });
    }
  }

  void _removePosition(int index) {
    setState(() {
      _employeePositions.removeAt(index);
    });
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: kIsWeb ? true : false,
      withReadStream: !kIsWeb,
    );

    if (result != null) {
      setState(() {
        _fileName = result.files.single.name;
        if (kIsWeb) {
          _fileBytes = result.files.single.bytes;
          _filePath = 'web_file';
        } else {
          _filePath = result.files.single.path!;
          _fileBytes = null;
        }
      });
    }
  }

  Future<String?> _uploadFile() async {
    if (_fileName == null) {
      return null;
    }

    final fileName = _fileName!;
    final fileExt = fileName.split('.').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'uploads/$timestamp-$fileName';
    String contentType = 'application/octet-stream';

    switch (fileExt.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        contentType = 'image/jpeg';
        break;
      case 'png':
        contentType = 'image/png';
        break;
      case 'pdf':
        contentType = 'application/pdf';
        break;
    }

    try {
      if (kIsWeb) {
        if (_fileBytes == null) {
          _logger.e('Webda fayl baytlari null');
          return null;
        }
        await supabase.storage.from('company_docs').uploadBinary(
              storagePath,
              _fileBytes!,
              fileOptions: FileOptions(contentType: contentType),
            );
      } else {
        if (_filePath == null) {
          _logger.e('Mobil qurilmada fayl yo\'li null');
          return null;
        }
        final file = File(_filePath!);
        await supabase.storage.from('company_docs').upload(
              storagePath,
              file,
              fileOptions: FileOptions(contentType: contentType),
            );
      }

      final response =
          supabase.storage.from('company_docs').getPublicUrl(storagePath);
      return response;
    } catch (error) {
      _logger.e('Faylni yuklashda xatolik: $error');
      return null;
    }
  }

  Future<void> _applyForAccount(BuildContext context) async {
    if (!_regFormKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _regIsLoading = true;
    });

    final adminEmail = _adminEmailController.text.trim();
    final phoneNumber =
        '+998${_phoneNumberController.text.replaceAll(RegExp(r'[^0-9]'), '')}';

    final existingEmail = await supabase
        .from('requests')
        .select()
        .eq('admin_email', adminEmail)
        .maybeSingle();

    if (existingEmail != null) {
      Navigator.of(context).pop();
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Xatolik'),
            content: const Text('Ushbu email allaqachon ro\'yxatdan o\'tgan.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
      setState(() {
        _regIsLoading = false;
      });
      return;
    }

    final existingPhone = await supabase
        .from('requests')
        .select()
        .eq('phone', phoneNumber)
        .maybeSingle();

    if (existingPhone != null) {
      Navigator.of(context).pop();
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Xatolik'),
            content: const Text(
                'Ushbu telefon raqami allaqachon ro\'yxatdan o\'tgan.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
      setState(() {
        _regIsLoading = false;
      });
      return;
    }

    String? fileUrl;
    if (_fileName != null) {
      fileUrl = await _uploadFile();
      if (fileUrl == null) {
        Navigator.of(context).pop();
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Xatolik'),
              content: const Text("Faylni yuklashda xatolik yuz berdi."),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        }

        setState(() => _regIsLoading = false);
        return;
      }
    }

    try {
      final positionsString = _employeePositions.join(', ');
      final phone = phoneNumber;

      int? employeeCount = int.tryParse(_employeesCountController.text);
      if (employeeCount == null) {
        Navigator.of(context).pop();
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Xatolik'),
              content:
                  const Text('Xodimlar soni maydoniga faqat raqam kiriting.'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        }

        setState(() {
          _regIsLoading = false;
        });
        return;
      }

      await supabase.from('requests').insert({
        'company_name': _companyNameController.text,
        'employees_count': employeeCount,
        'employee_positions': positionsString,
        'working_hours':
            '${_workingHoursStartController.text} - ${_workingHoursEndController.text}',
        'admin_email': adminEmail,
        'admin_password': _adminPasswordController.text,
        'phone': phone,
        'request_time': DateTime.now().toIso8601String(),
        'status': 'pending',
        'payment_check_url': fileUrl,
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('adminEmail', adminEmail);

      Navigator.of(context).pop();

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Muvaffaqiyatli'),
            content: const Text('Ariza berildi, kuting...'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      _logger.e('Ariza berishda xatolik: $error');
      Navigator.of(context).pop();
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Xatolik'),
            content:
                Text('Ariza berishda xatolik yuz berdi: ${error.toString()}'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _regIsLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor =
        isDarkMode ? CupertinoColors.white : CupertinoColors.black;

    return CupertinoAlertDialog(
      title: const Text('Hisob yaratish uchun ariza'),
      content: SingleChildScrollView(
        child: Material(
          type: MaterialType.transparency,
          child: Form(
            key: _regFormKey,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CupertinoTextFormFieldRow(
                      prefix: const Icon(CupertinoIcons.building_2_fill),
                      placeholder: 'Kompaniya nomini kiriting',
                      controller: _companyNameController,
                      style: TextStyle(color: textColor),
                      placeholderStyle: theme.textTheme.textStyle
                          .copyWith(color: CupertinoColors.placeholderText),
                      validator: (value) {
                        print(
                            'Company Name Validator value: $value'); // Debug Print
                        if (value == null || value.isEmpty) {
                          return 'Kompaniya nomini kiriting';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CupertinoTextFormFieldRow(
                      prefix: const Icon(CupertinoIcons.person_2_fill),
                      placeholder: 'Xodimlar sonini kiriting',
                      controller: _employeesCountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor),
                      placeholderStyle: theme.textTheme.textStyle
                          .copyWith(color: CupertinoColors.placeholderText),
                      validator: (value) {
                        print(
                            'Employees Count Validator value: $value'); // Debug Print
                        if (value == null || value.isEmpty) {
                          return 'Xodimlar sonini kiriting';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Raqam kiriting';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            controller: _positionController,
                            placeholder: 'Lavozim',
                            style: TextStyle(color: textColor),
                            placeholderStyle: theme.textTheme.textStyle
                                .copyWith(
                                    color: CupertinoColors.placeholderText),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                          ),
                        ),
                        CupertinoButton(
                          child: const Icon(CupertinoIcons.add),
                          onPressed: _addPosition,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    itemCount: _employeePositions.length,
                    itemBuilder: (context, index) {
                      return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Container(
                              decoration: BoxDecoration(
                                color: CupertinoColors.secondarySystemFill,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0),
                                      child: Text(
                                        _employeePositions[index],
                                        style: TextStyle(color: textColor),
                                      ),
                                    ),
                                  ),
                                  CupertinoButton(
                                    child: const Icon(CupertinoIcons.delete),
                                    onPressed: () => _removePosition(index),
                                  ),
                                ],
                              )));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoTextFormFieldRow(
                            prefix: const Icon(CupertinoIcons.clock_fill),
                            placeholder: '9:00',
                            controller: _workingHoursStartController,
                            keyboardType: TextInputType.text,
                            style: TextStyle(color: textColor),
                            placeholderStyle: theme.textTheme.textStyle
                                .copyWith(
                                    color: CupertinoColors.placeholderText),
                            inputFormatters: [
                              TextInputFormatter.withFunction(
                                  (oldValue, newValue) {
                                final newText = newValue.text;
                                if (newText.length <= 5) {
                                  return newValue;
                                } else {
                                  return oldValue;
                                }
                              })
                            ],
                            validator: (value) {
                              print(
                                  'Working Hours Start Validator value: $value'); // Debug Print
                              if (value == null || value.isEmpty) {
                                return 'Kelish vaqtini kiriting';
                              }
                              if (!RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$')
                                  .hasMatch(value)) {
                                return 'Soat formatini kiriting (HH:MM)';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(' - ', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CupertinoTextFormFieldRow(
                            placeholder: '18:00',
                            controller: _workingHoursEndController,
                            keyboardType: TextInputType.text,
                            style: TextStyle(color: textColor),
                            placeholderStyle: theme.textTheme.textStyle
                                .copyWith(
                                    color: CupertinoColors.placeholderText),
                            inputFormatters: [
                              TextInputFormatter.withFunction(
                                  (oldValue, newValue) {
                                final newText = newValue.text;
                                if (newText.length <= 5) {
                                  return newValue;
                                } else {
                                  return oldValue;
                                }
                              })
                            ],
                            validator: (value) {
                              print(
                                  'Working Hours End Validator value: $value'); // Debug Print
                              if (value == null || value.isEmpty) {
                                return 'Ketish vaqtini kiriting';
                              }
                              if (!RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$')
                                  .hasMatch(value)) {
                                return 'Soat formatini kiriting (HH:MM)';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CupertinoTextFormFieldRow(
                      prefix: const Icon(CupertinoIcons.mail_solid),
                      placeholder: 'Admin Email',
                      controller: _adminEmailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: textColor),
                      placeholderStyle: theme.textTheme.textStyle
                          .copyWith(color: CupertinoColors.placeholderText),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      validator: (value) {
                        print(
                            'Admin Email Validator value: $value'); // Debug Print
                        if (value == null || value.isEmpty) {
                          return 'Emailni kiriting';
                        }
                        if (!value.contains('@')) {
                          return 'Noto\'g\'ri email format';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CupertinoTextFormFieldRow(
                      obscureText: true,
                      prefix: const Icon(CupertinoIcons.padlock_solid),
                      placeholder: 'Admin Parol',
                      controller: _adminPasswordController,
                      style: TextStyle(color: textColor),
                      placeholderStyle: theme.textTheme.textStyle
                          .copyWith(color: CupertinoColors.placeholderText),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      validator: (value) {
                        print(
                            'Admin Password Validator value: $value'); // Debug Print
                        if (value == null || value.isEmpty) {
                          return 'Parolni kiriting';
                        }
                        if (value.length < 6) {
                          return 'Parol kamida 6 ta belgidan iborat bo\'lishi kerak';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.secondarySystemFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CupertinoTextFormFieldRow(
                      prefix: const Icon(CupertinoIcons.phone_solid),
                      placeholder: 'Telegram raqam: 991239909',
                      controller: _phoneNumberController,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(color: textColor),
                      placeholderStyle: theme.textTheme.textStyle
                          .copyWith(color: CupertinoColors.placeholderText),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                        LengthLimitingTextInputFormatter(9),
                      ],
                      validator: (value) {
                        print(
                            'Phone Number Validator value: $value'); // Debug Print
                        if (value == null || value.isEmpty) {
                          return 'Telegram Telefon raqamini kiriting';
                        }
                        if (value.length != 9) {
                          return '9 ta raqam kiriting';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Bir martalik to\'lov: 100,000 so\'m',
                    style: TextStyle(color: CupertinoColors.activeGreen)),
                const Text("To'lov qilish uchun karta:",
                    style: TextStyle(color: CupertinoColors.activeBlue)),
                const Text(
                    "8600 0000 9000 8000 - Pardayev.M\n\nTo'lov qilib bo'lganingizdan so'ng, sizga Davomat dasturi ulab beriladi",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                CupertinoButton(
                  child: const Text('To\'lov Chekni joylash'),
                  onPressed: _pickFile,
                ),
                if (_fileName != null) ...[
                  const SizedBox(height: 8),
                  Text('Tanlangan fayl: $_fileName'),
                ],
                const SizedBox(height: 12),
                CupertinoButton.filled(
                  onPressed:
                      _regIsLoading ? null : () => _applyForAccount(context),
                  child: _regIsLoading
                      ? const CupertinoActivityIndicator()
                      : const Text('Ariza berish'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <CupertinoDialogAction>[
        CupertinoDialogAction(
          child: const Text('Bekor qilish'),
          isDestructiveAction: true,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

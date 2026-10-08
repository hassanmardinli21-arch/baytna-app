import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as audio;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const BaytnaApp());
}

class BaytnaApp extends StatelessWidget {
  const BaytnaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'تطبيق بيتنا',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const BaytnaHomeScreen(),
    );
  }
}

class BaytnaHomeScreen extends StatefulWidget {
  const BaytnaHomeScreen({Key? key}) : super(key: key);

  @override
  _BaytnaHomeScreenState createState() => _BaytnaHomeScreenState();
}

class _BaytnaHomeScreenState extends State<BaytnaHomeScreen> {
  final audio.AudioPlayer _audioPlayer = audio.AudioPlayer();
  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _currentUser;
  bool _authLoading = true;

  final CollectionReference _shoppingRef =
      FirebaseFirestore.instance.collection('shopping_items');

  @override
  void initState() {
    super.initState();
    _currentUser = _auth.currentUser;
    _auth.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _authLoading = false;
        });
      }
    });
  }

  Future<void> _playBellSound() async {
    try {
      await _audioPlayer.stop();
      audio.Source urlSource = audio.AssetSource('sounds/bell.wav');
      await _audioPlayer.play(urlSource);
    } catch (e) {
      debugPrint("خطأ في الصوت: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  // ================= Authentication =================

  Future<void> _showLoginDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    bool isRegisterMode = false;
    bool isBusy = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final email = emailController.text.trim();
              final password = passwordController.text;

              if (email.isEmpty || password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى إدخال البريد الإلكتروني وكلمة المرور'),
                  ),
                );
                return;
              }

              if (password.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
                  ),
                );
                return;
              }

              setDialogState(() => isBusy = true);

              try {
                if (isRegisterMode) {
                  await _auth.createUserWithEmailAndPassword(
                    email: email,
                    password: password,
                  );
                } else {
                  await _auth.signInWithEmailAndPassword(
                    email: email,
                    password: password,
                  );
                }

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isRegisterMode
                            ? '✅ تم إنشاء الحساب وتسجيل الدخول'
                            : '✅ تم تسجيل الدخول بنجاح',
                      ),
                    ),
                  );
                }
              } on FirebaseAuthException catch (e) {
                String message;
                switch (e.code) {
                  case 'invalid-email':
                    message = 'البريد الإلكتروني غير صالح';
                    break;
                  case 'user-not-found':
                  case 'wrong-password':
                  case 'invalid-credential':
                    message = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
                    break;
                  case 'email-already-in-use':
                    message = 'هذا البريد الإلكتروني مستخدم مسبقًا';
                    break;
                  case 'weak-password':
                    message = 'كلمة المرور ضعيفة، استخدم 6 أحرف على الأقل';
                    break;
                  case 'network-request-failed':
                    message = 'تعذر الاتصال بالإنترنت';
                    break;
                  case 'too-many-requests':
                    message = 'محاولات كثيرة، يرجى المحاولة لاحقًا';
                    break;
                  default:
                    message = 'حدث خطأ أثناء المصادقة: ${e.message ?? e.code}';
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ $message')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('❌ حدث خطأ: $e')),
                  );
                }
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => isBusy = false);
                }
              }
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      isRegisterMode ? Icons.person_add : Icons.login,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 10),
                    Text(isRegisterMode ? 'إنشاء حساب جديد' : 'تسجيل الدخول'),
                  ],
                ),
                content: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setDialogState(
                                () => obscurePassword = !obscurePassword,
                              );
                            },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: isBusy
                              ? null
                              : () {
                                  setDialogState(
                                    () => isRegisterMode = !isRegisterMode,
                                  );
                                },
                          child: Text(
                            isRegisterMode
                                ? 'لدي حساب بالفعل — تسجيل الدخول'
                                : 'ليس لدي حساب — إنشاء حساب',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        isBusy ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isBusy ? null : submit,
                    icon: isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isRegisterMode ? Icons.person_add : Icons.login,
                          ),
                    label: Text(isRegisterMode ? 'إنشاء الحساب' : 'دخول'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🚪 تم تسجيل الخروج')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ تعذر تسجيل الخروج: $e')),
        );
      }
    }
  }

  void _showAccountMenu() {
    if (_currentUser == null) {
      _showLoginDialog();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.blue[700],
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'الحساب الحالي',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentUser?.email ?? '',
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _signOut();
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('تسجيل الخروج'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ================= Shopping List =================

  void _addItem() {
    final titleController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة مادة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'اسم المادة والكمية',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'السعر (اختياري)',
                    prefixIcon: Icon(Icons.attach_money),
                    hintText: 'مثال: 25.50',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  final priceText = priceController.text.trim();
                  final double? price =
                      priceText.isEmpty ? null : double.tryParse(priceText);
                  await _shoppingRef.add({
                    'title': titleController.text,
                    'price': price,
                    'addedBy': _currentUser?.email ?? 'أنت',
                    'editedBy': _currentUser?.email ?? 'أنت',
                    'isChecked': false,
                    'isPinned': false,
                    'isBlocked': false,
                    'imagePath': null,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _editItem(String docId, String currentTitle, double? currentPrice) {
    final titleController = TextEditingController(text: currentTitle);
    final priceController = TextEditingController(
      text: currentPrice != null ? currentPrice.toString() : '',
    );

    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل المادة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'اسم المادة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'السعر',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty) {
                  final priceText = priceController.text.trim();
                  final double? price =
                      priceText.isEmpty ? null : double.tryParse(priceText);
                  await _shoppingRef.doc(docId).update({
                    'title': titleController.text,
                    'price': price,
                    'editedBy': _currentUser?.email ?? 'أنت',
                  });
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteItem(String docId) async {
    await _shoppingRef.doc(docId).delete();
  }

  Future<void> _toggleField(
      String docId, String field, bool currentValue) async {
    await _shoppingRef.doc(docId).update({field: !currentValue});
  }

  Future<void> _pickImage(String docId, String? currentImagePath) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Wrap(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'إضافة صورة للمادة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt,
                      color: Colors.blue, size: 30),
                  title: const Text('التقاط صورة بالكاميرا'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _getImage(ImageSource.camera, docId);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library,
                      color: Colors.green, size: 30),
                  title: const Text('اختيار صورة من المعرض'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _getImage(ImageSource.gallery, docId);
                  },
                ),
                if (currentImagePath != null)
                  ListTile(
                    leading:
                        const Icon(Icons.delete, color: Colors.red, size: 30),
                    title: const Text('حذف الصورة الحالية'),
                    onTap: () async {
                      await _shoppingRef
                          .doc(docId)
                          .update({'imagePath': null});
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source, String docId) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 50,
        maxWidth: 800,
      );

      if (pickedFile != null) {
        await _shoppingRef.doc(docId).update({
          'imagePath': pickedFile.path,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم إضافة الصورة')),
          );
        }
      }
    } catch (e) {
      debugPrint("خطأ: $e");
    }
  }

  void _showFullImage(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(imagePath), fit: BoxFit.contain),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: const Text('إغلاق'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('قائمة المشتريات المشتركة - بيتنا'),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            if (_authLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: TextButton.icon(
                  onPressed: _showAccountMenu,
                  icon: Icon(
                    _currentUser == null ? Icons.login : Icons.account_circle,
                    color: Colors.blue[700],
                  ),
                  label: Text(
                    _currentUser == null ? 'تسجيل الدخول' : 'حسابي',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 28),
                  label: const Text(
                    'إضافة مادة جديدة للقائمة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_currentUser != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified_user,
                        size: 18,
                        color: Colors.green[700],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'مسجل الدخول: ${_currentUser!.email ?? ''}',
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),

              // ============ لوحة إجمالي المشتريات ============
              StreamBuilder<QuerySnapshot>(
                stream: _shoppingRef.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  double totalAll = 0;
                  double totalActive = 0;
                  double totalBlocked = 0;
                  int activeCount = 0;
                  int blockedCount = 0;

                  for (final doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final price = data['price'];
                    final isBlocked = data['isBlocked'] ?? false;
                    final priceValue = (price is num) ? price.toDouble() : 0.0;

                    if (isBlocked) {
                      totalBlocked += priceValue;
                      blockedCount++;
                    } else {
                      totalActive += priceValue;
                      activeCount++;
                    }
                    totalAll += priceValue;
                  }

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.calculate,
                                    color: Colors.white, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'إجمالي المشتريات',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${totalAll.toStringAsFixed(2)} \$',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Divider(color: Colors.white54, height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'النشطة ($activeCount)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${totalActive.toStringAsFixed(2)} \$',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (blockedCount > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.block,
                                      color: Colors.white70, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'الملغاة ($blockedCount)',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${totalBlocked.toStringAsFixed(2)} \$',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              // ============ قائمة المشتريات ============
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _shoppingRef
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'خطأ في الاتصال: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('القائمة فارغة، أضف بعض المشتريات!'),
                      );
                    }

                    final docs = snapshot.data!.docs.toList();

                    // ✅ الترتيب: النشطة أولاً (المثبتة قبل غيرها)، ثم الملغاة في الأسفل
                    docs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aBlocked = aData['isBlocked'] ?? false;
                      final bBlocked = bData['isBlocked'] ?? false;

                      // الملغاة في الأسفل دائماً
                      if (aBlocked != bBlocked) return aBlocked ? 1 : -1;

                      // المثبتة في الأعلى (فقط للنشطة)
                      final aPinned = aData['isPinned'] ?? false;
                      final bPinned = bData['isPinned'] ?? false;
                      if (aPinned != bPinned) return aPinned ? -1 : 1;

                      return 0;
                    });

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildShoppingItem(doc.id, data);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShoppingItem(String docId, Map<String, dynamic> item) {
    final bool isChecked = item['isChecked'] ?? false;
    final bool isPinned = item['isPinned'] ?? false;
    final bool isBlocked = item['isBlocked'] ?? false;
    final String? imagePath = item['imagePath'];
    final double? price = (item['price'] is num)
        ? (item['price'] as num).toDouble()
        : null;

    // ✅ ألوان مخصصة: تظليل داكن للملغاة
    final Color cardColor = isBlocked
        ? const Color(0xFF2C2C2C)
        : (isPinned ? const Color(0xFFFFF9E6) : Colors.white);

    final Color titleColor = isBlocked ? Colors.white70 : Colors.black;
    final Color infoColor = isBlocked ? Colors.white54 : Colors.black87;
    final Color subInfoColor = isBlocked ? Colors.white38 : Colors.grey[700]!;
    final Color borderColor =
        isBlocked ? Colors.red[900]! : Colors.grey.shade300;

    return Card(
      elevation: isBlocked ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderColor,
          width: isBlocked ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: isChecked,
                  onChanged: (val) =>
                      _toggleField(docId, 'isChecked', isChecked),
                  activeColor: isBlocked ? Colors.red : Colors.purple,
                  checkColor: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // اسم المادة
                      Text(
                        item['title'] ?? '',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration:
                              isBlocked ? TextDecoration.lineThrough : null,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // ✅ السعر بجانب المادة
                      if (price != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isBlocked
                                ? Colors.red[900]!.withOpacity(0.4)
                                : Colors.green[100],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isBlocked
                                  ? Colors.red[700]!
                                  : Colors.green[700]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.attach_money,
                                size: 16,
                                color: isBlocked
                                    ? Colors.white70
                                    : Colors.green[800],
                              ),
                              const SizedBox(width: 2),
                              Text(
                                price.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isBlocked
                                      ? Colors.white
                                      : Colors.green[900],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (imagePath != null && File(imagePath).existsSync())
                  GestureDetector(
                    onTap: () => _showFullImage(imagePath),
                    child: Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isBlocked ? Colors.red[700]! : Colors.grey.shade300,
                          width: isBlocked ? 2 : 1,
                        ),
                        image: DecorationImage(
                          image: FileImage(File(imagePath)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 48.0, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'أضافها: ${item['addedBy'] ?? ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: infoColor,
                    ),
                  ),
                  Text(
                    'عدل عليها: ${item['editedBy'] ?? ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isBlocked
                          ? Colors.white38
                          : Colors.orange[800],
                    ),
                  ),
                  if (isBlocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.block,
                              size: 14, color: Colors.red[300]),
                          const SizedBox(width: 4),
                          Text(
                            'ملغاة',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.red[300],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionIcon(
                  Icons.delete_outline,
                  isBlocked ? Colors.white60 : Colors.blueGrey,
                  () => _deleteItem(docId),
                ),
                _buildActionIcon(
                  Icons.edit,
                  isBlocked ? Colors.amber[300]! : Colors.amber,
                  () => _editItem(docId, item['title'] ?? '', price),
                ),
                _buildActionIcon(
                  Icons.block,
                  isBlocked ? Colors.red[300]! : Colors.grey,
                  () => _toggleField(docId, 'isBlocked', isBlocked),
                ),
                _buildActionIcon(
                  Icons.push_pin,
                  isPinned
                      ? (isBlocked ? Colors.red[300]! : Colors.red)
                      : (isBlocked ? Colors.white38 : Colors.grey),
                  () => _toggleField(docId, 'isPinned', isPinned),
                ),
                _buildActionIcon(
                  Icons.volume_up,
                  isBlocked ? Colors.white60 : Colors.blueGrey,
                  _playBellSound,
                ),
                _buildActionIcon(
                  Icons.add_a_photo,
                  imagePath == null
                      ? (isBlocked ? Colors.green[300]! : Colors.green)
                      : (isBlocked ? Colors.blue[300]! : Colors.blue),
                  () => _pickImage(docId, imagePath),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon, color: color, size: 24),
      onPressed: onPressed,
      splashRadius: 20,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}
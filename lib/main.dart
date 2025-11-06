// main.dart - full working file (Firebase + Auth + Drawer + Pages)

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

/// ------------------------
/// MODEL
/// ------------------------
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String mobileNumber;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.mobileNumber,
  });

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      mobileNumber: data['mobileNumber'] ?? '',
    );
  }
}

/// ------------------------
/// MAIN
/// ------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const GuessingGameApp());
}

/// ------------------------
/// APP ROOT
/// ------------------------
class GuessingGameApp extends StatefulWidget {
  const GuessingGameApp({super.key});

  @override
  State<GuessingGameApp> createState() => _GuessingGameAppState();
}

class _GuessingGameAppState extends State<GuessingGameApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _changeTheme(ThemeMode themeMode) {
    setState(() => _themeMode = themeMode);
  }

  ThemeData _buildTheme(Brightness brightness) {
    bool isDark = brightness == Brightness.dark;
    var base = ThemeData(brightness: brightness, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F7),
      primaryColor: Colors.blueAccent,
      appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: isDark ? Colors.white : Colors.black87),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guessing Game',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnap) {
          if (authSnap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (authSnap.hasData) {
            return FutureBuilder<AppUser>(
              future: _fetchUserData(authSnap.data!),
              builder: (context, userSnap) {
                if (userSnap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
                if (userSnap.hasError || !userSnap.hasData) return const Scaffold(body: Center(child: Text('Error loading user data')));
                return GameHomeScreen(
                  user: userSnap.data!,
                  onLogout: () async => await FirebaseAuth.instance.signOut(),
                  themeMode: _themeMode,
                  onThemeChanged: _changeTheme,
                );
              },
            );
          }
          return const AuthPage();
        },
      ),
    );
  }

  Future<AppUser> _fetchUserData(User firebaseUser) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(firebaseUser.uid).get();
    return AppUser.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
  }
}

/// ------------------------
/// AUTH PAGE
/// ------------------------
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _loginIdentifierCtrl = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        String loginId = _loginIdentifierCtrl.text.trim();
        String password = _passCtrl.text.trim();
        String email = loginId;

        if (!loginId.contains('@')) {
          final q = await FirebaseFirestore.instance.collection('users').where('mobileNumber', isEqualTo: loginId).limit(1).get();
          if (q.docs.isNotEmpty) {
            email = q.docs.first.data()['email'];
          } else {
            throw FirebaseAuthException(code: 'user-not-found', message: 'No user with this mobile');
          }
        }
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      } else {
        final email = _emailCtrl.text.trim();
        final password = _passCtrl.text.trim();
        final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
        if (userCred.user != null) {
          await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
            'name': _nameCtrl.text.trim(),
            'email': email,
            'mobileNumber': _mobileCtrl.text.trim(),
            'score': 0,
            'created_at': DateTime.now(),
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Auth error'), backgroundColor: Colors.red));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blueAccent, Colors.lightBlue.shade200], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Form(
              key: _formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lightbulb_outline, size: 80, color: Colors.white),
                const SizedBox(height: 18),
                Text('Guessing Game', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_isLogin ? 'Login to start playing' : 'Create your account', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 24),

                if (_isLogin) ...[
                  TextFormField(controller: _loginIdentifierCtrl, decoration: const InputDecoration(labelText: 'Email or Mobile', prefixIcon: Icon(Icons.person_outline)), validator: (v) => v == null || v.isEmpty ? 'Enter email or mobile' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)), validator: (v) => v != null && v.length < 6 ? 'Min 6 chars' : null),
                ] else ...[
                  TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)), validator: (v) => v == null || v.isEmpty ? 'Enter name' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress, validator: (v) => v == null || !v.contains('@') ? 'Enter valid email' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _mobileCtrl, decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone_outlined)), keyboardType: TextInputType.phone, validator: (v) => v == null || v.length < 10 ? 'Enter valid number' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline)), validator: (v) => v != null && v.length < 6 ? 'Min 6 chars' : null),
                ],

                const SizedBox(height: 20),
                if (_isLoading) const CircularProgressIndicator(color: Colors.white) else SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blueAccent), child: Text(_isLogin ? 'Login' : 'Sign Up')),
                ),
                TextButton(onPressed: () => setState(() { _isLogin = !_isLogin; }), child: Text(_isLogin ? "Don't have an account? Sign Up" : 'Already have an account? Login', style: const TextStyle(color: Colors.white70))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// ------------------------
/// UI HELPERS: GameCard
/// ------------------------
class GameCard extends StatelessWidget {
  final Color? color;
  final Widget? child;
  final VoidCallback? onTap;
  const GameCard({super.key, this.color, this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        color: color ?? Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Center(child: child),
      ),
    );
  }
}

/// ------------------------
/// GAME PAGES (defined BEFORE GameHomeScreen to avoid ordering issues)
/// ------------------------
class ColorGuessPage extends StatefulWidget {
  final Function(int) onScore;
  const ColorGuessPage({super.key, required this.onScore});

  @override
  State<ColorGuessPage> createState() => _ColorGuessPageState();
}

class _ColorGuessPageState extends State<ColorGuessPage> {
  final _random = Random();
  final Map<String, Color> _colors = {
    'Red': Colors.red,
    'Green': Colors.green,
    'Blue': Colors.blue,
    'Yellow': Colors.yellow,
    'Orange': Colors.orange,
    'Purple': Colors.purple,
    'Pink': Colors.pink,
    'Brown': Colors.brown,
  };

  late String _targetName;
  late List<Color> _options;
  bool _isMixed = false;
  bool _reveal = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    final names = _colors.keys.toList()..shuffle();
    final selected = names.take(4).toList();
    _targetName = selected[_random.nextInt(selected.length)];
    _options = selected.map((n) => _colors[n]!).toList();
    _isMixed = false;
    _reveal = false;
    setState(() {});
  }

  void _mix() => setState(() => _isMixed = true);

  void _handle(Color c) {
    if (_reveal) return;
    bool ok = c == _colors[_targetName];
    if (ok) widget.onScore(1);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Correct!' : 'Wrong!'), backgroundColor: ok ? Colors.green : Colors.red, duration: const Duration(seconds: 1)));
    _reveal = true;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 900), _generate);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 10),
        Text(_isMixed ? 'Find: $_targetName' : 'Remember the colors and press MIX', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 18, crossAxisSpacing: 18),
            itemCount: 4,
            itemBuilder: (ctx, i) {
              final color = _options[i];
              final show = !_isMixed || _reveal;
              return GameCard(
                color: show ? color : null,
                child: show ? null : const Icon(Icons.question_mark_rounded, size: 44, color: Colors.grey),
                onTap: _isMixed ? () => _handle(color) : null,
              );
            },
          ),
        ),
        SizedBox(width: 180, child: ElevatedButton(onPressed: _isMixed ? _generate : _mix, child: Text(_isMixed ? 'NEW ROUND' : 'MIX'))),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class NumberGuessPage extends StatefulWidget {
  final Function(int) onScore;
  const NumberGuessPage({super.key, required this.onScore});

  @override
  State<NumberGuessPage> createState() => _NumberGuessPageState();
}

class _NumberGuessPageState extends State<NumberGuessPage> {
  final _random = Random();
  late int _target;
  late List<int> _options;
  bool _isMixed = false;
  bool _reveal = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    final set = <int>{};
    while (set.length < 4) set.add(_random.nextInt(50) + 1);
    _options = set.toList();
    _target = _options[_random.nextInt(4)];
    _isMixed = false;
    _reveal = false;
    setState(() {});
  }

  void _mix() => setState(() => _isMixed = true);

  void _guess(int n) {
    if (_reveal) return;
    bool ok = n == _target;
    if (ok) widget.onScore(1);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Correct!' : 'Wrong!'), backgroundColor: ok ? Colors.green : Colors.red, duration: const Duration(seconds: 1)));
    _reveal = true;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 900), _generate);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 10),
        Text(_isMixed ? 'Find: $_target' : 'Remember the numbers and press MIX', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 18, crossAxisSpacing: 18),
            itemCount: 4,
            itemBuilder: (ctx, i) => GameCard(
              child: _isMixed || _reveal ? Text('${_options[i]}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)) : const Icon(Icons.question_mark_rounded, size: 44, color: Colors.grey),
              onTap: _isMixed ? () => _guess(_options[i]) : null,
            ),
          ),
        ),
        SizedBox(width: 180, child: ElevatedButton(onPressed: _isMixed ? _generate : _mix, child: Text(_isMixed ? 'NEW ROUND' : 'MIX'))),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class AlphabetsGuessPage extends StatefulWidget {
  final Function(int) onScore;
  const AlphabetsGuessPage({super.key, required this.onScore});

  @override
  State<AlphabetsGuessPage> createState() => _AlphabetsGuessPageState();
}

class _AlphabetsGuessPageState extends State<AlphabetsGuessPage> {
  final _random = Random();
  final _letters = List.generate(26, (i) => String.fromCharCode(65 + i));
  late String _target;
  late List<String> _options;
  bool _isMixed = false;
  bool _reveal = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    _letters.shuffle();
    _options = _letters.take(4).toList();
    _target = _options[_random.nextInt(4)];
    _isMixed = false;
    _reveal = false;
    setState(() {});
  }

  void _mix() => setState(() => _isMixed = true);

  void _guess(String s) {
    if (_reveal) return;
    bool ok = s == _target;
    if (ok) widget.onScore(1);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'Correct!' : 'Wrong!'), backgroundColor: ok ? Colors.green : Colors.red, duration: const Duration(seconds: 1)));
    _reveal = true;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 900), _generate);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 10),
        Text(_isMixed ? 'Find: $_target' : 'Remember the letters and press MIX', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 18),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 18, crossAxisSpacing: 18),
            itemCount: 4,
            itemBuilder: (ctx, i) => GameCard(
              child: _isMixed || _reveal ? Text(_options[i], style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)) : const Icon(Icons.question_mark_rounded, size: 44, color: Colors.grey),
              onTap: _isMixed ? () => _guess(_options[i]) : null,
            ),
          ),
        ),
        SizedBox(width: 180, child: ElevatedButton(onPressed: _isMixed ? _generate : _mix, child: Text(_isMixed ? 'NEW ROUND' : 'MIX'))),
        const SizedBox(height: 12),
      ]),
    );
  }
}

class ScorePage extends StatelessWidget {
  final int score;
  const ScorePage({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Your Score: $score', style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: Colors.blueAccent)));
  }
}

/// ------------------------
/// GAME HOME (uses the pages defined above)
/// ------------------------
class GameHomeScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback onLogout;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const GameHomeScreen({super.key, required this.user, required this.onLogout, required this.themeMode, required this.onThemeChanged});

  @override
  State<GameHomeScreen> createState() => _GameHomeScreenState();
}

class _GameHomeScreenState extends State<GameHomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _fetchScore();
  }

  Future<void> _fetchScore() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).get();
      if (doc.exists) {
        setState(() => _score = doc.data()?['score'] ?? 0);
      } else {
        setState(() => _score = 0);
      }
    } catch (_) {
      setState(() => _score = 0);
    }
  }

  void _updateScore(int points) async {
    setState(() => _score += points);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({'score': _score});
    } catch (_) {
      // ignore failures here for simplicity
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ColorGuessPage(onScore: _updateScore),
      NumberGuessPage(onScore: _updateScore),
      AlphabetsGuessPage(onScore: _updateScore),
      ScorePage(score: _score),
    ];

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Guessing Game'),
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
        actions: [
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(user: widget.user, onLogout: widget.onLogout)))),
        ],
      ),
      drawer: AppDrawer(themeMode: widget.themeMode, onThemeChanged: widget.onThemeChanged),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.color_lens_outlined), label: 'Color Guess'),
          BottomNavigationBarItem(icon: Icon(Icons.format_list_numbered), label: 'Number Guess'),
          BottomNavigationBarItem(icon: Icon(Icons.abc_outlined), label: 'Alphabet Guess'),
          BottomNavigationBarItem(icon: Icon(Icons.score_outlined), label: 'Score'),
        ],
      ),
    );
  }
}

/// ------------------------
/// DRAWER & PROFILE
/// ------------------------
class AppDrawer extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  const AppDrawer({super.key, required this.themeMode, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    bool isDark = themeMode == ThemeMode.dark;
    return Drawer(
      child: SafeArea(
        child: Column(children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blueAccent),
            child: const Align(alignment: Alignment.bottomLeft, child: Text('Guessing Game Menu', style: TextStyle(color: Colors.white, fontSize: 20))),
          ),
          ListTile(leading: const Icon(Icons.settings), title: const Text('Account Settings'), onTap: () => Navigator.pop(context)),
          SwitchListTile(
            title: const Text('Dark Theme'),
            value: isDark,
            onChanged: (v) => onThemeChanged(v ? ThemeMode.dark : ThemeMode.light),
            secondary: Icon(isDark ? Icons.nightlight_round : Icons.wb_sunny_outlined),
          ),
          const Divider(),
          ListTile(leading: const Icon(Icons.share_outlined), title: const Text('Share App'), onTap: () => Navigator.pop(context)),
          ListTile(leading: const Icon(Icons.contact_mail_outlined), title: const Text('Developer Contact'), onTap: () {
            showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Developer Contact'), content: const Text('Ayush Thakur\nayushwork981@gmail.com'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
          }),
        ]),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  final AppUser user;
  final VoidCallback onLogout;
  const ProfilePage({super.key, required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
          const SizedBox(height: 16),
          Text(user.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(user.mobileNumber, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () {
            Navigator.pop(context);
            onLogout();
          }, child: const Text('Logout')),
        ]),
      ),
    );
  }
}

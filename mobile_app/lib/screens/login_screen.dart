import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../core/theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _showPassword = false;
  bool _isSignUp = false;
  bool _rememberMe = false;

  // Animation controllers for staggered entrance
  late final AnimationController _staggerController;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;

  // Logo bounce
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();

    // Staggered entrance — 5 items
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnims = List.generate(5, (i) {
      final start = i * 0.15;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _staggerController, curve: Interval(start, end, curve: Curves.easeOut)),
      );
    });

    _slideAnims = List.generate(5, (i) {
      final start = i * 0.15;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(parent: _staggerController, curve: Interval(start, end, curve: Curves.easeOutCubic)),
      );
    });

    // Logo scale bounce
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Start animations
    _logoController.forward();
    _staggerController.forward();

    // Load remembered credentials
    _loadRemembered();
  }

  void _loadRemembered() {
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        final email = box.get('remembered_email');
        final password = box.get('remembered_password');
        if (email != null && password != null) {
          _emailController.text = email;
          _passwordController.text = password;
          setState(() => _rememberMe = true);
        }
      }
    } catch (_) {}
  }

  void _saveRemembered() {
    try {
      if (Hive.isBoxOpen('settings')) {
        final box = Hive.box('settings');
        if (_rememberMe) {
          box.put('remembered_email', _emailController.text.trim());
          box.put('remembered_password', _passwordController.text);
        } else {
          box.delete('remembered_email');
          box.delete('remembered_password');
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _staggerController.dispose();
    _logoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Widget _animItem(int index, Widget child) {
    return SlideTransition(
      position: _slideAnims[index.clamp(0, 4)],
      child: FadeTransition(
        opacity: _fadeAnims[index.clamp(0, 4)],
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final lang = ref.watch(languageProvider);
    final tr = (String key) => S.t(key, lang);

    ref.listen<AuthState>(authProvider, (_, state) {
      if (state.isAuthenticated) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });

    return Directionality(
      textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Language toggle
                  _animItem(
                    0,
                    Align(
                      alignment: lang == 'ar' ? Alignment.topLeft : Alignment.topRight,
                      child: TextButton.icon(
                        onPressed: () => ref.read(languageProvider.notifier).toggle(),
                        icon: const Icon(Icons.language, size: 20),
                        label: Text(lang == 'ar' ? 'English' : 'العربية'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Animated logo
                  ScaleTransition(
                    scale: _logoScale,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.local_hospital, size: 36, color: Colors.white),
                          SizedBox(height: 2),
                          Icon(Icons.navigation, size: 18, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _animItem(
                    0,
                    Column(children: [
                      Text(
                        tr('app_title'),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('app_subtitle'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 28),

                  // Login/Signup toggle with animated switch
                  _animItem(
                    1,
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isSignUp = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isSignUp ? AppTheme.primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  tr('login'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: !_isSignUp ? Colors.white : Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _isSignUp = true),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isSignUp ? AppTheme.primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  tr('signup'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _isSignUp ? Colors.white : Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name field with animated appearance
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _isSignUp
                        ? _animItem(
                            2,
                            Column(children: [
                              TextField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  labelText: tr('full_name'),
                                  prefixIcon: const Icon(Icons.person_outlined),
                                ),
                              ),
                              const SizedBox(height: 14),
                            ]),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Email
                  _animItem(
                    2,
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: tr('email'),
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Password
                  _animItem(
                    3,
                    TextField(
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        labelText: tr('password'),
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                  ),

                  // Remember Me checkbox (login mode only)
                  if (!_isSignUp)
                    _animItem(
                      3,
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _rememberMe = !_rememberMe),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                  activeColor: AppTheme.primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tr('remember_me'),
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Error with animated appearance
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: authState.error != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              authState.error!,
                              style: const TextStyle(color: Colors.red, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 24),

                  // Login/Sign Up button
                  _animItem(
                    4,
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authState.isLoading
                            ? null
                            : () {
                                if (_isSignUp) {
                                  final name = _nameController.text.trim();
                                  final email = _emailController.text.trim();
                                  final pass = _passwordController.text;
                                  if (name.isEmpty || email.isEmpty || pass.length < 8) return;
                                  ref.read(authProvider.notifier).register(email, pass, name);
                                } else {
                                  _saveRemembered();
                                  ref.read(authProvider.notifier).login(
                                    _emailController.text.trim(),
                                    _passwordController.text,
                                  );
                                }
                              },
                        child: authState.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_isSignUp ? tr('signup') : tr('login')),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Demo user button
                  if (!_isSignUp)
                    _animItem(
                      4,
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => ref.read(authProvider.notifier).skipAuth(),
                          child: Text(tr('demo_user')),
                        ),
                      ),
                    ),

                  if (_isSignUp) ...[
                    const SizedBox(height: 8),
                    Text(
                      tr('signup_hint'),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/services/auth_service.dart';
import '../../widgets/common/app_logo.dart';
import '../../widgets/common/custom_text_field.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordCheckController = TextEditingController();

  bool emailChecked = false;
  bool isMovingNext = false;

  bool get isNameDone => nameController.text.trim().length >= 2;

  bool get isEmailDone {
    final email = emailController.text.trim();
    return RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email);
  }

  bool get isPasswordDone {
    final password = passwordController.text.trim();
    return RegExp(
      r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[!@#$%^&*(),.?":{}|<>]).{8,}$',
    ).hasMatch(password);
  }

  bool get isPasswordCheckDone {
    final password = passwordController.text.trim();
    final passwordCheck = passwordCheckController.text.trim();

    return passwordCheck.isNotEmpty && passwordCheck == password;
  }

  bool get showEmail => isNameDone;
  bool get showEmailCheckButton => showEmail && isEmailDone && !emailChecked;
  bool get showPassword => showEmail && isEmailDone && emailChecked;
  bool get showPasswordCheck => showPassword && isPasswordDone;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    passwordCheckController.dispose();
    super.dispose();
  }

  void refresh() {
    setState(() {});
  }

  void onEmailChanged(String value) {
    setState(() {
      emailChecked = false;
    });
  }

  bool checkingEmail = false;

  Future<void> checkEmailDuplicate() async {
    if (checkingEmail) return;
    setState(() => checkingEmail = true);
    try {
      final available =
          await AuthService.isEmailAvailable(emailController.text.trim());
      if (!mounted) return;
      setState(() => emailChecked = available);

      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      if (available) {
        messenger.showSnackBar(const SnackBar(
          content: Text('사용 가능한 이메일입니다.'),
          duration: Duration(milliseconds: 1100),
        ));
      } else {
        // Already registered → offer a shortcut to the login screen.
        messenger.showSnackBar(SnackBar(
          content: const Text('이미 가입된 이메일이에요.'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: '로그인하기',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => checkingEmail = false);
    }
  }

  void moveToProfileSetupIfReady() {
    if (!isPasswordCheckDone || isMovingNext) return;

    setState(() {
      isMovingNext = true;
    });

    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(
            name: nameController.text.trim(),
            email: emailController.text.trim(),
            password: passwordController.text,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 52),

              const AppLogo(fontSize: 36, goHomeOnTap: false),

              const SizedBox(height: 42),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      CustomTextField(
                        label: '이름',
                        hintText: '이름을 입력하세요',
                        controller: nameController,
                        onChanged: (_) => refresh(),
                      ),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        child: showEmail
                            ? Column(
                                children: [
                                  const SizedBox(height: 18),
                                  CustomTextField(
                                    label: '이메일',
                                    hintText: 'contact@gmail.com',
                                    controller: emailController,
                                    onChanged: onEmailChanged,
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        child: showEmailCheckButton
                            ? Column(
                                children: [
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 44,
                                    child: OutlinedButton(
                                      onPressed:
                                          checkingEmail ? null : checkEmailDuplicate,
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: AppColors.primary,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: checkingEmail
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                        AppColors.primary),
                                              ),
                                            )
                                          : const Text(
                                              '이메일 중복확인',
                                              style: TextStyle(
                                                fontFamily: 'Pretendard',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),

                      if (emailChecked) ...[
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '사용 가능한 이메일입니다.',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.safe,
                            ),
                          ),
                        ),
                      ],

                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        child: showPassword
                            ? Column(
                                children: [
                                  const SizedBox(height: 18),
                                  CustomTextField(
                                    label: '비밀번호',
                                    hintText: '영문, 숫자, 특수문자 포함 8자 이상',
                                    obscureText: true,
                                    controller: passwordController,
                                    onChanged: (_) => refresh(),
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      isPasswordDone
                                          ? '사용 가능한 비밀번호입니다.'
                                          : '* 영문, 숫자, 특수문자 포함 8자 이상',
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        color: isPasswordDone
                                            ? AppColors.safe
                                            : AppColors.textSub,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),

                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        child: showPasswordCheck
                            ? Column(
                                children: [
                                  const SizedBox(height: 18),
                                  CustomTextField(
                                    label: '비밀번호 확인',
                                    hintText: '비밀번호를 다시 입력하세요',
                                    obscureText: true,
                                    controller: passwordCheckController,
                                    onChanged: (_) {
                                      refresh();
                                      moveToProfileSetupIfReady();
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  if (passwordCheckController
                                      .text
                                      .trim()
                                      .isNotEmpty)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        isPasswordCheckDone
                                            ? '비밀번호가 일치합니다.'
                                            : '비밀번호가 일치하지 않습니다.',
                                        style: TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w400,
                                          color: isPasswordCheckDone
                                              ? AppColors.safe
                                              : AppColors.danger,
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
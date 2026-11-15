import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../router/app_router.dart';
import '../application/owner_auth_service.dart';
import '../data/registration_repository.dart';
import 'auth_widgets.dart';
import 'legal_links.dart';

/// Owner sign-up (FR-001, FR-002, FR-003).
///
/// In "complete" mode (a verified user whose restaurant was never created)
/// the email and password fields are hidden and only the restaurant is
/// created.
class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _form = GlobalKey<FormState>();
  final _mobileField = GlobalKey<FormFieldState<String>>();
  final _restaurantName = TextEditingController();
  final _city = TextEditingController();
  final _ownerName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  Country _country = Countries.india;
  BusinessType? _businessType;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _restaurantName,
      _city,
      _ownerName,
      _mobile,
      _email,
      _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _completeMode {
    final session = ref.read(authSessionProvider).value;
    return session != null && session.emailVerified && !session.isOwner;
  }

  RegistrationDetails _details() => RegistrationDetails(
    restaurantName: _restaurantName.text,
    ownerName: _ownerName.text,
    mobile: Validators.normalizeMobile(_mobile.text, _country.code)!,
    country: _country,
    businessType: _businessType!,
    city: _city.text,
  );

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = ref.read(ownerAuthServiceProvider);
    try {
      if (_completeMode) {
        await service.completeForCurrentUser(_details());
        return; // The guard moves on once the claims arrive.
      }
      final email = _email.text.trim();
      await service.register(
        email: email,
        password: _password.text,
        details: _details(),
      );
      if (!mounted) return;
      context.go(
        Uri(
          path: Routes.verifyEmail,
          queryParameters: {'email': email.toLowerCase(), 'reason': 'sent'},
        ).toString(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = CoreLocalizations.of(context).messageForError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    ref.watch(authSessionProvider);
    final complete = _completeMode;

    return OwnerAuthLayout(
      title: complete ? l10n.signUpCompleteTitle : l10n.signUpTitle,
      subtitle: complete ? l10n.signUpCompleteSubtitle : l10n.signUpSubtitle,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormSectionTitle(l10n.signUpSectionRestaurant),
            AppTextField(
              key: const ValueKey('signUp.restaurantName'),
              label: l10n.fieldRestaurantName,
              controller: _restaurantName,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.organizationName],
              prefixIcon: Icons.storefront_outlined,
              validator: (v) => Validators.text(core, v),
            ),
            formGap,
            DropdownButtonFormField<BusinessType>(
              key: const ValueKey('signUp.businessType'),
              value: _businessType,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.fieldBusinessType,
                prefixIcon: const Icon(Icons.restaurant_outlined),
              ),
              items: [
                for (final t in BusinessType.values)
                  DropdownMenuItem(value: t, child: Text(t.label(core))),
              ],
              onChanged: (t) => setState(() => _businessType = t),
              validator: (t) => t == null ? core.validationRequired : null,
            ),
            formGap,
            DropdownButtonFormField<Country>(
              key: const ValueKey('signUp.country'),
              value: _country,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.fieldCountry,
                prefixIcon: const Icon(Icons.public),
              ),
              items: [
                for (final c in Countries.all)
                  DropdownMenuItem(value: c, child: Text(c.name(core))),
              ],
              onChanged: (c) {
                if (c == null) return;
                setState(() => _country = c);
                if (_mobile.text.isNotEmpty) {
                  _mobileField.currentState?.validate();
                }
              },
            ),
            formGap,
            AppTextField(
              key: const ValueKey('signUp.city'),
              label: l10n.fieldCity,
              helperText: l10n.fieldCityHelper,
              controller: _city,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.addressCity],
              prefixIcon: Icons.location_city_outlined,
              validator: (v) => Validators.optionalText(core, v),
            ),
            const SizedBox(height: 24),
            FormSectionTitle(l10n.signUpSectionOwner),
            AppTextField(
              key: const ValueKey('signUp.ownerName'),
              label: l10n.fieldOwnerName,
              controller: _ownerName,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              prefixIcon: Icons.person_outline,
              validator: (v) => Validators.text(core, v),
            ),
            formGap,
            _MobileField(
              fieldKey: _mobileField,
              label: l10n.fieldMobile,
              controller: _mobile,
              country: _country,
              validator: (v) => Validators.mobile(core, v, _country.code),
            ),
            if (!complete) ...[
              formGap,
              AppTextField(
                key: const ValueKey('signUp.email'),
                label: l10n.fieldEmail,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                prefixIcon: Icons.mail_outline,
                validator: (v) => Validators.email(core, v),
              ),
              formGap,
              AppPasswordField(
                key: const ValueKey('signUp.password'),
                label: l10n.fieldPassword,
                helperText: l10n.fieldPasswordHelper,
                controller: _password,
                newPassword: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) => Validators.password(core, v),
              ),
            ],
            const SizedBox(height: 24),
            if (_error != null) ...[FormMessage(_error!), formGap],
            AppPrimaryButton(
              key: const ValueKey('signUp.submit'),
              label: complete
                  ? l10n.actionFinishSetup
                  : l10n.actionCreateAccount,
              loading: _busy,
              expand: true,
              onPressed: _submit,
            ),
            // FRD §7.7 / M13: the terms and privacy policy, before signing up.
            const LegalLinks(),
            formGap,
            if (complete)
              Center(
                child: TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => ref.read(ownerAuthServiceProvider).signOut(),
                  child: Text(l10n.actionSignOut),
                ),
              )
            else
              AuthLinkRow(
                text: l10n.signUpHaveAccount,
                action: l10n.actionSignIn,
                onPressed: () => context.go(Routes.signIn),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mobile number with the country's dial code shown in front.
class _MobileField extends StatelessWidget {
  const _MobileField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.country,
    required this.validator,
  });

  final GlobalKey<FormFieldState<String>> fieldKey;
  final String label;
  final TextEditingController controller;
  final Country country;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: fieldKey,
    controller: controller,
    validator: validator,
    keyboardType: TextInputType.phone,
    textInputAction: TextInputAction.next,
    autofillHints: const [AutofillHints.telephoneNumberNational],
    autovalidateMode: AutovalidateMode.onUserInteraction,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.phone_outlined),
      prefixText: '+${country.dialCode} ',
    ),
  );
}

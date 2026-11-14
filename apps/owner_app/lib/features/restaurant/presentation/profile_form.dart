import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/draft_autosave.dart';
import 'menu_header_preview.dart';

/// Field keys, for tests.
abstract final class ProfileKeys {
  static const name = ValueKey('profile.name');
  static const businessType = ValueKey('profile.businessType');
  static const description = ValueKey('profile.description');
  static const phone = ValueKey('profile.phone');
  static const email = ValueKey('profile.email');
  static const website = ValueKey('profile.website');
  static const address = ValueKey('profile.address');
  static const city = ValueKey('profile.city');
  static const postalCode = ValueKey('profile.postalCode');
  static ValueKey<String> social(SocialNetwork n) =>
      ValueKey('profile.social.${n.key}');
  static ValueKey<String> visibility(VisibleField f) =>
      ValueKey('profile.visibility.${f.key}');
}

/// Edits the FR-011 profile fields of one restaurant and stages valid
/// changes in [DraftAutosave] (M03). Owned by a page's State; used by the
/// profile page and the setup wizard.
///
/// Every text field validates as the owner types. A valid change is staged
/// (whole `contact` map at a time); an invalid one marks the field invalid,
/// so the indicator says "Fix the highlighted fields".
class ProfileFormModel {
  ProfileFormModel(this.base, {required this.autosave, required this.onChanged})
    : country = Countries.byCode(base.country) ?? Countries.india,
      businessType = base.businessType,
      visibility = base.visibility {
    final c = base.contact;
    name.text = base.name;
    description.text = base.description;
    phone.text = c.phone == null ? '' : Validators.nationalNumber(c.phone!);
    email.text = c.email ?? '';
    website.text = c.website ?? '';
    address.text = c.address ?? '';
    city.text = c.city ?? '';
    postalCode.text = c.postalCode ?? '';
    for (final n in SocialNetwork.values) {
      social[n] = TextEditingController(text: c.social[n] ?? '');
    }
  }

  /// The restaurant when the form opened (system fields, images).
  Restaurant base;
  final DraftAutosave Function() autosave;

  /// Called after every change, to rebuild the preview.
  final VoidCallback onChanged;
  final Country country;

  BusinessType? businessType;
  PublicVisibility visibility;

  final name = TextEditingController();
  final description = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final website = TextEditingController();
  final address = TextEditingController();
  final city = TextEditingController();
  final postalCode = TextEditingController();
  final social = <SocialNetwork, TextEditingController>{};

  void dispose() {
    for (final c in [
      name,
      description,
      phone,
      email,
      website,
      address,
      city,
      postalCode,
      ...social.values,
    ]) {
      c.dispose();
    }
  }

  // ---- Validation -------------------------------------------------------

  String? nameError(CoreLocalizations l10n) =>
      Validators.text(l10n, name.text, max: RestaurantFields.nameMax);

  String? descriptionError(CoreLocalizations l10n) => Validators.optionalText(
    l10n,
    description.text,
    max: RestaurantFields.descriptionMax,
  );

  String? phoneError(CoreLocalizations l10n) =>
      Validators.optionalPhone(l10n, phone.text, country.code);

  String? emailError(CoreLocalizations l10n) =>
      Validators.optionalEmail(l10n, email.text);

  String? websiteError(CoreLocalizations l10n) =>
      Validators.optionalHttpsUrl(l10n, website.text);

  String? addressError(CoreLocalizations l10n) => Validators.optionalText(
    l10n,
    address.text,
    max: RestaurantFields.addressMax,
  );

  String? cityError(CoreLocalizations l10n) =>
      Validators.optionalText(l10n, city.text, max: RestaurantFields.cityMax);

  String? postalError(CoreLocalizations l10n) =>
      Validators.optionalPostalCode(l10n, postalCode.text, country.address);

  String? socialError(CoreLocalizations l10n, SocialNetwork n) =>
      Validators.optionalSocialLink(
        l10n,
        n.key,
        social[n]!.text,
        n.label(l10n),
      );

  bool contactValid(CoreLocalizations l10n) =>
      phoneError(l10n) == null &&
      emailError(l10n) == null &&
      websiteError(l10n) == null &&
      addressError(l10n) == null &&
      cityError(l10n) == null &&
      postalError(l10n) == null &&
      SocialNetwork.values.every((n) => socialError(l10n, n) == null);

  // ---- Values -----------------------------------------------------------

  String? _clean(String text) => text.trim().isEmpty ? null : text.trim();

  /// The contact details as stored: phone in E.164, links normalized.
  ContactInfo contact() => ContactInfo(
    phone: _clean(phone.text) == null
        ? null
        : Validators.normalizeMobile(phone.text.trim(), country.code),
    email: _clean(email.text),
    website: _clean(website.text) == null
        ? null
        : Validators.normalizeHttpsUrl(website.text),
    address: _clean(address.text),
    city: _clean(city.text),
    postalCode: _clean(postalCode.text),
    social: {
      for (final n in SocialNetwork.values)
        if (_clean(social[n]!.text) != null)
          if (Validators.normalizeSocialLink(n.key, social[n]!.text)
              case final url?)
            n: url,
    },
  );

  /// The restaurant with the form's values, for the live preview.
  Restaurant preview(Restaurant live) => live.copyWith(
    name: name.text.trim(),
    businessType: () => businessType,
    description: description.text.trim(),
    contact: contact(),
    visibility: visibility,
  );

  // ---- Change handlers --------------------------------------------------

  void nameChanged(CoreLocalizations l10n) {
    final ok = nameError(l10n) == null;
    autosave().setInvalid('name', invalid: !ok);
    if (ok) autosave().stage(RestaurantFields.name, name.text.trim());
    onChanged();
  }

  void businessTypeChanged(BusinessType? value) {
    if (value == null) return;
    businessType = value;
    autosave().stage(RestaurantFields.businessType, value.name);
    onChanged();
  }

  void descriptionChanged(CoreLocalizations l10n) {
    final ok = descriptionError(l10n) == null;
    autosave().setInvalid('description', invalid: !ok);
    if (ok) {
      autosave().stage(RestaurantFields.description, description.text.trim());
    }
    onChanged();
  }

  void contactChanged(CoreLocalizations l10n) {
    final ok = contactValid(l10n);
    autosave().setInvalid('contact', invalid: !ok);
    if (ok) autosave().stage(RestaurantFields.contact, contact().toMap());
    onChanged();
  }

  void visibilityChanged(VisibleField field, bool shown) {
    visibility = visibility.withField(field, shown: shown);
    autosave().stage(RestaurantFields.visibility, visibility.toMap());
    onChanged();
  }

  // ---- Field widgets ----------------------------------------------------

  Widget nameField(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    return AppTextField(
      key: ProfileKeys.name,
      controller: name,
      label: l10n.fieldRestaurantName,
      maxLength: RestaurantFields.nameMax,
      textInputAction: TextInputAction.next,
      validator: (_) => nameError(core),
      onChanged: (_) => nameChanged(core),
    );
  }

  Widget businessTypeField(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    return DropdownButtonFormField<BusinessType>(
      key: ProfileKeys.businessType,
      value: businessType,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.fieldBusinessType),
      validator: (v) => v == null ? core.validationRequired : null,
      items: [
        for (final t in BusinessType.values)
          DropdownMenuItem(value: t, child: Text(t.label(core))),
      ],
      onChanged: businessTypeChanged,
    );
  }

  Widget descriptionField(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    return AppTextField(
      key: ProfileKeys.description,
      controller: description,
      label: l10n.fieldDescription,
      helperText: l10n.fieldDescriptionHelper,
      maxLength: RestaurantFields.descriptionMax,
      maxLines: 5,
      minLines: 3,
      keyboardType: TextInputType.multiline,
      validator: (_) => descriptionError(core),
      onChanged: (_) => descriptionChanged(core),
    );
  }

  Widget phoneField(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    return AppTextField(
      key: ProfileKeys.phone,
      controller: phone,
      label: l10n.fieldPhone,
      helperText: l10n.fieldPhoneHelper,
      prefixText: '+${country.dialCode} ',
      keyboardType: TextInputType.phone,
      autofillHints: const [AutofillHints.telephoneNumber],
      validator: (_) => phoneError(core),
      onChanged: (_) => contactChanged(core),
    );
  }

  Widget emailField(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    return AppTextField(
      key: ProfileKeys.email,
      controller: email,
      label: l10n.fieldPublicEmail,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      validator: (_) => emailError(core),
      onChanged: (_) => contactChanged(core),
    );
  }

  Widget websiteField(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    return AppTextField(
      key: ProfileKeys.website,
      controller: website,
      label: l10n.fieldWebsite,
      hintText: 'https://',
      keyboardType: TextInputType.url,
      autofillHints: const [AutofillHints.url],
      validator: (_) => websiteError(core),
      onChanged: (_) => contactChanged(core),
    );
  }

  /// Address, city and postal code in the country's order (FRD §6.4).
  List<Widget> addressFields(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    final format = country.address;
    return [
      for (final part in format.order)
        switch (part) {
          AddressPart.address => AppTextField(
            key: ProfileKeys.address,
            controller: address,
            label: l10n.fieldAddress,
            helperText: l10n.fieldAddressHelper,
            maxLines: 2,
            minLines: 1,
            autofillHints: const [AutofillHints.fullStreetAddress],
            validator: (_) => addressError(core),
            onChanged: (_) => contactChanged(core),
          ),
          AddressPart.city => AppTextField(
            key: ProfileKeys.city,
            controller: city,
            label: l10n.fieldCityPlain,
            autofillHints: const [AutofillHints.addressCity],
            validator: (_) => cityError(core),
            onChanged: (_) => contactChanged(core),
          ),
          AddressPart.postalCode => AppTextField(
            key: ProfileKeys.postalCode,
            controller: postalCode,
            label: format.postalLabel.label(core),
            hintText: format.postalExample,
            autofillHints: const [AutofillHints.postalCode],
            validator: (_) => postalError(core),
            onChanged: (_) => contactChanged(core),
          ),
        },
    ];
  }

  List<Widget> socialFields(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final core = CoreLocalizations.of(context);
    return [
      for (final n in SocialNetwork.values)
        AppTextField(
          key: ProfileKeys.social(n),
          controller: social[n],
          label: n.label(core),
          hintText: n == SocialNetwork.googleMaps
              ? l10n.fieldMapsHint
              : l10n.fieldSocialHint,
          keyboardType: TextInputType.url,
          validator: (_) => socialError(core, n),
          onChanged: (_) => contactChanged(core),
        ),
    ];
  }

  List<Widget> visibilityFields(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      for (final f in VisibleField.values)
        SwitchListTile(
          key: ProfileKeys.visibility(f),
          contentPadding: EdgeInsetsDirectional.zero,
          title: Text(visibleFieldLabel(l10n, f)),
          value: visibility.isShown(f),
          onChanged: (shown) => visibilityChanged(f, shown),
        ),
    ];
  }
}

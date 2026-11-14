import '../l10n/generated/core_localizations.dart';

/// Address parts a restaurant profile can hold (FR-011).
enum AddressPart { address, city, postalCode }

/// What the postal code is called in a country.
enum PostalCodeLabel {
  postalCode,
  pinCode,
  zipCode;

  String label(CoreLocalizations l10n) => switch (this) {
    PostalCodeLabel.postalCode => l10n.addressPostalCode,
    PostalCodeLabel.pinCode => l10n.addressPinCode,
    PostalCodeLabel.zipCode => l10n.addressZipCode,
  };
}

/// A country's address form: which parts it uses, in which order, and the
/// postal code format (FRD §6.1, §6.4). Data only, so adding a market needs
/// no code change.
class AddressFormat {
  const AddressFormat({
    this.order = const [
      AddressPart.address,
      AddressPart.city,
      AddressPart.postalCode,
    ],
    this.postalLabel = PostalCodeLabel.postalCode,
    this.postalPattern,
    this.postalExample,
  });

  /// Parts in display and entry order. Countries without postal codes
  /// leave [AddressPart.postalCode] out.
  final List<AddressPart> order;

  final PostalCodeLabel postalLabel;

  /// Full-match pattern for the postal code, or null to accept any
  /// reasonable value (letters, digits, spaces and hyphens).
  final String? postalPattern;

  /// Shown as a hint, for example `600017`.
  final String? postalExample;

  bool get hasPostalCode => order.contains(AddressPart.postalCode);

  /// Whether [value] (already trimmed) is a valid postal code here.
  bool isValidPostalCode(String value) {
    // Same shape the security rules accept.
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9 -]{1,11}$').hasMatch(value)) {
      return false;
    }
    final pattern = postalPattern;
    return pattern == null || RegExp('^(?:$pattern)\$').hasMatch(value);
  }
}

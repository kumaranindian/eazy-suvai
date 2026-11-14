import '../l10n/generated/core_localizations.dart';
import 'image_object.dart';

/// Localized messages for image rejections (M02).
extension ImageMessages on CoreLocalizations {
  /// What went wrong with an image for [purpose], in the user's language.
  String imageRejectMessage(ImageRejectReason reason, ImagePurpose purpose) =>
      switch (reason) {
        ImageRejectReason.unsupportedType => imageErrorUnsupportedType,
        ImageRejectReason.tooLarge => imageErrorTooLarge,
        ImageRejectReason.tooSmall => imageErrorTooSmall(
          purpose.minWidth,
          purpose.minHeight,
        ),
        ImageRejectReason.invalidImage => imageErrorInvalid,
        ImageRejectReason.processingFailed => imageErrorProcessingFailed,
        ImageRejectReason.uploadFailed => imageErrorUploadFailed,
        ImageRejectReason.pickFailed => imageErrorPickFailed,
      };
}

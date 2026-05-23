import 'package:flutter/material.dart';

enum ImageSyncTone { neutral, success, warning, error, progress }

class ImageSyncStatus {
  const ImageSyncStatus({
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final ImageSyncTone tone;
}

ImageSyncStatus? resolveImageSyncStatus({
  required String imageUrl,
  required bool hasSelectedImage,
  required bool isUploadingImage,
  String? uploadError,
}) {
  if (uploadError != null) {
    return const ImageSyncStatus(
      label: 'Lỗi upload ảnh',
      icon: Icons.error_outline_rounded,
      tone: ImageSyncTone.error,
    );
  }

  if (isUploadingImage) {
    return const ImageSyncStatus(
      label: 'Đang upload ảnh lên Cloudinary',
      icon: Icons.cloud_upload_rounded,
      tone: ImageSyncTone.progress,
    );
  }

  if (hasSelectedImage) {
    return const ImageSyncStatus(
      label: 'Sẵn sàng upload Cloudinary',
      icon: Icons.cloud_queue_rounded,
      tone: ImageSyncTone.neutral,
    );
  }

  final trimmedUrl = imageUrl.trim();
  if (trimmedUrl.isEmpty) return null;

  if (isCloudinaryImageUrl(trimmedUrl)) {
    return const ImageSyncStatus(
      label: 'Đã lưu Cloudinary',
      icon: Icons.cloud_done_rounded,
      tone: ImageSyncTone.success,
    );
  }

  if (isGoogleHostedImageUrl(trimmedUrl)) {
    return const ImageSyncStatus(
      label: 'Ảnh Google Maps tạm thời',
      icon: Icons.map_rounded,
      tone: ImageSyncTone.warning,
    );
  }

  return const ImageSyncStatus(
    label: 'Ảnh từ liên kết ngoài',
    icon: Icons.link_rounded,
    tone: ImageSyncTone.neutral,
  );
}

bool isCloudinaryImageUrl(String value) {
  final uri = Uri.tryParse(value);
  final host = uri?.host.toLowerCase() ?? '';
  return host == 'res.cloudinary.com' || host.endsWith('.cloudinary.com');
}

bool isGoogleHostedImageUrl(String value) {
  final uri = Uri.tryParse(value);
  final host = uri?.host.toLowerCase() ?? '';
  return host.contains('googleusercontent.com') ||
      host.contains('gstatic.com') ||
      host.contains('googleapis.com');
}

import 'package:flutter_test/flutter_test.dart';
import 'package:roamy/screens/add_place/image_sync_status.dart';

void main() {
  test('marks selected local images as ready to upload', () {
    final status = resolveImageSyncStatus(
      imageUrl: '',
      hasSelectedImage: true,
      isUploadingImage: false,
    );

    expect(status?.label, 'Sẵn sàng upload Cloudinary');
    expect(status?.tone, ImageSyncTone.neutral);
  });

  test('marks image upload progress and failures', () {
    final uploading = resolveImageSyncStatus(
      imageUrl: '',
      hasSelectedImage: true,
      isUploadingImage: true,
    );
    final failed = resolveImageSyncStatus(
      imageUrl: '',
      hasSelectedImage: true,
      isUploadingImage: false,
      uploadError: 'Cloudinary lỗi',
    );

    expect(uploading?.label, 'Đang upload ảnh lên Cloudinary');
    expect(uploading?.tone, ImageSyncTone.progress);
    expect(failed?.label, 'Lỗi upload ảnh');
    expect(failed?.tone, ImageSyncTone.error);
  });

  test('distinguishes Cloudinary, Google Maps, and external image URLs', () {
    final cloudinary = resolveImageSyncStatus(
      imageUrl: 'https://res.cloudinary.com/demo/image/upload/roamy/photo.jpg',
      hasSelectedImage: false,
      isUploadingImage: false,
    );
    final googleMaps = resolveImageSyncStatus(
      imageUrl: 'https://lh5.googleusercontent.com/p/map-photo=w408-h306-k-no',
      hasSelectedImage: false,
      isUploadingImage: false,
    );
    final external = resolveImageSyncStatus(
      imageUrl: 'https://example.com/photo.jpg',
      hasSelectedImage: false,
      isUploadingImage: false,
    );

    expect(cloudinary?.label, 'Đã lưu Cloudinary');
    expect(googleMaps?.label, 'Ảnh Google Maps tạm thời');
    expect(external?.label, 'Ảnh từ liên kết ngoài');
  });
}

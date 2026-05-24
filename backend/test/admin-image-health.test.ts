import assert from 'node:assert/strict';
import test from 'node:test';

import { checkImageUrl } from '../src/modules/admin/admin.image-health';

test('image health marks empty image URLs as missing', async () => {
  const result = await checkImageUrl('');

  assert.equal(result.status, 'MISSING');
  assert.equal(result.errorMessage, 'No image URL saved');
});

test('image health rejects non-http image URLs', async () => {
  const result = await checkImageUrl('file:///tmp/image.png');

  assert.equal(result.status, 'BROKEN');
  assert.equal(result.errorMessage, 'Image URL is not HTTP/HTTPS');
});

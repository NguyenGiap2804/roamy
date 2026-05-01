import assert from 'node:assert/strict';
import test from 'node:test';

import type { NextFunction, Request, Response } from 'express';

import { ValidationError } from '../src/utils/errors';
import {
  validateUploadedImage,
} from '../src/modules/upload/upload.service';
import { createUploadHandler } from '../src/modules/upload/upload.routes';

test('validateUploadedImage rejects files with unsupported mime types', () => {
  const file = createFile({
    mimetype: 'text/plain',
    buffer: Buffer.from('not-an-image'),
  });

  assert.throws(
    () => validateUploadedImage(file),
    (error: unknown) =>
      error instanceof ValidationError &&
      error.message ===
        'Only JPEG, PNG, WebP, GIF, HEIC, and HEIF images are allowed',
  );
});

test('validateUploadedImage rejects mismatched image buffers', () => {
  const file = createFile({
    mimetype: 'image/png',
    buffer: Buffer.from('not-a-real-png'),
  });

  assert.throws(
    () => validateUploadedImage(file),
    (error: unknown) =>
      error instanceof ValidationError &&
      error.message === 'Uploaded file is not a valid image',
  );
});

test('validateUploadedImage accepts a valid png signature', () => {
  const file = createFile({
    mimetype: 'image/png',
    buffer: Buffer.from([
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      0x00,
    ]),
  });

  assert.doesNotThrow(() => validateUploadedImage(file));
});

test('upload handler forwards missing file errors as validation errors', async () => {
  const handler = createUploadHandler({
    uploadImage: async () => 'unused',
  });

  const nextError = await invokeHandler(handler, createRequest(), createResponse());

  assert(nextError instanceof ValidationError);
  assert.equal(nextError.message, 'No image provided');
});

test('upload handler forwards unexpected service failures to shared middleware', async () => {
  const failure = new Error('disk write failed');
  const handler = createUploadHandler({
    uploadImage: async () => {
      throw failure;
    },
  });

  const nextError = await invokeHandler(
    handler,
    createRequest({
      file: createFile({
        mimetype: 'image/png',
        buffer: Buffer.from([
          0x89,
          0x50,
          0x4e,
          0x47,
          0x0d,
          0x0a,
          0x1a,
          0x0a,
          0x00,
        ]),
      }),
    }),
    createResponse(),
  );

  assert.equal(nextError, failure);
});

type UploadHandler = ReturnType<typeof createUploadHandler>;

async function invokeHandler(
  handler: UploadHandler,
  req: Request,
  res: Response,
) {
  let capturedError: unknown;
  const next: NextFunction = (error?: unknown) => {
    capturedError = error;
  };

  await handler(req, res, next);
  return capturedError;
}

function createRequest(overrides: Partial<Request> = {}) {
  return {
    protocol: 'http',
    file: undefined,
    get: (header: string) => (header.toLowerCase() === 'host' ? 'localhost:4000' : undefined),
    ...overrides,
  } as Request;
}

function createResponse() {
  return {
    status: () => createResponse(),
    json: () => createResponse(),
  } as unknown as Response;
}

function createFile({
  mimetype,
  buffer,
}: {
  mimetype: string;
  buffer: Buffer;
}) {
  return {
    fieldname: 'image',
    originalname: 'upload.bin',
    encoding: '7bit',
    mimetype,
    size: buffer.length,
    buffer,
    stream: undefined,
    destination: '',
    filename: '',
    path: '',
  } as Express.Multer.File;
}

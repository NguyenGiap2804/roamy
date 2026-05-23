import assert from 'node:assert/strict';
import test from 'node:test';

import type { NextFunction, Request, Response } from 'express';

import { ValidationError } from '../src/utils/errors';
import {
  UploadService,
  validateUploadedImage,
} from '../src/modules/upload/upload.service';
import { createUploadHandler } from '../src/modules/upload/upload.routes';
import { AppError } from '../src/utils/errors';

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

test('production uploads fail fast when durable image storage is not configured', async () => {
  const restoreEnv = withUploadEnv({
    NODE_ENV: 'production',
    CLOUDINARY_CLOUD_NAME: undefined,
    CLOUDINARY_API_KEY: undefined,
    CLOUDINARY_API_SECRET: undefined,
  });

  try {
    const service = new UploadService();
    await assert.rejects(
      () =>
        service.uploadImage(
          createFile({
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
          'https://roamy-backend.example.com',
        ),
      (error: unknown) => {
        assert(error instanceof AppError);
        assert.equal(error.statusCode, 503);
        assert.match(error.message, /Image storage is not configured/);
        return true;
      },
    );
  } finally {
    restoreEnv();
  }
});

test('development uploads may use local disk fallback', async () => {
  const restoreEnv = withUploadEnv({
    NODE_ENV: 'development',
    CLOUDINARY_CLOUD_NAME: undefined,
    CLOUDINARY_API_KEY: undefined,
    CLOUDINARY_API_SECRET: undefined,
  });

  try {
    const service = new UploadService();
    const url = await service.uploadImage(
      createFile({
        mimetype: 'image/png',
        originalname: 'upload.png',
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
      'http://localhost:4000',
    );

    assert.match(url, /^http:\/\/localhost:4000\/uploads\/.+\.png$/);
  } finally {
    restoreEnv();
  }
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
  originalname = 'upload.bin',
}: {
  mimetype: string;
  buffer: Buffer;
  originalname?: string;
}) {
  return {
    fieldname: 'image',
    originalname,
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

function withUploadEnv(values: Record<string, string | undefined>) {
  const previous = new Map<string, string | undefined>();
  for (const [key, value] of Object.entries(values)) {
    previous.set(key, process.env[key]);
    if (value === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = value;
    }
  }

  return () => {
    for (const [key, value] of previous.entries()) {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
  };
}

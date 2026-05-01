import assert from "node:assert/strict";
import test from "node:test";

import type { NextFunction, Request, Response } from "express";

import { errorMiddleware } from "../src/middlewares/error.middleware";
import { AppError, ValidationError } from "../src/utils/errors";

test("production 500 responses do not expose stack traces", () => {
  const restoreEnv = withNodeEnv("production");
  const originalConsoleError = console.error;
  const logs: unknown[] = [];
  console.error = (...args: unknown[]) => {
    logs.push(args);
  };

  try {
    const response = createResponseCapture();
    const error = new Error("database credentials leaked");
    error.stack = "SECRET_STACK";

    errorMiddleware(
      error,
      createRequest(),
      response.res,
      createNext(),
    );

    assert.equal(response.statusCode, 500);
    assert.deepEqual(response.body, {
      data: null,
      message: "Internal server error",
      status: 500,
    });
    assert(logs.length >= 1);
    assert.equal(logs[0]?.[0], "[Roamy API Error]");
  } finally {
    console.error = originalConsoleError;
    restoreEnv();
  }
});

test("development 500 responses still include debugging fields", () => {
  const restoreEnv = withNodeEnv("development");
  const originalConsoleError = console.error;
  console.error = () => {};

  try {
    const response = createResponseCapture();
    const error = new Error("boom");
    error.stack = "DEV_STACK";

    errorMiddleware(
      error,
      createRequest(),
      response.res,
      createNext(),
    );

    assert.equal(response.statusCode, 500);
    assert.equal(response.body.message, "boom");
    assert.equal(response.body.errorName, "Error");
    assert.equal(response.body.stack, "DEV_STACK");
  } finally {
    console.error = originalConsoleError;
    restoreEnv();
  }
});

test("production app errors with 500 status hide internal message and details", () => {
  const restoreEnv = withNodeEnv("production");
  const originalConsoleError = console.error;
  console.error = () => {};

  try {
    const response = createResponseCapture();
    const error = new AppError(500, "Sensitive backend failure", {
      stack: "HIDDEN",
      internalCode: "X-123",
    });

    errorMiddleware(
      error,
      createRequest(),
      response.res,
      createNext(),
    );

    assert.equal(response.statusCode, 500);
    assert.deepEqual(response.body, {
      data: null,
      message: "Internal server error",
      status: 500,
    });
  } finally {
    console.error = originalConsoleError;
    restoreEnv();
  }
});

test("production validation errors keep useful details but strip stack fields", () => {
  const restoreEnv = withNodeEnv("production");
  const originalConsoleError = console.error;
  console.error = () => {};

  try {
    const response = createResponseCapture();
    const error = new ValidationError("Validation failed", {
      fieldErrors: {
        image: ["Required"],
      },
      stack: "REMOVE_ME",
      nested: {
        keep: true,
        stackTrace: "REMOVE_ME_TOO",
      },
    });

    errorMiddleware(
      error,
      createRequest(),
      response.res,
      createNext(),
    );

    assert.equal(response.statusCode, 400);
    assert.deepEqual(response.body, {
      data: {
        fieldErrors: {
          image: ["Required"],
        },
        nested: {
          keep: true,
        },
      },
      message: "Validation failed",
      status: 400,
    });
  } finally {
    console.error = originalConsoleError;
    restoreEnv();
  }
});

function createRequest(overrides: Partial<Request> = {}) {
  return {
    method: "POST",
    originalUrl: "/api/v1/upload",
    ...overrides,
  } as Request;
}

function createResponseCapture() {
  const state: {
    statusCode?: number;
    body?: Record<string, unknown>;
  } = {};

  const res = {
    status(code: number) {
      state.statusCode = code;
      return this;
    },
    json(payload: Record<string, unknown>) {
      state.body = payload;
      return this;
    },
  } as unknown as Response;

  return {
    res,
    get statusCode() {
      return state.statusCode;
    },
    get body() {
      return state.body;
    },
  };
}

function createNext() {
  return ((_error?: unknown) => undefined) as NextFunction;
}

function withNodeEnv(value: string) {
  const previous = process.env.NODE_ENV;
  process.env.NODE_ENV = value;
  return () => {
    if (previous === undefined) {
      delete process.env.NODE_ENV;
      return;
    }
    process.env.NODE_ENV = previous;
  };
}

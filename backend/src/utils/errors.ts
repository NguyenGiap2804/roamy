export class AppError extends Error {
  constructor(
    public readonly statusCode: number,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
    Error.captureStackTrace(this, this.constructor);
  }
}

export class NotFoundError extends AppError {
  constructor(message = "Resource not found") {
    super(404, message);
  }
}

export class ValidationError extends AppError {
  constructor(message = "Validation failed", details?: unknown) {
    super(400, message, details);
  }
}

export class ConflictError extends AppError {
  constructor(message = "Resource already exists", details?: unknown) {
    super(409, message, details);
  }
}

export class InternalServerError extends AppError {
  constructor(message = "Internal server error") {
    super(500, message);
  }
}

declare namespace Express {
  interface Request {
    requestId?: string;
    deviceId?: string;
    userId?: string;
    userEmail?: string;
  }
}

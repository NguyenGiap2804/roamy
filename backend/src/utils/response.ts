import { Response } from 'express';

export function sendResponse<T>(
  res: Response,
  status: number,
  message: string,
  data?: T,
) {
  return res.status(status).json({
    data,
    message,
    status,
  });
}

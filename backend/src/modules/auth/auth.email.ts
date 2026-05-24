import nodemailer from 'nodemailer';
import SMTPTransport from 'nodemailer/lib/smtp-transport';

import { AppError } from '../../utils/errors';

type AuthEmailInput = {
  to: string;
  subject: string;
  text: string;
};

export async function sendAuthEmail(input: AuthEmailInput) {
  const host = process.env.SMTP_HOST;
  const port = Number(process.env.SMTP_PORT || 587);
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  const from = process.env.MAIL_FROM || user;
  const timeoutMs = Number(process.env.SMTP_TIMEOUT_MS || 8000);

  if (!host || !user || !pass || !from) {
    if (process.env.NODE_ENV === 'production') {
      throw new AppError(500, 'Email delivery is not configured');
    }
    console.log('[Roamy Auth Email]', input);
    return;
  }

  const transportOptions = {
    host,
    port,
    secure: process.env.SMTP_SECURE === 'true',
    auth: { user, pass },
    family: 4,
    connectionTimeout: timeoutMs,
    greetingTimeout: timeoutMs,
    socketTimeout: timeoutMs,
  } as SMTPTransport.Options & { family: number };

  const transporter = nodemailer.createTransport(transportOptions);

  try {
    await transporter.sendMail({
      from,
      to: input.to,
      subject: input.subject,
      text: input.text,
    });
  } catch (error) {
    throw new AppError(502, 'Could not send auth email. Please try again later.', {
      cause: sanitizeEmailError(error),
    });
  }
}

function sanitizeEmailError(error: unknown) {
  if (!(error instanceof Error)) {
    return 'Unknown email delivery error';
  }

  const code = (error as NodeJS.ErrnoException).code;
  return code ? `${code}: ${error.message}` : error.message;
}

import nodemailer from 'nodemailer';

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

  if (!host || !user || !pass || !from) {
    if (process.env.NODE_ENV === 'production') {
      throw new AppError(500, 'Email delivery is not configured');
    }
    console.log('[Roamy Auth Email]', input);
    return;
  }

  const transporter = nodemailer.createTransport({
    host,
    port,
    secure: process.env.SMTP_SECURE === 'true',
    auth: { user, pass },
  });

  await transporter.sendMail({
    from,
    to: input.to,
    subject: input.subject,
    text: input.text,
  });
}

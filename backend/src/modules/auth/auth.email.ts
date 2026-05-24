import { promises as dns, setDefaultResultOrder } from "dns";
import nodemailer from "nodemailer";
import SMTPTransport from "nodemailer/lib/smtp-transport";

import { AppError } from "../../utils/errors";

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
    if (process.env.NODE_ENV === "production") {
      throw new AppError(500, "Email delivery is not configured");
    }
    console.log("[Roamy Auth Email]", input);
    return;
  }

  setDefaultResultOrder("ipv4first");
  const transportHost = await resolveTransportHost(host);

  try {
    await sendMailWithOptions(
      buildTransportOptions({
        host,
        transportHost,
        port,
        secure: process.env.SMTP_SECURE === "true",
        user,
        pass,
        timeoutMs,
      }),
      input,
      from,
    );
  } catch (error) {
    if (shouldFallbackToGmailStartTls(error, host, port)) {
      try {
        await sendMailWithOptions(
          buildTransportOptions({
            host,
            transportHost,
            port: 587,
            secure: false,
            user,
            pass,
            timeoutMs,
          }),
          input,
          from,
        );
        return;
      } catch (fallbackError) {
        throw emailDeliveryError(fallbackError);
      }
    }

    throw emailDeliveryError(error);
  }
}

async function sendMailWithOptions(
  options: SMTPTransport.Options & { family: number },
  input: AuthEmailInput,
  from: string,
) {
  const transporter = nodemailer.createTransport(options);
  await transporter.sendMail({
    from,
    to: input.to,
    subject: input.subject,
    text: input.text,
  });
}

function buildTransportOptions(input: {
  host: string;
  transportHost: string;
  port: number;
  secure: boolean;
  user: string;
  pass: string;
  timeoutMs: number;
}) {
  return {
    host: input.transportHost,
    port: input.port,
    secure: input.secure,
    requireTLS: !input.secure,
    auth: { user: input.user, pass: input.pass },
    tls: {
      servername: input.host,
    },
    family: 4,
    connectionTimeout: input.timeoutMs,
    greetingTimeout: input.timeoutMs,
    socketTimeout: input.timeoutMs,
  } as SMTPTransport.Options & { family: number };
}

async function resolveTransportHost(host: string) {
  try {
    const addresses = await dns.resolve4(host);
    return addresses[0] ?? host;
  } catch {
    return host;
  }
}

function shouldFallbackToGmailStartTls(
  error: unknown,
  host: string,
  port: number,
) {
  if (!host.toLowerCase().includes("gmail.com") || port !== 465) {
    return false;
  }

  const code =
    error instanceof Error ? (error as NodeJS.ErrnoException).code : null;
  return code === "ETIMEDOUT" || code === "ESOCKET" || code === "ENETUNREACH";
}

function emailDeliveryError(error: unknown) {
  return new AppError(
    502,
    "Could not send auth email. Please try again later.",
    {
      cause: sanitizeEmailError(error),
    },
  );
}

function sanitizeEmailError(error: unknown) {
  if (!(error instanceof Error)) {
    return "Unknown email delivery error";
  }

  const code = (error as NodeJS.ErrnoException).code;
  return code ? `${code}: ${error.message}` : error.message;
}

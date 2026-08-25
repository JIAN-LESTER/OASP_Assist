import axios from "axios";
import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as net from "net";
import * as tls from "tls";

type EmailKind = "verify" | "reset" | "change";

const appName = process.env.AUTH_EMAIL_APP_NAME || "CMU OASP Assist";
const fromEmail =
  process.env.AUTH_EMAIL_FROM ||
  process.env.GMAIL_USER ||
  process.env.SMTP_USER ||
  "oasp.assist@gmail.com";
const continueUrl =
  process.env.AUTH_EMAIL_CONTINUE_URL || "https://cmu-oasp-assist.web.app";

const actionCodeSettings = {
  url: continueUrl,
  handleCodeInApp: false,
};

const callableOptions = {region: "asia-southeast1"};

function requireEmail(value: unknown, field = "email"): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `Missing ${field}.`);
  }

  const email = value.trim().toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("invalid-argument", `Invalid ${field}.`);
  }

  return email;
}

function buildEmail(kind: EmailKind, link: string, newEmail?: string) {
  const titles = {
    verify: "Verify your email address",
    reset: "Reset your password",
    change: "Confirm your new email address",
  };

  const body = {
    verify: "Confirm this email address to finish setting up your account.",
    reset: "Use this secure link to choose a new password.",
    change: `Confirm ${newEmail} as the new email address for your account.`,
  };

  const button = {
    verify: "Verify Email",
    reset: "Reset Password",
    change: "Confirm Email Change",
  };

  const title = titles[kind];

  return {
    subject: `${appName}: ${title}`,
    text: `${title}\n\n${body[kind]}\n\n${link}\n\nIf you did not request this, you can ignore this email.`,
    html: `<!doctype html>
<html>
  <body style="margin:0;background:#f6f8fb;font-family:Arial,sans-serif;color:#172033;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border:1px solid #dde4ee;border-radius:8px;overflow:hidden;">
            <tr>
              <td style="background:#14532d;padding:24px 28px;color:#ffffff;font-size:20px;font-weight:700;">
                ${appName}
              </td>
            </tr>
            <tr>
              <td style="padding:28px;">
                <h1 style="margin:0 0 12px;font-size:24px;line-height:1.25;color:#172033;">${title}</h1>
                <p style="margin:0 0 24px;font-size:16px;line-height:1.6;color:#394456;">${body[kind]}</p>
                <a href="${link}" style="display:inline-block;background:#166534;color:#ffffff;text-decoration:none;font-weight:700;padding:12px 18px;border-radius:6px;">${button[kind]}</a>
                <p style="margin:24px 0 0;font-size:13px;line-height:1.5;color:#6b7280;">If the button does not work, copy and paste this link into your browser:</p>
                <p style="word-break:break-all;margin:8px 0 0;font-size:13px;line-height:1.5;color:#166534;">${link}</p>
                <p style="margin:24px 0 0;font-size:13px;line-height:1.5;color:#6b7280;">If you did not request this, you can ignore this email.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`,
  };
}

async function sendEmail(to: string, subject: string, html: string, text: string) {
  if (!fromEmail) {
    throw new HttpsError("failed-precondition", "Email sender is not configured.");
  }

  if (process.env.SENDGRID_API_KEY) {
    await axios.post(
      "https://api.sendgrid.com/v3/mail/send",
      {
        personalizations: [{to: [{email: to}]}],
        from: {email: fromEmail, name: appName},
        subject,
        content: [
          {type: "text/plain", value: text},
          {type: "text/html", value: html},
        ],
      },
      {headers: {Authorization: `Bearer ${process.env.SENDGRID_API_KEY}`}},
    );
    return;
  }

  if (process.env.RESEND_API_KEY) {
    await axios.post(
      "https://api.resend.com/emails",
      {from: `${appName} <${fromEmail}>`, to: [to], subject, html, text},
      {headers: {Authorization: `Bearer ${process.env.RESEND_API_KEY}`}},
    );
    return;
  }

  if (process.env.MAILGUN_API_KEY && process.env.MAILGUN_DOMAIN) {
    const form = new URLSearchParams();
    form.set("from", `${appName} <${fromEmail}>`);
    form.set("to", to);
    form.set("subject", subject);
    form.set("text", text);
    form.set("html", html);

    await axios.post(
      `https://api.mailgun.net/v3/${process.env.MAILGUN_DOMAIN}/messages`,
      form,
      {
        auth: {username: "api", password: process.env.MAILGUN_API_KEY},
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
      },
    );
    return;
  }

  await sendSmtpEmail(to, subject, html, text);
}

function readLine(socket: net.Socket): Promise<string> {
  return new Promise((resolve, reject) => {
    let buffer = "";
    const onData = (chunk: Buffer) => {
      buffer += chunk.toString("utf8");
      const lastLine = buffer.trimEnd().split(/\r?\n/).pop() || "";
      if (/\r?\n/.test(buffer) && /^\d{3} /.test(lastLine)) {
        socket.off("data", onData);
        socket.off("error", reject);
        resolve(buffer);
      }
    };

    socket.on("data", onData);
    socket.once("error", reject);
  });
}

async function expect(socket: net.Socket, codes: string[]) {
  const line = await readLine(socket);
  if (!codes.some((code) => line.startsWith(code))) {
    throw new Error(`SMTP error: ${line.trim()}`);
  }
}

async function command(socket: net.Socket, value: string, codes: string[]) {
  socket.write(`${value}\r\n`);
  await expect(socket, codes);
}

function encodeSubject(subject: string) {
  return `=?UTF-8?B?${Buffer.from(subject).toString("base64")}?=`;
}

function escapeAddress(value: string) {
  return value.replace(/[<>\r\n]/g, "");
}

async function sendSmtpEmail(
  to: string,
  subject: string,
  html: string,
  text: string,
) {
  const host = process.env.SMTP_HOST || "smtp.gmail.com";
  const port = Number(process.env.SMTP_PORT || "465");
  const user = process.env.SMTP_USER || process.env.GMAIL_USER;
  const pass = process.env.SMTP_PASS || process.env.GMAIL_APP_PASSWORD;

  if (!user || !pass) {
    throw new HttpsError("failed-precondition", "SMTP credentials are not configured.");
  }

  const socket = tls.connect({host, port, servername: host});
  await expect(socket, ["220"]);
  await command(socket, `EHLO ${host}`, ["250"]);
  await command(socket, "AUTH LOGIN", ["334"]);
  await command(socket, Buffer.from(user).toString("base64"), ["334"]);
  await command(socket, Buffer.from(pass).toString("base64"), ["235"]);
  await command(socket, `MAIL FROM:<${escapeAddress(fromEmail || user)}>`, ["250"]);
  await command(socket, `RCPT TO:<${escapeAddress(to)}>`, ["250", "251"]);
  await command(socket, "DATA", ["354"]);

  const boundary = `b_${Date.now().toString(36)}`;
  const message = [
    `From: "${appName}" <${escapeAddress(fromEmail || user)}>`,
    `To: <${escapeAddress(to)}>`,
    `Subject: ${encodeSubject(subject)}`,
    "MIME-Version: 1.0",
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
    "",
    `--${boundary}`,
    "Content-Type: text/plain; charset=UTF-8",
    "",
    text,
    "",
    `--${boundary}`,
    "Content-Type: text/html; charset=UTF-8",
    "",
    html,
    "",
    `--${boundary}--`,
    ".",
    "",
  ].join("\r\n");

  socket.write(message);
  await expect(socket, ["250"]);
  socket.write("QUIT\r\n");
  socket.end();
}

async function assertUserExists(email: string) {
  try {
    await admin.auth().getUserByEmail(email);
  } catch {
    throw new HttpsError("not-found", "No account found with this email address.");
  }
}

export const sendCustomEmailVerification = onCall(callableOptions, async (request) => {
  const email = request.auth?.token.email;
  if (!request.auth || !email) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const link = await admin.auth().generateEmailVerificationLink(
    email,
    actionCodeSettings,
  );
  const emailContent = buildEmail("verify", link);
  await sendEmail(email, emailContent.subject, emailContent.html, emailContent.text);

  return {success: true};
});


export const sendCustomPasswordReset = onCall(callableOptions, async (request) => {
  const email = requireEmail(request.data?.email);
  await assertUserExists(email);

  const link = await admin.auth().generatePasswordResetLink(
    email,
    actionCodeSettings,
  );
  const emailContent = buildEmail("reset", link);
  await sendEmail(email, emailContent.subject, emailContent.html, emailContent.text);

  return {success: true};
});

export const sendCustomEmailChangeVerification = onCall(callableOptions, async (request) => {
  const currentEmail = request.auth?.token.email;
  if (!request.auth || !currentEmail) {
    throw new HttpsError("unauthenticated", "You must be logged in.");
  }

  const newEmail = requireEmail(request.data?.newEmail, "newEmail");
  if (newEmail === currentEmail.toLowerCase()) {
    return {success: true, skipped: true};
  }

  try {
    await admin.auth().getUserByEmail(newEmail);
    throw new HttpsError("already-exists", "This email is already registered.");
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
  }

  const link = await admin.auth().generateVerifyAndChangeEmailLink(
    currentEmail,
    newEmail,
    actionCodeSettings,
  );
  const emailContent = buildEmail("change", link, newEmail);
  await sendEmail(newEmail, emailContent.subject, emailContent.html, emailContent.text);

  return {success: true};
});

import { events, object, rows, string, displayText } from "../portal-data.ts";
import { exchange, read, PortalError, type Session } from "./portal.ts";

export function decodeDocument(payload: unknown, fallback: string) {
  const wrapper = object(payload);
  const document = rows(wrapper.documentDatas)[0] ?? wrapper;
  const encoded = string(document.base64Code).replace(/\s/g, "");
  if (
    !encoded ||
    encoded.length > 12_000_000 ||
    encoded.length % 4 !== 0 ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(encoded)
  )
    throw new PortalError(
      "The district did not return a usable document. Try again.",
    );
  const bytes = Buffer.from(encoded, "base64");
  if (process.env.VERCEL && bytes.length > 4_000_000)
    throw new PortalError(
      "This file is too large for this deployment. Download it from StudentVUE.",
      413,
    );
  const filename =
    (displayText(document.fileName) || fallback || "document")
      .split(/[\\/]/)
      .at(-1)!
      .replace(/[\x00-\x1f\x7f<>:"|?*]/g, "_")
      .slice(0, 180) || "document";
  return { bytes, filename };
}

export async function downloadDocument(
  session: Session,
  id: unknown,
  load = read,
  call = exchange,
) {
  if (
    typeof id !== "string" ||
    !id.trim() ||
    id.length > 200 ||
    /[\x00-\x1f]/.test(id)
  )
    throw new PortalError("Choose a document to download.", 400);
  const listing = events(
    await load(session, "documents", undefined),
    "documents",
  );
  const own = listing.find(
    (document) => document.id?.toLowerCase() === id.toLowerCase(),
  );
  if (!own)
    throw new PortalError(
      "This document is no longer available for your account. Refresh the list.",
      404,
    );
  const response = await call(
    session.base,
    "GetStudentDocumentContent",
    `Bearer ${session.token}`,
    { childIntID: 0, languageCode: "1", documentGU: own.id },
  );
  if (response.error)
    throw new PortalError(
      "The district could not download this document. Try again.",
    );
  const data = object(response.data);
  return decodeDocument(
    data.studentAttachedDocumentData ?? data,
    own.filename ?? "document",
  );
}

export async function downloadMailAttachment(
  session: Session,
  messageId: unknown,
  id: unknown,
  load = read,
  call = exchange,
) {
  if (
    typeof messageId !== "string" ||
    typeof id !== "string" ||
    !messageId.trim() ||
    !id.trim() ||
    messageId.length > 200 ||
    id.length > 200 ||
    /[\x00-\x1f]/.test(messageId + id)
  )
    throw new PortalError("Choose a mail attachment to download.", 400);
  const inbox = events(await load(session, "mail", undefined), "mail");
  const message = inbox.find(
    (m) => m.id?.toLowerCase() === messageId.toLowerCase(),
  );
  const attachment = message?.attachments?.find(
    (a) => a.id.toLowerCase() === id.toLowerCase(),
  );
  if (!message || !attachment)
    throw new PortalError(
      "This attachment is no longer available in your inbox. Refresh your messages.",
      404,
    );
  const response = await call(
    session.base,
    "GetSynergyMailGetAttachment",
    `Bearer ${session.token}`,
    {
      childIntID: 0,
      languageCode: "1",
      smMessageGU: message.id,
      smAttachmentGU: attachment.id,
      attachmentGU: attachment.id,
    },
  );
  if (response.error)
    throw new PortalError(
      "The district could not download this attachment. Try again.",
    );
  const data = object(response.data);
  let raw: unknown = data.attachmentXML ?? data;
  if (typeof raw === "string") {
    try {
      raw = JSON.parse(raw);
    } catch {
      // Extract just the base64 field from XML envelopes, without resolving entities.
      const text = raw as string;
      const base64 =
        !/<!DOCTYPE|<!ENTITY/i.test(text) &&
        text.match(
          /<(?:\w+:)?Base64Code\s*>([A-Za-z0-9+/=\s]+)<\/(?:\w+:)?Base64Code\s*>/i,
        )?.[1];
      if (!base64)
        throw new PortalError(
          "The district returned an unsupported attachment format. Open it in StudentVUE.",
        );
      raw = { base64Code: base64 };
    }
  }
  const wrapper = object(raw);
  const file = object(wrapper.AttachmentXML ?? wrapper);
  return decodeDocument(
    {
      base64Code: file.base64Code ?? file.Base64Code,
      fileName: file.fileName ?? file.documentName ?? file._DocumentName,
    },
    attachment.filename,
  );
}

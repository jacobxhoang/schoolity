import { test } from "node:test";
import assert from "node:assert/strict";
import { events } from "../src/lib/portal-data.ts";
import { downloadMailAttachment } from "../src/lib/server/documents.ts";
import { PortalError, type Session } from "../src/lib/server/portal.ts";
const session: Session = {
  base: "https://school.example",
  token: "synthetic-token",
  expires: Date.now() + 1000,
};
const inbox = {
  inboxItemListings: [
    {
      smMessageGU: "message-one",
      attachments: [
        { smAttachmentGU: "attachment-one", documentName: "Handout.pdf" },
      ],
    },
    { smMessageGU: "message-two", attachments: [] },
  ],
};
test("mail preserves attachment IDs and ignores empty attachment fields", () => {
  const [message] = events(inbox, "mail");
  assert.equal(message.id, "message-one");
  assert.deepEqual(message.attachments, [
    { id: "attachment-one", filename: "Handout.pdf" },
  ]);
  assert.deepEqual(
    events({ inboxItemListings: [{ attachments: "" }] }, "mail")[0].attachments,
    [],
  );
});
test("mail downloads authorize the parent message before calling the dedicated API", async () => {
  const file = await downloadMailAttachment(
    session,
    "message-one",
    "attachment-one",
    async (_session, resource) => {
      assert.equal(resource, "mail");
      return inbox;
    },
    async (base, method, auth, params) => {
      assert.equal(base, session.base);
      assert.equal(method, "GetSynergyMailGetAttachment");
      assert.equal(auth, "Bearer synthetic-token");
      assert.equal(params.attachmentGU, "attachment-one");
      assert.equal(params.smAttachmentGU, "attachment-one");
      assert.equal(params.smMessageGU, "message-one");
      return {
        data: {
          attachmentXML: {
            base64Code: Buffer.from("%PDF-sample").toString("base64"),
          },
        },
      };
    },
  );
  assert.equal(file.bytes.toString(), "%PDF-sample");
  assert.equal(file.filename, "Handout.pdf");
});
test("another message or account cannot supply an attachment ID", async () => {
  for (const messageId of ["message-two", "other-account-message"])
    await assert.rejects(
      downloadMailAttachment(
        session,
        messageId,
        "attachment-one",
        async () => inbox,
        async () => {
          assert.fail("Content request must not run");
        },
      ),
      (e) => e instanceof PortalError && e.status === 404,
    );
});
test("mail accepts JSON and single-field XML attachment envelopes", async () => {
  for (const attachmentXML of [
    { AttachmentXML: { Base64Code: "dGVzdA==", _DocumentName: "Note.txt" } },
    "<AttachmentXML><Base64Code>dGVzdA==</Base64Code></AttachmentXML>",
  ]) {
    const file = await downloadMailAttachment(
      session,
      "message-one",
      "attachment-one",
      async () => inbox,
      async () => ({ data: { attachmentXML } }),
    );
    assert.equal(file.bytes.toString(), "test");
  }
});
test("upstream errors, malformed files and XML entities never become downloaded files", async () => {
  await assert.rejects(
    downloadMailAttachment(
      session,
      "message-one",
      "attachment-one",
      async () => inbox,
      async () => ({ error: { code: "500" } }),
    ),
    /could not download/,
  );
  await assert.rejects(
    downloadMailAttachment(
      session,
      "message-one",
      "attachment-one",
      async () => inbox,
      async () => ({ data: { attachmentXML: { base64Code: "not base64!" } } }),
    ),
    /usable document/,
  );
  await assert.rejects(
    downloadMailAttachment(
      session,
      "message-one",
      "attachment-one",
      async () => inbox,
      async () => ({
        data: {
          attachmentXML:
            "<!DOCTYPE x><AttachmentXML><Base64Code>dGVzdA==</Base64Code></AttachmentXML>",
        },
      }),
    ),
    /unsupported attachment format/,
  );
});

import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { pushService } from "$lib/server/push";
export const GET: RequestHandler = async ({ request }) => {
  const headers = { "Cache-Control": "no-store" };
  if (!pushService.authorizedCron(request.headers.get("authorization")))
    return json({ error: "Unauthorized." }, { status: 401, headers });
  try {
    return json(await pushService.run(), { headers });
  } catch {
    return json(
      { error: "Notification checks are unavailable." },
      { status: 503, headers },
    );
  }
};

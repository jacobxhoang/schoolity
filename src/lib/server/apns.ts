import { createPrivateKey, sign } from 'node:crypto';
import { connect } from 'node:http2';
import { PortalError } from './portal.ts';

export type PushEnvironment = 'development' | 'production';
export class APNs {
  private jwt?: { value: string; created: number };
  private env: NodeJS.ProcessEnv;
  private now: () => number;
  constructor(env: NodeJS.ProcessEnv = process.env, now = Date.now) { this.env = env; this.now = now; }
  ensureReady() {
    if (!/^[A-Z0-9]{10}$/.test(this.env.SCHOOLITY_APNS_KEY_ID ?? '') ||
        !/^[A-Z0-9]{10}$/.test(this.env.SCHOOLITY_APNS_TEAM_ID ?? '') ||
        !/^[A-Za-z0-9][A-Za-z0-9.-]{2,200}$/.test(this.env.SCHOOLITY_APNS_TOPIC ?? ''))
      throw new PortalError('Closed-app alerts are not configured on this service.', 503);
    try {
      const key = createPrivateKey((this.env.SCHOOLITY_APNS_PRIVATE_KEY ?? '').replace(/\\n/g, '\n'));
      if (key.asymmetricKeyType !== 'ec' || key.asymmetricKeyDetails?.namedCurve !== 'prime256v1') throw new Error();
    } catch { throw new PortalError('Closed-app alerts are not configured on this service.', 503); }
  }
  token(): string {
    this.ensureReady();
    if (this.jwt && this.now() - this.jwt.created < 40 * 60 * 1000) return this.jwt.value;
    const header = Buffer.from(JSON.stringify({ alg: 'ES256', kid: this.env.SCHOOLITY_APNS_KEY_ID })).toString('base64url');
    const payload = Buffer.from(JSON.stringify({ iss: this.env.SCHOOLITY_APNS_TEAM_ID, iat: Math.floor(this.now() / 1000) })).toString('base64url');
    const unsigned = `${header}.${payload}`;
    const signature = sign('sha256', Buffer.from(unsigned), {
      key: (this.env.SCHOOLITY_APNS_PRIVATE_KEY ?? '').replace(/\\n/g, '\n'), dsaEncoding: 'ieee-p1363',
    }).toString('base64url');
    this.jwt = { value: `${unsigned}.${signature}`, created: this.now() };
    return this.jwt.value;
  }
  async send(device: string, environment: PushEnvironment, id: string, body: string): Promise<'sent' | 'invalid'> {
    if (!/^[a-f0-9]{64,256}$/.test(device)) throw new Error('Invalid device token');
    const jwt = this.token();
    const payload = Buffer.from(JSON.stringify({ aps: {
      alert: { title: 'Assignment graded', body: body.slice(0, 800) }, sound: 'default', 'thread-id': 'schoolity.grades',
    } }));
    const host = environment === 'development' ? 'api.sandbox.push.apple.com' : 'api.push.apple.com';
    return await new Promise((resolve, reject) => {
      const client = connect(`https://${host}`);
      const timer = setTimeout(() => { client.destroy(); reject(new Error('APNs timed out')); }, 8000);
      const finish = () => { clearTimeout(timer); client.close(); };
      client.once('error', () => { finish(); reject(new Error('APNs unavailable')); });
      const request = client.request({
        ':method': 'POST', ':path': `/3/device/${device}`, authorization: `bearer ${jwt}`,
        'apns-topic': this.env.SCHOOLITY_APNS_TOPIC!, 'apns-push-type': 'alert', 'apns-priority': '10',
        'apns-expiration': String(Math.floor(this.now() / 1000) + 3600), 'apns-collapse-id': id.slice(0, 64),
      });
      let status = 0, text = '';
      request.on('response', headers => { status = Number(headers[':status']); });
      request.on('data', chunk => { if (text.length < 4096) text += chunk.toString(); });
      request.on('error', () => { finish(); reject(new Error('APNs unavailable')); });
      request.on('end', () => {
        finish();
        let reason = '';
        try { reason = JSON.parse(text).reason; } catch { /* Empty success response. */ }
        if (status === 200) resolve('sent');
        else if (status === 410 || ['BadDeviceToken', 'DeviceTokenNotForTopic', 'Unregistered'].includes(reason)) resolve('invalid');
        else reject(new Error('APNs rejected the notification'));
      });
      request.end(payload);
    });
  }
}

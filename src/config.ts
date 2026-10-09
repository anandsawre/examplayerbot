export interface Env {
  BOT_TOKEN: string;
  SUPABASE_URL: string;
  SUPABASE_KEY: string;
  ADMIN_USER_ID?: string;
  WEBHOOK_SECRET?: string;
  REQUIRED_CHANNEL?: string; // e.g. @MyChannel or channel ID
  UPI_ID?: string; // e.g. yourname@upi
  PREMIUM_PRICE?: string; // e.g. 99
}

export function getConfig(env?: Partial<Env>): Env {
  const botToken = env?.BOT_TOKEN || process.env.BOT_TOKEN || '';
  const supabaseUrl = env?.SUPABASE_URL || process.env.SUPABASE_URL || '';
  const supabaseKey = env?.SUPABASE_KEY || process.env.SUPABASE_KEY || '';
  const adminUserId = env?.ADMIN_USER_ID || process.env.ADMIN_USER_ID;
  const webhookSecret = env?.WEBHOOK_SECRET || process.env.WEBHOOK_SECRET;
  const requiredChannel = env?.REQUIRED_CHANNEL || process.env.REQUIRED_CHANNEL;
  const upiId = env?.UPI_ID || process.env.UPI_ID || 'your-upi-id@okhdfcbank';
  const premiumPrice = env?.PREMIUM_PRICE || process.env.PREMIUM_PRICE || '99';

  return {
    BOT_TOKEN: botToken,
    SUPABASE_URL: supabaseUrl,
    SUPABASE_KEY: supabaseKey,
    ADMIN_USER_ID: adminUserId,
    WEBHOOK_SECRET: webhookSecret,
    REQUIRED_CHANNEL: requiredChannel,
    UPI_ID: upiId,
    PREMIUM_PRICE: premiumPrice,
  };
}

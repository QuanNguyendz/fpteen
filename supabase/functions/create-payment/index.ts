import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Deno runtime global (for TypeScript type checking)
// This declaration has no effect at runtime on Supabase Edge Functions.
declare const Deno: any;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonError("Unauthorized", 401);
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", "")
    );
    if (authError || !user) return jsonError("Unauthorized", 401);

    const { order_id, gateway } = await req.json();
    if (!order_id || !gateway) {
      return jsonError("Missing order_id or gateway", 400);
    }
    if (!["vnpay", "momo", "zalopay"].includes(gateway)) {
      return jsonError("Invalid gateway", 400);
    }

    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("id, total_amount, status, customer_id")
      .eq("id", order_id)
      .eq("customer_id", user.id)
      .eq("status", "pending")
      .single();

    if (orderError || !order) {
      return jsonError("Order not found or not eligible for payment", 404);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const webhookUrl = `${supabaseUrl}/functions/v1/payment-webhook`;

    // payment_ref is the reference we send to the gateway (used for webhook lookup)
    let paymentRef = "";
    let paymentUrl = "";

    if (gateway === "vnpay") {
      paymentRef = order_id.replace(/-/g, ""); // 32-char hex, alphanumeric only
      paymentUrl = await createVNPayUrl(paymentRef, order.total_amount, webhookUrl);
    } else if (gateway === "momo") {
      paymentRef = order_id; // MoMo accepts UUID with dashes
      paymentUrl = await createMoMoUrl(paymentRef, order.total_amount, webhookUrl);
    } else if (gateway === "zalopay") {
      const d = new Date();
      const yymmdd = d.toISOString().slice(2, 10).replace(/-/g, "");
      paymentRef = `${yymmdd}_${order_id.replace(/-/g, "")}`; // max 39 chars
      paymentUrl = await createZaloPayUrl(paymentRef, order.total_amount, webhookUrl);
    }

    // Persist payment_ref to orders and create payment record
    await supabase
      .from("orders")
      .update({ payment_method: gateway, payment_ref: paymentRef })
      .eq("id", order_id);

    await supabase.from("payments").upsert(
      { order_id, gateway, amount: order.total_amount, status: "pending" },
      { onConflict: "order_id" }
    );

    return new Response(
      JSON.stringify({ payment_url: paymentUrl, order_id }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    console.error("create-payment error:", err);
    const msg = err instanceof Error ? err.message : "Internal server error";
    return jsonError(msg, 500);
  }
});

function jsonError(message: string, status: number) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

async function hmacHex(
  key: string,
  message: string,
  algorithm: "SHA-256" | "SHA-512"
): Promise<string> {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    enc.encode(key),
    { name: "HMAC", hash: algorithm },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(message));
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function createVNPayUrl(
  txnRef: string,
  amount: number,
  returnUrl: string
): Promise<string> {
  const tmnCode = Deno.env.get("VNPAY_TMN_CODE") ?? "";
  const secretKey = Deno.env.get("VNPAY_SECRET_KEY") ?? "";
  const vnpUrl = "https://sandbox.vnpayment.vn/paymentv2/vpcpay.html";

  const createDate = new Date()
    .toISOString()
    .replace(/[-:T.Z]/g, "")
    .slice(0, 14);

  const params: Record<string, string> = {
    vnp_Version: "2.1.0",
    vnp_Command: "pay",
    vnp_TmnCode: tmnCode,
    vnp_Amount: String(amount * 100), // VNPay requires amount * 100
    vnp_CurrCode: "VND",
    vnp_TxnRef: txnRef,
    vnp_OrderInfo: `FPTeen order ${txnRef.slice(0, 8)}`,
    vnp_OrderType: "other",
    vnp_Locale: "vn",
    vnp_ReturnUrl: returnUrl,
    vnp_IpAddr: "127.0.0.1",
    vnp_CreateDate: createDate,
  };

  const sortedKeys = Object.keys(params).sort();
  const sortedParams = sortedKeys.reduce(
    (acc: Record<string, string>, k) => { acc[k] = params[k]; return acc; },
    {}
  );
  const queryString = new URLSearchParams(sortedParams).toString();
  const secureHash = await hmacHex(secretKey, queryString, "SHA-512");

  return `${vnpUrl}?${queryString}&vnp_SecureHash=${secureHash}`;
}

async function createMoMoUrl(
  orderId: string,
  amount: number,
  returnUrl: string
): Promise<string> {
  const partnerCode = Deno.env.get("MOMO_PARTNER_CODE") ?? "";
  const accessKey = Deno.env.get("MOMO_ACCESS_KEY") ?? "";
  const secretKey = Deno.env.get("MOMO_SECRET_KEY") ?? "";
  const endpoint = "https://test-payment.momo.vn/v2/gateway/api/create";

  const requestId = crypto.randomUUID();
  const requestType = "payWithMethod";
  const orderInfo = `FPTeen payment ${orderId.slice(0, 8)}`;
  const extraData = "";

  const rawSignature = [
    `accessKey=${accessKey}`,
    `amount=${amount}`,
    `extraData=${extraData}`,
    `ipnUrl=${returnUrl}`,
    `orderId=${orderId}`,
    `orderInfo=${orderInfo}`,
    `partnerCode=${partnerCode}`,
    `redirectUrl=${returnUrl}`,
    `requestId=${requestId}`,
    `requestType=${requestType}`,
  ].join("&");

  const signature = await hmacHex(secretKey, rawSignature, "SHA-256");

  const body = {
    partnerCode,
    requestId,
    amount,
    orderId,
    orderInfo,
    redirectUrl: returnUrl,
    ipnUrl: returnUrl,
    requestType,
    extraData,
    lang: "vi",
    signature,
  };

  const res = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  return data.payUrl ?? "";
}

async function createZaloPayUrl(
  appTransId: string,
  amount: number,
  returnUrl: string
): Promise<string> {
  const appId = Deno.env.get("ZALOPAY_APP_ID") ?? "2554";
  const key1 = Deno.env.get("ZALOPAY_KEY1") ?? "";
  const endpoint = "https://sb-openapi.zalopay.vn/v2/create";

  const appTime = Date.now();
  const appUser = "fpteen_user";
  const embedData = JSON.stringify({ redirecturl: returnUrl });
  const items = "[]";
  const description = `FPTeen - Thanh toan ${appTransId.slice(-8)}`;

  // ZaloPay v2/create MAC format:
  // app_id|app_trans_id|app_user|amount|app_time|embed_data|item
  const dataToSign = `${appId}|${appTransId}|${appUser}|${amount}|${appTime}|${embedData}|${items}`;
  const mac = await hmacHex(key1, dataToSign, "SHA-256");

  const body = new URLSearchParams({
    app_id: appId,
    app_trans_id: appTransId,
    app_user: appUser,
    app_time: String(appTime),
    amount: String(amount),
    item: items,
    embed_data: embedData,
    description,
    bank_code: "",
    mac,
    callback_url: returnUrl,
  });

  const res = await fetch(endpoint, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });
  const data: Record<string, unknown> = await res.json();
  const returnCode = Number(data["return_code"]);
  const returnMessage = String(data["return_message"] ?? "");
  const orderUrl = typeof data["order_url"] === "string" ? data["order_url"] : "";

  console.log("ZaloPay create response:", {
    return_code: returnCode,
    return_message: returnMessage,
    sub_return_code: data["sub_return_code"],
    sub_return_message: data["sub_return_message"],
    has_order_url: Boolean(orderUrl),
  });

  if (returnCode !== 1 || !orderUrl) {
    throw new Error(
      `ZaloPay create failed: ${returnMessage || String(data["sub_return_message"] ?? "unknown")}`
    );
  }

  return orderUrl;
}

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

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const url = new URL(req.url);
  const queryParams = Object.fromEntries(url.searchParams.entries());
  const contentType = req.headers.get("content-type") ?? "";

  let gateway = "";
  let paymentRef = "";
  let paymentSuccess = false;
  let gatewayTxnId = "";
  let rawResponse: Record<string, unknown> = {};

  try {
    // Detect gateway by unique parameter signatures
    if (queryParams.vnp_TmnCode || queryParams.vnp_SecureHash) {
      // VNPay: parameters arrive as GET query params on return URL
      gateway = "vnpay";
      const isValid = await verifyVNPaySignature(queryParams);
      paymentSuccess = isValid && queryParams.vnp_ResponseCode === "00";
      paymentRef = queryParams.vnp_TxnRef ?? "";
      gatewayTxnId = queryParams.vnp_TransactionNo ?? "";
      rawResponse = queryParams;
    } else if (contentType.includes("application/json")) {
      const body: Record<string, unknown> = await req.json();
      rawResponse = body;

      if (typeof body.partnerCode === "string") {
        // MoMo IPN
        gateway = "momo";
        const isValid = await verifyMoMoSignature(body);
        paymentSuccess = isValid && body.resultCode === 0;
        paymentRef = String(body.orderId ?? "");
        gatewayTxnId = String(body.transId ?? "");
      } else if (typeof body.data === "string" && typeof body.mac === "string") {
        // ZaloPay IPN
        gateway = "zalopay";
        const dataStr = String(body.data);
        const isValid = await verifyZaloPayCallback(dataStr, String(body.mac));
        const dataObj = JSON.parse(dataStr);
        paymentSuccess = isValid && dataObj.return_code === 1;
        paymentRef = String(dataObj.app_trans_id ?? "");
        gatewayTxnId = String(dataObj.zp_trans_id ?? "");
        rawResponse = dataObj;
      }
    }

    if (!gateway || !paymentRef) {
      return new Response(
        JSON.stringify({ error: "Unrecognised callback" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Find order by payment_ref
    const { data: order } = await supabase
      .from("orders")
      .select("id, status")
      .eq("payment_ref", paymentRef)
      .maybeSingle();

    if (!order) {
      console.warn("payment-webhook: order not found for paymentRef", paymentRef);
      return new Response(
        JSON.stringify({ RspCode: "01", Message: "Order not found" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Idempotency: skip if already processed
    if (order.status !== "pending") {
      return respondSuccess(gateway);
    }

    const newOrderStatus = paymentSuccess ? "paid" : "cancelled";
    const paymentStatus = paymentSuccess ? "success" : "failed";

    await supabase
      .from("orders")
      .update({ status: newOrderStatus })
      .eq("id", order.id);

    await supabase
      .from("payments")
      .update({
        status: paymentStatus,
        gateway_transaction_id: gatewayTxnId,
        raw_response: rawResponse,
      })
      .eq("order_id", order.id);

    // For VNPay GET return: redirect WebView to known callback URL
    if (gateway === "vnpay" && req.method === "GET") {
      const status = paymentSuccess ? "success" : "failed";
      const callbackUrl = `https://fpteen.app/payment/callback?order_id=${order.id}&status=${status}`;
      return Response.redirect(callbackUrl, 302);
    }

    return respondSuccess(gateway);
  } catch (err) {
    console.error("payment-webhook error:", err);
    return new Response(
      JSON.stringify({ error: "Internal error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

function respondSuccess(gateway: string) {
  // Each gateway expects a specific acknowledge response
  if (gateway === "momo") {
    return new Response(
      JSON.stringify({ message: "success" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
  if (gateway === "zalopay") {
    return new Response(
      JSON.stringify({ return_code: 1, return_message: "success" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
  // VNPay IPN
  return new Response(
    JSON.stringify({ RspCode: "00", Message: "Confirm Success" }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
}

async function hmacHex(key: string, message: string, alg: "SHA-256" | "SHA-512"): Promise<string> {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw", enc.encode(key), { name: "HMAC", hash: alg }, false, ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function verifyVNPaySignature(params: Record<string, string>): Promise<boolean> {
  const secretKey = Deno.env.get("VNPAY_SECRET_KEY") ?? "";
  const secureHash = params.vnp_SecureHash ?? "";
  const filtered = Object.fromEntries(
    Object.entries(params).filter(([k]) => k !== "vnp_SecureHash" && k !== "vnp_SecureHashType")
  );
  const sorted = Object.keys(filtered).sort().reduce(
    (acc: Record<string, string>, k) => { acc[k] = filtered[k]; return acc; }, {}
  );
  const qs = new URLSearchParams(sorted).toString();
  const computed = await hmacHex(secretKey, qs, "SHA-512");
  return computed.toLowerCase() === secureHash.toLowerCase();
}

async function verifyMoMoSignature(body: Record<string, unknown>): Promise<boolean> {
  const secretKey = Deno.env.get("MOMO_SECRET_KEY") ?? "";
  const accessKey = Deno.env.get("MOMO_ACCESS_KEY") ?? "";
  const { partnerCode, orderId, requestId, amount, orderInfo, orderType, transId,
    resultCode, message, payType, responseTime, extraData, signature } = body as Record<string, unknown>;
  const rawSig = [
    `accessKey=${accessKey}`, `amount=${amount}`, `extraData=${extraData}`,
    `message=${message}`, `orderId=${orderId}`, `orderInfo=${orderInfo}`,
    `orderType=${orderType}`, `partnerCode=${partnerCode}`, `payType=${payType}`,
    `requestId=${requestId}`, `responseTime=${responseTime}`,
    `resultCode=${resultCode}`, `transId=${transId}`,
  ].join("&");
  const computed = await hmacHex(secretKey, rawSig, "SHA-256");
  return computed === String(signature);
}

async function verifyZaloPayCallback(dataStr: string, mac: string): Promise<boolean> {
  const key2 = Deno.env.get("ZALOPAY_KEY2") ?? "";
  const computed = await hmacHex(key2, dataStr, "SHA-256");
  return computed === mac;
}
